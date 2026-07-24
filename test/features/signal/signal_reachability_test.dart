import 'package:tapline/engine/engine.dart';
import 'package:tapline/features/signal/signal_reachability.dart';
import 'package:test/test.dart';

void main() {
  group('signalReachableFrom', () {
    test('a chain: driver at the head reaches everything', () {
      final graph = Graph.directed(
        nodes: const [
          GraphNode(id: 'a'),
          GraphNode(id: 'b'),
          GraphNode(id: 'c'),
          GraphNode(id: 'd'),
        ],
        edges: const [
          GraphEdge('a', 'b'),
          GraphEdge('b', 'c'),
          GraphEdge('c', 'd'),
        ],
      );
      expect(
        signalReachableFrom(graph, {'a'}),
        {'a', 'b', 'c', 'd'},
      );
    });

    test('a driver in the middle of a chain only reaches forward, '
        'never backward', () {
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
      expect(signalReachableFrom(graph, {'b'}), {'b', 'c'});
    });

    test('two disjoint chains: a driver in one never reaches the other',
        () {
      final graph = Graph.directed(
        nodes: const [
          GraphNode(id: 'a'),
          GraphNode(id: 'b'),
          GraphNode(id: 'x'),
          GraphNode(id: 'y'),
        ],
        edges: const [
          GraphEdge('a', 'b'),
          GraphEdge('x', 'y'),
        ],
      );
      expect(signalReachableFrom(graph, {'a'}), {'a', 'b'});
    });

    test('a pure cycle: any single node in it reaches the whole cycle',
        () {
      final graph = Graph.directed(
        nodes: const [
          GraphNode(id: 'a'),
          GraphNode(id: 'b'),
          GraphNode(id: 'c'),
        ],
        edges: const [
          GraphEdge('a', 'b'),
          GraphEdge('b', 'c'),
          GraphEdge('c', 'a'),
        ],
      );
      expect(signalReachableFrom(graph, {'b'}), {'a', 'b', 'c'});
    });

    test('no drivers: nothing is reachable', () {
      final graph = Graph.directed(
        nodes: const [GraphNode(id: 'a'), GraphNode(id: 'b')],
        edges: const [GraphEdge('a', 'b')],
      );
      expect(signalReachableFrom(graph, {}), isEmpty);
    });

    test('multiple drivers union their reachable sets', () {
      final graph = Graph.directed(
        nodes: const [
          GraphNode(id: 'a'),
          GraphNode(id: 'b'),
          GraphNode(id: 'x'),
          GraphNode(id: 'y'),
        ],
        edges: const [
          GraphEdge('a', 'b'),
          GraphEdge('x', 'y'),
        ],
      );
      expect(
        signalReachableFrom(graph, {'a', 'x'}),
        {'a', 'b', 'x', 'y'},
      );
    });
  });
}
