import 'package:test/test.dart';

import 'package:tapline/engine/engine.dart';

Graph _digraph(int n, List<(int, int)> edges) {
  return Graph.directed(
    nodes: [for (var i = 0; i < n; i++) GraphNode(id: '$i')],
    edges: [for (final (u, v) in edges) GraphEdge('$u', '$v')],
  );
}

void main() {
  group('SignalSolver.solve — hand-verified cases', () {
    test('directed path 0->1->2->3 needs exactly 1 driver (the source)',
        () {
      final graph = _digraph(4, [(0, 1), (1, 2), (2, 3)]);
      final result = SignalSolver.solve(graph);
      expect(result.optimalTapCount, equals(1));
      expect(result.optimalTaps, equals({'0'}));
      expect(SignalSolver.verify(graph, result.optimalTaps), isTrue);
    });

    test('two disconnected directed paths need 1 driver each', () {
      final graph = _digraph(4, [(0, 1), (2, 3)]);
      final result = SignalSolver.solve(graph);
      expect(result.optimalTapCount, equals(2));
      expect(result.optimalTaps, equals({'0', '2'}));
      expect(SignalSolver.verify(graph, result.optimalTaps), isTrue);
    });

    test(
      'pure directed cycle: perfect matching would naively give 0 '
      'drivers, which cannot reach anything — must be fixed to 1',
      () {
        final graph = _digraph(3, [(0, 1), (1, 2), (2, 0)]);
        final result = SignalSolver.solve(graph);
        expect(result.optimalTapCount, equals(1));
        // any single node on the cycle is a valid driver — confirm
        // reachability actually holds for whichever one was chosen,
        // rather than hard-coding which node it should be.
        expect(SignalSolver.verify(graph, result.optimalTaps), isTrue);
      },
    );

    test('two disjoint pure cycles need 1 driver per cycle', () {
      final graph = _digraph(6, [
        (0, 1), (1, 2), (2, 0), // cycle A
        (3, 4), (4, 5), (5, 3), // cycle B
      ]);
      final result = SignalSolver.solve(graph);
      expect(result.optimalTapCount, equals(2));
      expect(SignalSolver.verify(graph, result.optimalTaps), isTrue);
    });

    test(
      'two 2-cycles chained by a one-way edge need only 1 driver, not '
      '2 — regression test for the refinement-step bug: picking '
      'unreached nodes by index order could waste a driver on a '
      '"downstream" component',
      () {
        // 0<->1 and 2<->3 are each independently perfectly matched (0
        // drivers from the initial matching step either way), but
        // 3->0 lets a driver anywhere in {2,3} reach all four nodes:
        // 2->3->0->1. The bug: picking node 0 first (lowest index)
        // only reaches {0,1} and ends up needing a second driver for
        // {2,3} too.
        final graph = _digraph(4, [(0, 1), (1, 0), (2, 3), (3, 2), (3, 0)]);
        final result = SignalSolver.solve(graph);
        expect(result.optimalTapCount, equals(1));
        expect(SignalSolver.verify(graph, result.optimalTaps), isTrue);
      },
    );

    test(
      'three 2-cycles chained A->B->C need only 1 driver — confirms '
      'the fix is genuinely component-based, not just patched for '
      'the two-component case above',
      () {
        // A=0<->1, B=2<->3, C=4<->5, connected A->B->C only (one-way
        // each hop, no path back). A single driver anywhere in A
        // reaches all six nodes: 0<->1, 1->2 (into B), 2<->3,
        // 3->4 (into C), 4<->5.
        final graph = _digraph(6, [
          (0, 1), (1, 0), // cycle A
          (2, 3), (3, 2), // cycle B
          (4, 5), (5, 4), // cycle C
          (1, 2), // A -> B
          (3, 4), // B -> C
        ]);
        final result = SignalSolver.solve(graph);
        expect(result.optimalTapCount, equals(1));
        expect(SignalSolver.verify(graph, result.optimalTaps), isTrue);
      },
    );

    test(
      'denser graph needs FEWER drivers than a sparser one on the '
      'same nodes — the pedagogical hook the Master Context calls out',
      () {
        // sparse: center fans out to 3 leaves, no other structure.
        // center is never a target -> unmatched; 2 of the 3 leaves
        // also end up unmatched (only one can be matched to center).
        final sparse = _digraph(4, [(0, 1), (0, 2), (0, 3)]);
        final sparseResult = SignalSolver.solve(sparse);

        // denser: same 4 nodes, but the leaves are chained so control
        // can hop through them — 0->1->2->3 lets a single driver
        // reach everyone by riding the chain.
        final dense = _digraph(4, [(0, 1), (1, 2), (2, 3)]);
        final denseResult = SignalSolver.solve(dense);

        expect(
          denseResult.optimalTapCount,
          lessThan(sparseResult.optimalTapCount),
        );
        expect(sparseResult.optimalTapCount, equals(3));
        expect(denseResult.optimalTapCount, equals(1));
      },
    );
  });

  group('SignalSolver.verify', () {
    test('rejects a driver set that misses part of the graph', () {
      final graph = _digraph(4, [(0, 1), (2, 3)]);
      // only covers the first component
      expect(SignalSolver.verify(graph, {'0'}), isFalse);
    });

    test('empty driver set only verifies for an empty graph', () {
      final graph = _digraph(3, [(0, 1), (1, 2)]);
      expect(SignalSolver.verify(graph, {}), isFalse);

      final emptyGraph = _digraph(0, []);
      expect(SignalSolver.verify(emptyGraph, {}), isTrue);
    });
  });

  group('performance sanity check', () {
    test('100-node sparse random digraph solves near-instantly '
        '(polynomial-time matching, unlike the other two modes)', () {
      var seedState = 999;
      int nextRand(int bound) {
        seedState = (seedState * 1103515245 + 12345) & 0x7fffffff;
        return seedState % bound;
      }

      const n = 100;
      final edges = <(int, int)>[];
      for (var i = 0; i < n; i++) {
        for (var j = 0; j < n; j++) {
          if (i != j && nextRand(100) < 5) edges.add((i, j));
        }
      }
      final graph = _digraph(n, edges);

      final stopwatch = Stopwatch()..start();
      final result = SignalSolver.solve(graph);
      stopwatch.stop();

      expect(SignalSolver.verify(graph, result.optimalTaps), isTrue);
      expect(stopwatch.elapsedMilliseconds, lessThan(1000));
      // ignore: avoid_print
      print(
        '100-node digraph: ${result.optimalTapCount} drivers in '
        '${stopwatch.elapsedMilliseconds}ms',
      );
    });
  });
}
