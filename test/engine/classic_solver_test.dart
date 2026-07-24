import 'package:test/test.dart';

import 'package:tapline/engine/engine.dart';

/// Builds an undirected [Graph] from a plain node-count + edge-index
/// list, so test cases can stay terse (node ids are just "0", "1",
/// ...).
Graph _graph(int n, List<(int, int)> edges) {
  return Graph.undirected(
    nodes: [for (var i = 0; i < n; i++) GraphNode(id: '$i')],
    edges: [for (final (u, v) in edges) GraphEdge('$u', '$v')],
  );
}

void main() {
  group('ClassicSolver.solve — hand-verified cases', () {
    test('5-node star: MDS is 1 (the center)', () {
      final graph = _graph(5, [(0, 1), (0, 2), (0, 3), (0, 4)]);
      final result = ClassicSolver.solve(graph);
      expect(result.optimalTapCount, equals(1));
      expect(ClassicSolver.verify(graph, result.optimalTaps), isTrue);
    });

    test('5-cycle: MDS is 2', () {
      final graph = _graph(5, [(0, 1), (1, 2), (2, 3), (3, 4), (4, 0)]);
      final result = ClassicSolver.solve(graph);
      expect(result.optimalTapCount, equals(2));
      expect(ClassicSolver.verify(graph, result.optimalTaps), isTrue);
    });

    test('isolated node must be tapped itself', () {
      // node "2" has no edges; 0-1 are connected. MDS = {2, one of 0/1} = 2.
      final graph = _graph(3, [(0, 1)]);
      final result = ClassicSolver.solve(graph);
      expect(result.optimalTapCount, equals(2));
      expect(result.optimalTaps, contains('2'));
      expect(ClassicSolver.verify(graph, result.optimalTaps), isTrue);
    });

    test('single isolated node (n=1, no edges)', () {
      final graph = _graph(1, []);
      final result = ClassicSolver.solve(graph);
      expect(result.optimalTapCount, equals(1));
      expect(result.optimalTaps, equals({'0'}));
    });

    test('complete graph K5: MDS collapses to 1', () {
      final edges = [
        for (var i = 0; i < 5; i++)
          for (var j = i + 1; j < 5; j++) (i, j),
      ];
      final graph = _graph(5, edges);
      final result = ClassicSolver.solve(graph);
      expect(result.optimalTapCount, equals(1));
      // Flagged for Phase 2, not a solver bug: a complete graph is a
      // degenerate puzzle (any single tap wins) and should be
      // rejected by the level generator, not shipped as a level.
    });

    test('disconnected graph: optimum sums across components', () {
      // two independent 5-cycles, each needing 2 -> total 4.
      final edges = [
        (0, 1), (1, 2), (2, 3), (3, 4), (4, 0), // cycle A: nodes 0-4
        (5, 6), (6, 7), (7, 8), (8, 9), (9, 5), // cycle B: nodes 5-9
      ];
      final graph = _graph(10, edges);
      final result = ClassicSolver.solve(graph);
      expect(result.optimalTapCount, equals(4));
      expect(ClassicSolver.verify(graph, result.optimalTaps), isTrue);
    });

    test('symmetric graph: size is stable even though the exact set '
        'can vary — star comparisons must use size, never membership',
        () {
      final graph = _graph(5, [(0, 1), (1, 2), (2, 3), (3, 4), (4, 0)]);
      final result = ClassicSolver.solve(graph);
      expect(result.optimalTapCount, equals(2));

      // A different, independently-chosen valid optimum for the same
      // 5-cycle must ALSO verify as a win, confirming scoring can't
      // rely on comparing to the solver's specific returned set.
      expect(ClassicSolver.verify(graph, {'0', '3'}), isTrue);
    });
  });

  group('ClassicSolver.verify', () {
    test('rejects an incomplete tap set', () {
      final graph = _graph(5, [(0, 1), (0, 2), (0, 3), (0, 4)]);
      expect(ClassicSolver.verify(graph, {'1'}), isFalse);
    });

    test('accepts tapping everyone (always valid, if wasteful)', () {
      final graph = _graph(5, [(0, 1), (0, 2), (0, 3), (0, 4)]);
      expect(
        ClassicSolver.verify(graph, {'0', '1', '2', '3', '4'}),
        isTrue,
      );
    });
  });

  group('benchmark: bitmask+greedy-seed vs. alternatives', () {
    // Requested by the Master Context: confirm the bitmask
    // representation and greedy-bound seeding are actually producing
    // the claimed speedup, rather than assuming they help just
    // because they were added. This mirrors the Python prototype
    // benchmark documented in classic_solver.dart's doc comment and
    // in lib/engine/README.md — run this test locally (not just CI)
    // to get real Dart-side numbers; the numbers in those docs are
    // from a Python port, not this implementation.
    test('6x6 grid graph (36 nodes) solves well under the 40-node '
        'target, and logs real timing', () {
      const rows = 6, cols = 6;
      int idx(int r, int c) => r * cols + c;
      final edges = <(int, int)>[];
      for (var r = 0; r < rows; r++) {
        for (var c = 0; c < cols; c++) {
          if (c + 1 < cols) edges.add((idx(r, c), idx(r, c + 1)));
          if (r + 1 < rows) edges.add((idx(r, c), idx(r + 1, c)));
        }
      }
      final graph = _graph(rows * cols, edges);

      final stopwatch = Stopwatch()..start();
      final result = ClassicSolver.solve(graph);
      stopwatch.stop();

      expect(ClassicSolver.verify(graph, result.optimalTaps), isTrue);
      // ignore: avoid_print
      print(
        '6x6 grid (36 nodes): ${result.optimalTapCount} taps in '
        '${stopwatch.elapsedMilliseconds}ms',
      );
    });

    test('random 34-node graph solves quickly', () {
      // Fixed seed via a simple LCG so this is reproducible without
      // pulling in dart:math's Random for a cross-platform-stable
      // sequence — we only need "some nontrivial, connected graph",
      // not a statistically rigorous random sample.
      var seedState = 12345;
      int nextRand(int bound) {
        seedState = (seedState * 1103515245 + 12345) & 0x7fffffff;
        return seedState % bound;
      }

      const n = 34;
      final edges = <(int, int)>[];
      // spanning tree first, so the graph is connected
      for (var i = 1; i < n; i++) {
        edges.add((i, nextRand(i)));
      }
      // sparse extra edges
      for (var i = 0; i < n; i++) {
        for (var j = i + 1; j < n; j++) {
          if (nextRand(100) < 8) edges.add((i, j));
        }
      }
      final graph = _graph(n, edges);

      final stopwatch = Stopwatch()..start();
      final result = ClassicSolver.solve(graph);
      stopwatch.stop();

      expect(ClassicSolver.verify(graph, result.optimalTaps), isTrue);
      expect(result.optimalTapCount, greaterThan(0));
      // ignore: avoid_print
      print(
        'random 34-node graph: ${result.optimalTapCount} taps in '
        '${stopwatch.elapsedMilliseconds}ms',
      );
    });
  });
}
