import 'package:tapline/engine/engine.dart';
import 'package:tapline/features/signal/signal_hint_engine.dart';
import 'package:test/test.dart';

void main() {
  group('nextSignalHint', () {
    test('single required driver: returns it', () {
      final graph = Graph.directed(
        nodes: const [
          GraphNode(id: 'a'),
          GraphNode(id: 'b'),
          GraphNode(id: 'c'),
        ],
        edges: const [
          GraphEdge('a', 'b'),
          GraphEdge('b', 'c'),
        ],
      );
      final hint = nextSignalHint(
        graph: graph,
        exampleSolution: {'a'},
        tappedNodeIds: {},
      );
      expect(hint, 'a');
    });

    test('every required driver already tapped: returns null', () {
      final graph = Graph.directed(
        nodes: const [GraphNode(id: 'a'), GraphNode(id: 'b')],
        edges: const [GraphEdge('a', 'b')],
      );
      final hint = nextSignalHint(
        graph: graph,
        exampleSolution: {'a'},
        tappedNodeIds: {'a'},
      );
      expect(hint, isNull);
    });

    test(
      'prioritizes the candidate reaching the most NEW ground — two '
      'disjoint chains of very different lengths',
      () {
        // chain A: a -> a1 -> a2 -> a3 -> a4 (5 nodes, driver 'a'
        // reaches all 5). chain B: b -> b1 (2 nodes, driver 'b'
        // reaches 2). 'a' should win.
        final graph = Graph.directed(
          nodes: const [
            GraphNode(id: 'a'),
            GraphNode(id: 'a1'),
            GraphNode(id: 'a2'),
            GraphNode(id: 'a3'),
            GraphNode(id: 'a4'),
            GraphNode(id: 'b'),
            GraphNode(id: 'b1'),
          ],
          edges: const [
            GraphEdge('a', 'a1'),
            GraphEdge('a1', 'a2'),
            GraphEdge('a2', 'a3'),
            GraphEdge('a3', 'a4'),
            GraphEdge('b', 'b1'),
          ],
        );
        final hint = nextSignalHint(
          graph: graph,
          exampleSolution: {'a', 'b'},
          tappedNodeIds: {},
        );
        expect(hint, 'a');
      },
    );

    test('a candidate whose whole chain is already reached by an '
        'existing tap contributes zero new ground and loses to a '
        'fresh one', () {
      // 'a' already tapped, reaching a->a1->a2 (3 nodes). 'a1' is
      // ALSO nominally in exampleSolution (unusual, but tests the
      // math) — tapping it adds nothing new, since a1/a2 are already
      // reached via 'a'. 'b' is a fresh, disjoint chain and should win.
      final graph = Graph.directed(
        nodes: const [
          GraphNode(id: 'a'),
          GraphNode(id: 'a1'),
          GraphNode(id: 'a2'),
          GraphNode(id: 'b'),
          GraphNode(id: 'b1'),
        ],
        edges: const [
          GraphEdge('a', 'a1'),
          GraphEdge('a1', 'a2'),
          GraphEdge('b', 'b1'),
        ],
      );
      final hint = nextSignalHint(
        graph: graph,
        exampleSolution: {'a1', 'b'},
        tappedNodeIds: {'a'},
      );
      expect(hint, 'b');
    });
  });
}
