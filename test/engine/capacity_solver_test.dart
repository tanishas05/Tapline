import 'package:test/test.dart';

import 'package:tapline/engine/engine.dart';

void main() {
  group('CapacitySolver.solve — hand-verified cases', () {
    test('3-leaf star, boundary case: optimum is 1 (tap the hub)', () {
      // hub cap 6 dem 1; each leaf cap 2 dem 3. Tapping just the hub:
      // supply(leaf) = 0 + 0.5*6 = 3, exactly meeting demand 3 — this
      // is deliberately an exact ">=" boundary, not slack, to catch a
      // solver that accidentally uses strict ">".
      final graph = Graph.undirected(
        nodes: const [
          GraphNode(id: 'hub', capacity: 6, demand: 1),
          GraphNode(id: 'leaf1', capacity: 2, demand: 3),
          GraphNode(id: 'leaf2', capacity: 2, demand: 3),
          GraphNode(id: 'leaf3', capacity: 2, demand: 3),
        ],
        edges: const [
          GraphEdge('hub', 'leaf1'),
          GraphEdge('hub', 'leaf2'),
          GraphEdge('hub', 'leaf3'),
        ],
      );

      final result = CapacitySolver.solve(graph) as Solved;
      expect(result.optimalTapCount, equals(1));
      expect(result.optimalTaps, equals({'hub'}));
      expect(CapacitySolver.verify(graph, result.optimalTaps), isTrue);
    });

    test('3-node path forced to tap everyone', () {
      // A-B-C path; cap [4,2,4], dem [3,5,3]. B's demand of 5 can only
      // ever receive 2 (from A) + 2 (from C) = 4 when both neighbors
      // are tapped without B itself — B needs all three taps: hand
      // verified by exhausting every 2-tap subset (none reaches 5).
      final graph = Graph.undirected(
        nodes: const [
          GraphNode(id: 'a', capacity: 4, demand: 3),
          GraphNode(id: 'b', capacity: 2, demand: 5),
          GraphNode(id: 'c', capacity: 4, demand: 3),
        ],
        edges: const [GraphEdge('a', 'b'), GraphEdge('b', 'c')],
      );

      final result = CapacitySolver.solve(graph) as Solved;
      expect(result.optimalTapCount, equals(3));
      expect(CapacitySolver.verify(graph, result.optimalTaps), isTrue);
    });

    test('infeasible: single node whose demand exceeds max possible '
        'supply is rejected, not silently mishandled', () {
      final graph = Graph.undirected(
        nodes: const [GraphNode(id: 'lonely', capacity: 5, demand: 10)],
        edges: const [],
      );
      final result = CapacitySolver.solve(graph);
      expect(result, isA<Infeasible>());
    });

    test('feasible only because a neighbor closes the gap', () {
      // node alone can't meet its own demand (cap 4 < dem 6), but with
      // its one neighbor tapped too, 4 + 0.5*4 = 6 exactly meets it.
      final graph = Graph.undirected(
        nodes: const [
          GraphNode(id: 'a', capacity: 4, demand: 6),
          GraphNode(id: 'b', capacity: 4, demand: 0),
        ],
        edges: const [GraphEdge('a', 'b')],
      );
      final result = CapacitySolver.solve(graph) as Solved;
      expect(result.optimalTapCount, equals(2));
      expect(CapacitySolver.verify(graph, result.optimalTaps), isTrue);
    });
  });

  group('CapacitySolver.verify', () {
    test('rejects a tap set that falls short of demand', () {
      final graph = Graph.undirected(
        nodes: const [
          GraphNode(id: 'hub', capacity: 6, demand: 1),
          GraphNode(id: 'leaf', capacity: 2, demand: 3),
        ],
        edges: const [GraphEdge('hub', 'leaf')],
      );
      expect(CapacitySolver.verify(graph, {}), isFalse);
    });
  });

  group('benchmark: lower-bound pruning on larger graphs', () {
    // Same spirit as ClassicSolver's benchmark test — confirms this
    // solves comfortably within Capacity's level-size range and logs
    // real timing. See lib/engine/README.md for the Python-prototype
    // numbers this is modeled on; re-run this locally for Dart-side
    // numbers.
    test('random 28-node graph with capacity/demand solves quickly',
        () {
      var seedState = 54321;
      int nextRand(int bound) {
        seedState = (seedState * 1103515245 + 12345) & 0x7fffffff;
        return seedState % bound;
      }

      const capOptions = [2.0, 4.0, 6.0, 8.0];
      const demOptions = [2.0, 4.0, 6.0];

      const n = 28;
      final nodes = [
        for (var i = 0; i < n; i++)
          GraphNode(
            id: '$i',
            capacity: capOptions[nextRand(capOptions.length)],
            demand: demOptions[nextRand(demOptions.length)],
          ),
      ];
      final edges = <GraphEdge>[];
      for (var i = 1; i < n; i++) {
        edges.add(GraphEdge('$i', '${nextRand(i)}'));
      }
      for (var i = 0; i < n; i++) {
        for (var j = i + 1; j < n; j++) {
          if (nextRand(100) < 8) edges.add(GraphEdge('$i', '$j'));
        }
      }
      final graph = Graph.undirected(nodes: nodes, edges: edges);

      final stopwatch = Stopwatch()..start();
      final result = CapacitySolver.solve(graph);
      stopwatch.stop();

      // ignore: avoid_print
      print(
        'random 28-node capacity graph: $result in '
        '${stopwatch.elapsedMilliseconds}ms',
      );

      switch (result) {
        case Solved(:final optimalTaps):
          expect(CapacitySolver.verify(graph, optimalTaps), isTrue);
        case Infeasible():
          fail('unexpected infeasible result on a random dense-ish graph');
      }
    });
  });
}
