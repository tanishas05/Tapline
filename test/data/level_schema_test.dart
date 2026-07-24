import 'package:tapline/data/level_schema.dart';
import 'package:tapline/engine/engine.dart';
import 'package:test/test.dart';

void main() {
  group('Level JSON round-trip', () {
    test('preserves all fields exactly for a small hand-built level', () {
      final level = Level(
        id: 'unit_test_001',
        mode: GameMode.classic,
        difficultyTier: DifficultyTier.small,
        nodes: const [
          GraphNode(id: 'hub', position: GraphPoint(500, 500)),
          GraphNode(id: 'leaf0', position: GraphPoint(600, 500)),
          GraphNode(id: 'leaf1', position: GraphPoint(400, 500)),
        ],
        edges: const [
          GraphEdge('hub', 'leaf0'),
          GraphEdge('hub', 'leaf1'),
        ],
        optimum: 1,
        exampleSolution: const {'hub'},
        timeLimitSeconds: 45,
      );

      final json = level.toJson();
      expect(json['id'], 'unit_test_001');
      expect(json['mode'], 'classic');
      expect(json['difficultyTier'], 'small');
      expect(json['directed'], isFalse);
      expect(json['optimum'], 1);
      expect(json['exampleSolution'], ['hub']);
      expect(json['timeLimitSeconds'], 45);

      final decoded = Level.fromJson(json);
      expect(decoded.id, level.id);
      expect(decoded.mode, level.mode);
      expect(decoded.difficultyTier, level.difficultyTier);
      expect(decoded.directed, level.directed);
      expect(decoded.optimum, level.optimum);
      expect(decoded.exampleSolution, level.exampleSolution);
      expect(decoded.timeLimitSeconds, level.timeLimitSeconds);
      expect(decoded.nodes.length, level.nodes.length);
      expect(decoded.edges.length, level.edges.length);
      for (var i = 0; i < level.nodes.length; i++) {
        expect(decoded.nodes[i].id, level.nodes[i].id);
        expect(decoded.nodes[i].position?.x, level.nodes[i].position?.x);
        expect(decoded.nodes[i].position?.y, level.nodes[i].position?.y);
        expect(decoded.nodes[i].capacity, level.nodes[i].capacity);
        expect(decoded.nodes[i].demand, level.nodes[i].demand);
      }
      for (var i = 0; i < level.edges.length; i++) {
        expect(decoded.edges[i].from, level.edges[i].from);
        expect(decoded.edges[i].to, level.edges[i].to);
      }
    });

    test('directed is derived from mode, never trusted from JSON', () {
      // A hand-edited/corrupted JSON file claiming "directed": false
      // for a Signal level must NOT change the reconstructed Level's
      // behavior — Level.directed is a computed getter driven by
      // mode alone, so toGraph() still builds a directed graph.
      final tamperedJson = {
        'id': 'tampered',
        'mode': 'signal',
        'difficultyTier': 'small',
        'directed': false, // deliberately wrong
        'nodes': [
          {'id': 'a', 'x': 0.0, 'y': 0.0, 'capacity': 0.0, 'demand': 0.0},
          {'id': 'b', 'x': 10.0, 'y': 0.0, 'capacity': 0.0, 'demand': 0.0},
        ],
        'edges': [
          {'from': 'a', 'to': 'b'},
        ],
        'optimum': 1,
        'exampleSolution': ['a'],
        'timeLimitSeconds': 45,
      };
      final decoded = Level.fromJson(tamperedJson);
      expect(decoded.directed, isTrue);
      expect(decoded.toGraph().directed, isTrue);
    });

    test(
        'toGraph() builds a directed graph for Signal, undirected '
        'otherwise', () {
      final signalLevel = Level(
        id: 's',
        mode: GameMode.signal,
        difficultyTier: DifficultyTier.small,
        nodes: const [GraphNode(id: 'a'), GraphNode(id: 'b')],
        edges: const [GraphEdge('a', 'b')],
        optimum: 1,
        exampleSolution: const {'a'},
        timeLimitSeconds: 45,
      );
      expect(signalLevel.toGraph().directed, isTrue);

      final classicLevel = Level(
        id: 'c',
        mode: GameMode.classic,
        difficultyTier: DifficultyTier.small,
        nodes: const [GraphNode(id: 'a'), GraphNode(id: 'b')],
        edges: const [GraphEdge('a', 'b')],
        optimum: 1,
        exampleSolution: const {'a'},
        timeLimitSeconds: 45,
      );
      expect(classicLevel.toGraph().directed, isFalse);
    });

    test('a node with no position round-trips as null, not (0,0)', () {
      final level = Level(
        id: 'no_pos',
        mode: GameMode.classic,
        difficultyTier: DifficultyTier.small,
        nodes: const [GraphNode(id: 'a')], // position defaults to null
        edges: const [],
        optimum: 0,
        exampleSolution: const <String>{},
        timeLimitSeconds: 45,
      );
      final decoded = Level.fromJson(level.toJson());
      expect(decoded.nodes.single.position, isNull);
    });
  });

  group('Level constructor invariant', () {
    test('asserts exampleSolution.length == optimum', () {
      expect(
        () => Level(
          id: 'bad',
          mode: GameMode.classic,
          difficultyTier: DifficultyTier.small,
          nodes: const [GraphNode(id: 'a')],
          edges: const [],
          optimum: 2, // wrong: exampleSolution below has 1 member
          exampleSolution: const {'a'},
          timeLimitSeconds: 45,
        ),
        throwsA(isA<AssertionError>()),
      );
    });
  });
}
