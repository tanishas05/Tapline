// Pure forward-reachability for Signal mode — Phase 5 item 2's "cheap
// traversal, not a re-solve." signal_solver.dart's verify() (used by
// GameplayController via verifyWin, unmodified from Phase 3) only
// answers "does this driver set win," a single bool for the whole
// graph — the live per-node visualization (driver / controlled /
// uncontrolled) and the hint engine's "which candidate reaches the
// most new ground" prioritization both need the actual per-node
// reachable set, so it's computed once here and shared between them,
// same reasoning as capacity_supply.dart in Phase 4.

import '../../engine/engine.dart';

/// Every node reachable by following directed edges forward from
/// [driverIds] (inclusive of the drivers themselves) — plain BFS/DFS
/// over [Graph.neighbors], the same traversal signal_solver.dart's
/// own verify()/checkSolvability use internally, just exposed here at
/// per-node granularity instead of collapsed to a single bool.
Set<String> signalReachableFrom(Graph graph, Set<String> driverIds) {
  final seenIndices = <int>{};
  final stack = <int>[];
  for (final id in driverIds) {
    final index = graph.indexOf(id);
    if (seenIndices.add(index)) stack.add(index);
  }
  while (stack.isNotEmpty) {
    final u = stack.removeLast();
    for (final v in graph.neighbors(u)) {
      if (seenIndices.add(v)) stack.add(v);
    }
  }
  return {for (final index in seenIndices) graph.idAt(index)};
}
