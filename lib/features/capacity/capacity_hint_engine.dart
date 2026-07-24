// Capacity's hint selection — Phase 4 item 4. Two-part hint, matching
// the brief exactly: (1) the currently most under-supplied node, so
// the player can see WHERE the problem is, and (2) separately, which
// untapped node from the precomputed optimal solution would
// contribute the most toward THAT specific node's remaining deficit —
// not just "most overall new coverage" the way classic_hint_engine.dart
// works, since Capacity's problem is a per-node numeric threshold, not
// a set-coverage one. A candidate that's excellent for some OTHER
// node but contributes nothing to the worst-off node isn't the right
// answer to "how do I fix THIS."
//
// Pure function, same reasoning as classic_hint_engine.dart and
// outcome_logic.dart: this is the one piece of Phase 4 worth a
// `dart test`-verifiable unit.

import '../../engine/engine.dart';
import 'capacity_supply.dart';

class CapacityHint {
  const CapacityHint({this.mostUnderSuppliedNodeId, this.suggestedTapNodeId});

  /// The node with the largest remaining deficit right now, or null
  /// if every node is already satisfied.
  final String? mostUnderSuppliedNodeId;

  /// Among untapped [Level.exampleSolution] nodes, whichever
  /// contributes the most toward [mostUnderSuppliedNodeId]'s deficit
  /// specifically — null if nothing under-supplied remains, or if no
  /// untapped optimal node actually touches the worst-off node (an
  /// edge case the star-cluster construction shouldn't produce, but
  /// this doesn't assume that guarantee holds for hand-authored
  /// levels a future editor might create).
  final String? suggestedTapNodeId;
}

/// Same floating-point tolerance as capacity_solver.dart's own
/// epsilon, so "is this node satisfied" agrees between the solver and
/// this hint logic.
const double _epsilon = 1e-9;

CapacityHint computeCapacityHint({
  required Graph graph,
  required Set<String> exampleSolution,
  required Set<String> tappedNodeIds,
}) {
  String? worstId;
  var worstDeficit = 0.0;
  for (var v = 0; v < graph.nodeCount; v++) {
    final id = graph.idAt(v);
    final deficit = graph.nodeAt(v).demand - capacitySupplyOf(graph, tappedNodeIds, id);
    if (deficit > worstDeficit + _epsilon) {
      worstDeficit = deficit;
      worstId = id;
    }
  }

  if (worstId == null) {
    return const CapacityHint();
  }

  final worstIndex = graph.indexOf(worstId);
  final worstNeighbors = graph.neighbors(worstIndex);
  final candidates = exampleSolution.difference(tappedNodeIds);

  String? bestCandidate;
  var bestContribution = 0.0;
  for (final candidateId in candidates) {
    final candidateIndex = graph.indexOf(candidateId);
    final double contribution;
    if (candidateIndex == worstIndex) {
      contribution = graph.nodeAt(candidateIndex).capacity;
    } else if (worstNeighbors.contains(candidateIndex)) {
      contribution = 0.5 * graph.nodeAt(candidateIndex).capacity;
    } else {
      contribution = 0.0;
    }
    if (contribution > bestContribution) {
      bestContribution = contribution;
      bestCandidate = candidateId;
    }
  }

  return CapacityHint(
    mostUnderSuppliedNodeId: worstId,
    suggestedTapNodeId: bestCandidate,
  );
}
