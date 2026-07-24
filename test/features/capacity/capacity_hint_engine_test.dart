import 'package:tapline/engine/engine.dart';
import 'package:tapline/features/capacity/capacity_hint_engine.dart';
import 'package:test/test.dart';

void main() {
  group('computeCapacityHint', () {
    test('everyone satisfied: both fields null', () {
      final graph = Graph.undirected(
        nodes: const [
          GraphNode(id: 'a', capacity: 5, demand: 5),
        ],
        edges: const [],
      );
      final hint = computeCapacityHint(
        graph: graph,
        exampleSolution: {'a'},
        tappedNodeIds: {'a'},
      );
      expect(hint.mostUnderSuppliedNodeId, isNull);
      expect(hint.suggestedTapNodeId, isNull);
    });

    test('the fix can be a NEIGHBOR of the worst node, not the node '
        'itself — a hungry leaf whose own capacity can\'t cover it, '
        'but its hub\'s spillover can', () {
      // hub_a (cap 14) -> leaf_a spillover 0.5*14=7, enough for
      // leaf_a's demand of 6; leaf_a's own capacity (1) alone isn't.
      final graph = Graph.undirected(
        nodes: const [
          GraphNode(id: 'hub_a', capacity: 14, demand: 2),
          GraphNode(id: 'leaf_a', capacity: 1, demand: 6),
        ],
        edges: const [GraphEdge('hub_a', 'leaf_a')],
      );
      final hint = computeCapacityHint(
        graph: graph,
        exampleSolution: {'hub_a'},
        tappedNodeIds: {},
      );
      expect(hint.mostUnderSuppliedNodeId, 'leaf_a');
      expect(hint.suggestedTapNodeId, 'hub_a');
    });

    test(
      'prioritizes the candidate contributing MOST to the worst '
      "node specifically, not just whichever has more raw capacity",
      () {
        final graph = Graph.undirected(
          nodes: const [
            GraphNode(id: 'target', capacity: 1, demand: 10),
            GraphNode(id: 'helperA', capacity: 4, demand: 1),
            GraphNode(id: 'helperB', capacity: 8, demand: 1),
          ],
          edges: const [
            GraphEdge('target', 'helperA'),
            GraphEdge('target', 'helperB'),
          ],
        );
        final hint = computeCapacityHint(
          graph: graph,
          exampleSolution: {'helperA', 'helperB'},
          tappedNodeIds: {},
        );
        expect(hint.mostUnderSuppliedNodeId, 'target');
        // helperB contributes 0.5*8=4 to target, helperA only 0.5*4=2
        expect(hint.suggestedTapNodeId, 'helperB');
      },
    );

    test(
      'a candidate with huge capacity but NO connection to the worst '
      'node loses to a smaller candidate that actually touches it — '
      'relevance beats raw magnitude',
      () {
        // two disjoint clusters: hub_a is wildly overpowered (cap
        // 100) but irrelevant to cluster B, where hub_b (cap 2) is
        // the only thing that can actually help leaf_b's cluster.
        final graph = Graph.undirected(
          nodes: const [
            GraphNode(id: 'hub_a', capacity: 100, demand: 1),
            GraphNode(id: 'leaf_a', capacity: 1, demand: 1),
            GraphNode(id: 'hub_b', capacity: 2, demand: 5),
            GraphNode(id: 'leaf_b', capacity: 1, demand: 1),
          ],
          edges: const [
            GraphEdge('hub_a', 'leaf_a'),
            GraphEdge('hub_b', 'leaf_b'),
          ],
        );
        final hint = computeCapacityHint(
          graph: graph,
          exampleSolution: {'hub_a', 'hub_b'},
          tappedNodeIds: {},
        );
        expect(hint.mostUnderSuppliedNodeId, 'hub_b'); // deficit 5, worst
        expect(hint.suggestedTapNodeId, 'hub_b'); // hub_a doesn't touch it
      },
    );

    test('already-tapped optimal nodes are never suggested again', () {
      final graph = Graph.undirected(
        nodes: const [
          GraphNode(id: 'hub', capacity: 10, demand: 2),
          GraphNode(id: 'leaf', capacity: 1, demand: 6),
        ],
        edges: const [GraphEdge('hub', 'leaf')],
      );
      final hint = computeCapacityHint(
        graph: graph,
        exampleSolution: {'hub'},
        tappedNodeIds: {'hub'}, // already tapped — nothing left to suggest
      );
      // leaf still under-supplied (0.5*10=5 < 6)
      expect(hint.mostUnderSuppliedNodeId, 'leaf');
      expect(hint.suggestedTapNodeId, isNull);
    });
  });
}
