import 'package:tapline/engine/engine.dart';
import 'package:tapline/features/classic/classic_hint_engine.dart';
import 'package:test/test.dart';

/// hub_a + 3 leaves, hub_b + 1 leaf, hub_c + 2 leaves — three
/// star-clusters, disjoint (matches the shape the Phase 2 generator
/// actually produces), used across several tests below.
Graph _threeClusterGraph() {
  return Graph.undirected(
    nodes: const [
      GraphNode(id: 'hub_a'),
      GraphNode(id: 'a0'),
      GraphNode(id: 'a1'),
      GraphNode(id: 'a2'),
      GraphNode(id: 'hub_b'),
      GraphNode(id: 'b0'),
      GraphNode(id: 'hub_c'),
      GraphNode(id: 'c0'),
      GraphNode(id: 'c1'),
    ],
    edges: const [
      GraphEdge('hub_a', 'a0'),
      GraphEdge('hub_a', 'a1'),
      GraphEdge('hub_a', 'a2'),
      GraphEdge('hub_b', 'b0'),
      GraphEdge('hub_c', 'c0'),
      GraphEdge('hub_c', 'c1'),
    ],
  );
}

void main() {
  group('nextClassicHint', () {
    test('single candidate: returns it regardless of coverage', () {
      final graph = _threeClusterGraph();
      final hint = nextClassicHint(
        graph: graph,
        exampleSolution: {'hub_b'},
        tappedNodeIds: {},
      );
      expect(hint, 'hub_b');
    });

    test('no candidates left: every optimal node already tapped', () {
      final graph = _threeClusterGraph();
      final hint = nextClassicHint(
        graph: graph,
        exampleSolution: {'hub_a', 'hub_b'},
        tappedNodeIds: {'hub_a', 'hub_b'},
      );
      expect(hint, isNull);
    });

    test(
      'prioritizes the candidate covering the most currently-'
      'uncovered nodes — three-way choice, not just a two-way one',
      () {
        final graph = _threeClusterGraph();
        // player has tapped a0 (a leaf, not itself optimal) — this
        // covers {a0, hub_a} already. Remaining fresh coverage if
        // tapped next: hub_a -> {a1,a2} (2 new), hub_b -> {hub_b,b0}
        // (2 new), hub_c -> {hub_c,c0,c1} (3 new). hub_c should win.
        final hint = nextClassicHint(
          graph: graph,
          exampleSolution: {'hub_a', 'hub_b', 'hub_c'},
          tappedNodeIds: {'a0'},
        );
        expect(hint, 'hub_c');
      },
    );

    test('a candidate whose neighborhood is already fully covered '
        'loses to one that still has fresh coverage', () {
      final graph = _threeClusterGraph();
      // hub_a's entire neighborhood is already covered by tapping
      // ALL its leaves individually (unusual, but legal — the player
      // doesn't have to play optimally). hub_b is untouched.
      final hint = nextClassicHint(
        graph: graph,
        exampleSolution: {'hub_a', 'hub_b'},
        tappedNodeIds: {'a0', 'a1', 'a2'},
      );
      expect(hint, 'hub_b');
    });

    test('empty exampleSolution (degenerate) returns null, not a crash',
        () {
      final graph = _threeClusterGraph();
      final hint = nextClassicHint(
        graph: graph,
        exampleSolution: {},
        tappedNodeIds: {},
      );
      expect(hint, isNull);
    });
  });
}
