import 'package:tapline/engine/engine.dart';
import 'package:tapline/features/capacity/capacity_supply.dart';
import 'package:test/test.dart';

/// hub (cap 10, dem 5) — leaf1 (cap 2, dem 3) — leaf2 (cap 2, dem 1),
/// a star: hub connects to both leaves, leaves don't connect to each
/// other.
Graph _starGraph() {
  return Graph.undirected(
    nodes: const [
      GraphNode(id: 'hub', capacity: 10, demand: 5),
      GraphNode(id: 'leaf1', capacity: 2, demand: 3),
      GraphNode(id: 'leaf2', capacity: 2, demand: 1),
    ],
    edges: const [
      GraphEdge('hub', 'leaf1'),
      GraphEdge('hub', 'leaf2'),
    ],
  );
}

void main() {
  group('capacitySupplyOf — formula correctness', () {
    test('a tapped node supplies itself its full capacity', () {
      final graph = _starGraph();
      expect(capacitySupplyOf(graph, {'hub'}, 'hub'), 10.0);
    });

    test('an untapped node gets 0.5x capacity from each tapped '
        'neighbor, nothing from non-neighbors', () {
      final graph = _starGraph();
      // hub tapped: both leaves get 0.5*10=5 each (they're not
      // neighbors of each other, so no cross-contribution).
      expect(capacitySupplyOf(graph, {'hub'}, 'leaf1'), 5.0);
      expect(capacitySupplyOf(graph, {'hub'}, 'leaf2'), 5.0);
    });

    test('a leaf tapped only reaches the hub, not the other leaf', () {
      final graph = _starGraph();
      expect(capacitySupplyOf(graph, {'leaf1'}, 'hub'), 1.0); // 0.5*2
      expect(capacitySupplyOf(graph, {'leaf1'}, 'leaf2'), 0.0);
      expect(capacitySupplyOf(graph, {'leaf1'}, 'leaf1'), 2.0); // self
    });

    test('contributions from multiple tapped neighbors add up', () {
      final graph = _starGraph();
      // both leaves tapped: hub gets 0.5*2 + 0.5*2 = 2, on top of
      // whatever its own tap would add (not tapped here, so just 2).
      expect(capacitySupplyOf(graph, {'leaf1', 'leaf2'}, 'hub'), 2.0);
    });

    test('nothing tapped means zero supply everywhere', () {
      final graph = _starGraph();
      expect(capacitySupplyOf(graph, {}, 'hub'), 0.0);
      expect(capacitySupplyOf(graph, {}, 'leaf1'), 0.0);
    });
  });

  group('capacitySupplyOf agrees with CapacitySolver.verify', () {
    void checkAgreement(Graph graph, Set<String> tapped) {
      final allSatisfied = [
        for (var v = 0; v < graph.nodeCount; v++)
          capacitySupplyOf(graph, tapped, graph.idAt(v)) >=
              graph.nodeAt(v).demand - 1e-9,
      ].every((ok) => ok);
      expect(allSatisfied, CapacitySolver.verify(graph, tapped));
    }

    test('hub alone: satisfied per-node math matches verify() == true',
        () {
      checkAgreement(_starGraph(), {'hub'});
    });

    test('nothing tapped: unsatisfied per-node math matches '
        'verify() == false', () {
      checkAgreement(_starGraph(), {});
    });

    test('one leaf only: unsatisfied per-node math matches '
        'verify() == false', () {
      checkAgreement(_starGraph(), {'leaf1'});
    });

    test('everyone tapped: satisfied per-node math matches '
        'verify() == true', () {
      checkAgreement(_starGraph(), {'hub', 'leaf1', 'leaf2'});
    });

    test('both leaves, hub untapped: still under-supplies the hub '
        '(2 < 5), matches verify() == false', () {
      checkAgreement(_starGraph(), {'leaf1', 'leaf2'});
    });
  });

  group('isCapacityClearEfficient — Phase 6 achievement math', () {
    Graph soloGraph({required double capacity, required double demand}) {
      return Graph.undirected(
        nodes: [GraphNode(id: 'solo', capacity: capacity, demand: demand)],
        edges: const [],
      );
    }

    test('exact match (zero surplus) is efficient', () {
      final graph = soloGraph(capacity: 5, demand: 5);
      expect(isCapacityClearEfficient(graph, {'solo'}), isTrue);
    });

    test('wildly over-tapped (900% surplus) is not efficient', () {
      final graph = soloGraph(capacity: 10, demand: 1);
      expect(isCapacityClearEfficient(graph, {'solo'}), isFalse);
    });

    test('right at a threshold counts as efficient (<=, not <) — '
        'uses an exact binary fraction (0.25) rather than 0.10, since '
        '1.1 - 1.0 is NOT exactly 0.1 in double-precision arithmetic '
        'and a naive boundary test here would be flaky', () {
      final graph = soloGraph(capacity: 1.25, demand: 1.0); // exact 25%
      expect(
        isCapacityClearEfficient(graph, {'solo'}, threshold: 0.25),
        isTrue,
      );
    });

    test('clearly past a threshold does not count — margin is well '
        'outside floating-point rounding range on purpose', () {
      final graph = soloGraph(capacity: 1.26, demand: 1.0); // 26% > 25%
      expect(
        isCapacityClearEfficient(graph, {'solo'}, threshold: 0.25),
        isFalse,
      );
    });

    test('a custom threshold is actually honored, not hardcoded', () {
      final graph = soloGraph(capacity: 1.4, demand: 1.0); // 40% surplus
      expect(isCapacityClearEfficient(graph, {'solo'}), isFalse);
      expect(
        isCapacityClearEfficient(graph, {'solo'}, threshold: 0.5),
        isTrue,
      );
    });

    test('zero total demand is never "efficient" — nothing to be '
        'efficient about', () {
      final graph = soloGraph(capacity: 5, demand: 0);
      expect(isCapacityClearEfficient(graph, {'solo'}), isFalse);
    });

    test('surplus sums correctly across multiple nodes, not just the '
        'first one', () {
      // hub tapped alone: hub itself exact (10 supply, 10 demand, 0
      // surplus), each leaf gets 0.5*10=5 supply against demand 5 each
      // (also exact) — total surplus 0 across all three nodes.
      final graph = Graph.undirected(
        nodes: const [
          GraphNode(id: 'hub', capacity: 10, demand: 10),
          GraphNode(id: 'leaf1', capacity: 2, demand: 5),
          GraphNode(id: 'leaf2', capacity: 2, demand: 5),
        ],
        edges: const [
          GraphEdge('hub', 'leaf1'),
          GraphEdge('hub', 'leaf2'),
        ],
      );
      expect(isCapacityClearEfficient(graph, {'hub'}), isTrue);
    });

    test('a star graph tapped at just the hub is nowhere near '
        'efficient by default — the fixture graph is intentionally '
        'loose, not tuned for this', () {
      expect(isCapacityClearEfficient(_starGraph(), {'hub'}), isFalse);
    });
  });
}
