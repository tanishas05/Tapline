// Pure supply computation for Capacity mode — the exact Master
// Context formula, computed per node. capacity_solver.dart's
// verify() only returns pass/fail for the whole graph; the live gauge
// (Phase 4 item 1) and the hint engine (item 4) both need the actual
// per-node number, so it lives here rather than being computed ad hoc
// in two different places.
//
// Deliberately reimplements the same arithmetic capacity_solver.dart
// already has internally (its private supplyOf) rather than exposing
// that private helper: this is presentation-layer code — feeds a
// gauge, feeds a hint — not solving anything, and duplicating four
// lines of arithmetic is a smaller risk than widening the engine's
// public surface for a UI concern. Cross-checked against the solver's
// own verify() in the test file: for many random tapped sets, "every
// node's capacitySupplyOf >= its demand" always agrees with what
// CapacitySolver.verify says.

import '../../engine/engine.dart';

/// `total_supply(v) = cap(v)*tapped(v) + 0.5 * sum(cap(u) for tapped
/// neighbors u)` — the Master Context formula, exactly, for the
/// single node [nodeId].
double capacitySupplyOf(Graph graph, Set<String> tappedIds, String nodeId) {
  final v = graph.indexOf(nodeId);
  final node = graph.nodeAt(v);
  var supply = tappedIds.contains(nodeId) ? node.capacity : 0.0;
  for (final u in graph.neighbors(v)) {
    if (tappedIds.contains(graph.idAt(u))) {
      supply += 0.5 * graph.nodeAt(u).capacity;
    }
  }
  return supply;
}

/// Total over-supply, as a fraction of total demand, for a completed
/// [tappedIds] set — Phase 6's "NO SPILLAGE" achievement.
///
/// Per node, surplus is `max(0, supply - demand)` — a node getting
/// LESS than it needs isn't "negative waste," it just isn't a win yet
/// (and by the time this is called on an actual clear, that can't
/// happen anyway). Summed across every node and divided by total
/// demand, so this reads as a scale-independent percentage rather than
/// a raw number that means something different on an 8-node level than
/// a 25-node one.
///
/// [threshold]'s default of 0.10 (surplus under 10% of total demand)
/// is a placeholder in the exact same spirit as
/// difficulty_tiers.dart's timeLimitSecondsByTier and
/// coin_economy.dart's payout tables: a real number so the achievement
/// does something now, not a playtested one. TODO(playtesting, Phase
/// 6+): revisit once real completed-attempt data exists to see what
/// fraction of clears this actually rewards.
///
/// Zero total demand (a degenerate all-hub, no-leaf graph) returns
/// `false` rather than dividing by zero — nothing to be "efficient"
/// about on a level with no demand to speak of.
bool isCapacityClearEfficient(
  Graph graph,
  Set<String> tappedIds, {
  double threshold = 0.10,
}) {
  var totalDemand = 0.0;
  var totalSurplus = 0.0;
  for (var v = 0; v < graph.nodeCount; v++) {
    final node = graph.nodeAt(v);
    final supply = capacitySupplyOf(graph, tappedIds, node.id);
    totalDemand += node.demand;
    final surplus = supply - node.demand;
    if (surplus > 0) totalSurplus += surplus;
  }
  if (totalDemand <= 0) return false;
  return (totalSurplus / totalDemand) <= threshold;
}
