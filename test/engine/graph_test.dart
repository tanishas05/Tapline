import 'package:test/test.dart';

import 'package:tapline/engine/engine.dart';

void main() {
  group('Graph.undirected', () {
    test('edges connect both directions', () {
      final graph = Graph.undirected(
        nodes: const [
          GraphNode(id: 'a'),
          GraphNode(id: 'b'),
          GraphNode(id: 'c'),
        ],
        edges: const [GraphEdge('a', 'b')],
      );

      final a = graph.indexOf('a');
      final b = graph.indexOf('b');
      final c = graph.indexOf('c');

      expect(graph.neighbors(a), equals([b]));
      expect(graph.neighbors(b), equals([a]));
      expect(graph.neighbors(c), isEmpty);
    });

    test('closedNeighborhood includes the node itself', () {
      final graph = Graph.undirected(
        nodes: const [GraphNode(id: 'a'), GraphNode(id: 'b')],
        edges: const [GraphEdge('a', 'b')],
      );
      final a = graph.indexOf('a');
      expect(graph.closedNeighborhood(a), unorderedEquals([a, graph.indexOf('b')]));
    });

    test('closedNeighborhoodMask matches closedNeighborhood', () {
      final graph = Graph.undirected(
        nodes: const [
          GraphNode(id: 'a'),
          GraphNode(id: 'b'),
          GraphNode(id: 'c'),
        ],
        edges: const [GraphEdge('a', 'b'), GraphEdge('b', 'c')],
      );
      final b = graph.indexOf('b');
      final mask = graph.closedNeighborhoodMask(b);
      for (final index in graph.closedNeighborhood(b)) {
        expect((mask >> index) & 1, equals(1));
      }
    });

    test('duplicate node ids throw', () {
      expect(
        () => Graph.undirected(
          nodes: const [GraphNode(id: 'a'), GraphNode(id: 'a')],
          edges: const [],
        ),
        throwsArgumentError,
      );
    });

    test('edge referencing unknown id throws', () {
      expect(
        () => Graph.undirected(
          nodes: const [GraphNode(id: 'a')],
          edges: const [GraphEdge('a', 'ghost')],
        ),
        throwsArgumentError,
      );
    });

    test('self-loops are ignored rather than corrupting adjacency', () {
      final graph = Graph.undirected(
        nodes: const [GraphNode(id: 'a')],
        edges: const [GraphEdge('a', 'a')],
      );
      expect(graph.neighbors(graph.indexOf('a')), isEmpty);
    });
  });

  group('Graph.directed', () {
    test('edges are one-directional', () {
      final graph = Graph.directed(
        nodes: const [GraphNode(id: 'a'), GraphNode(id: 'b')],
        edges: const [GraphEdge('a', 'b')],
      );
      final a = graph.indexOf('a');
      final b = graph.indexOf('b');
      expect(graph.neighbors(a), equals([b]));
      expect(graph.neighbors(b), isEmpty);
    });
  });

  group('assertBitmaskCapacity', () {
    test('accepts 62 nodes', () {
      final nodes = [for (var i = 0; i < 62; i++) GraphNode(id: 'n$i')];
      final graph = Graph.undirected(nodes: nodes, edges: const []);
      expect(graph.assertBitmaskCapacity, returnsNormally);
    });

    test('rejects 63 nodes', () {
      final nodes = [for (var i = 0; i < 63; i++) GraphNode(id: 'n$i')];
      final graph = Graph.undirected(nodes: nodes, edges: const []);
      expect(graph.assertBitmaskCapacity, throwsStateError);
    });
  });

  group('capacity/demand payload', () {
    test('round-trips through nodeAt', () {
      final graph = Graph.undirected(
        nodes: const [GraphNode(id: 'a', capacity: 4, demand: 2)],
        edges: const [],
      );
      final node = graph.nodeAt(graph.indexOf('a'));
      expect(node.capacity, equals(4));
      expect(node.demand, equals(2));
    });
  });
}
