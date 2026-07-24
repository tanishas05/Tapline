import 'package:test/test.dart';

import 'package:tapline/engine/engine.dart';

void main() {
  group('checkSolvability dispatches to the right solver', () {
    test('GameMode.classic', () {
      final graph = Graph.undirected(
        nodes: const [
          GraphNode(id: 'a'),
          GraphNode(id: 'b'),
          GraphNode(id: 'c'),
        ],
        edges: const [GraphEdge('a', 'b'), GraphEdge('a', 'c')],
      );
      final result = checkSolvability(graph, GameMode.classic) as Solved;
      expect(result.optimalTapCount, equals(1));
    });

    test('GameMode.capacity can report Infeasible', () {
      final graph = Graph.undirected(
        nodes: const [GraphNode(id: 'a', capacity: 1, demand: 100)],
        edges: const [],
      );
      final result = checkSolvability(graph, GameMode.capacity);
      expect(result, isA<Infeasible>());
    });

    test('GameMode.signal', () {
      final graph = Graph.directed(
        nodes: const [
          GraphNode(id: 'a'),
          GraphNode(id: 'b'),
          GraphNode(id: 'c'),
        ],
        edges: const [GraphEdge('a', 'b'), GraphEdge('b', 'c')],
      );
      final result = checkSolvability(graph, GameMode.signal) as Solved;
      expect(result.optimalTapCount, equals(1));
      expect(result.optimalTaps, equals({'a'}));
    });
  });

  group('verifyWin dispatches to the right solver', () {
    test('GameMode.classic', () {
      final graph = Graph.undirected(
        nodes: const [GraphNode(id: 'a'), GraphNode(id: 'b')],
        edges: const [GraphEdge('a', 'b')],
      );
      expect(verifyWin(graph, GameMode.classic, {'a'}), isTrue);
      expect(verifyWin(graph, GameMode.classic, {}), isFalse);
    });

    test('GameMode.capacity', () {
      final graph = Graph.undirected(
        nodes: const [
          GraphNode(id: 'a', capacity: 4, demand: 1),
          GraphNode(id: 'b', capacity: 4, demand: 1),
        ],
        edges: const [GraphEdge('a', 'b')],
      );
      expect(verifyWin(graph, GameMode.capacity, {'a'}), isTrue);
      expect(verifyWin(graph, GameMode.capacity, {}), isFalse);
    });

    test('GameMode.signal', () {
      final graph = Graph.directed(
        nodes: const [GraphNode(id: 'a'), GraphNode(id: 'b')],
        edges: const [GraphEdge('a', 'b')],
      );
      expect(verifyWin(graph, GameMode.signal, {'a'}), isTrue);
      expect(verifyWin(graph, GameMode.signal, {'b'}), isFalse);
    });
  });
}
