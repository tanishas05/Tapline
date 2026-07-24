// Pure hint-selection logic for Classic — Phase 3 item 5. Factored out
// as a standalone function (same reasoning as outcome_logic.dart) so
// it's verifiable under plain `dart test` without a running app.
//
// Classic-specific, not folded into the shared GameplayController:
// "cover the most currently-uncovered nodes" is Classic's own notion
// of coverage (closed neighborhoods). Capacity's analogous hint would
// be about unmet demand contribution and Signal's about reachability
// — related in spirit, not the same computation — so each mode gets
// its own hint engine when it's built, the same way each mode gets
// its own solver in lib/engine/.

import '../../engine/engine.dart';

/// Returns the id of the untapped node from [exampleSolution] that
/// would cover the most currently-uncovered nodes if tapped next —
/// Phase 3: "prioritize ... the one that would cover the most
/// currently-uncovered nodes, for teaching value." Returns null if
/// every node in [exampleSolution] is already tapped (no hint left to
/// give — the player has already found the full optimal set, even if
/// [GameplayController.isFullySatisfied] hasn't fired yet because
/// they haven't hit the exact optimum tap count some other way).
///
/// Ties (multiple candidates covering the same number of new nodes)
/// resolve to whichever [exampleSolution] iterates first — Sets in
/// Dart preserve insertion order, and [Level.exampleSolution] is
/// exactly the solver's own [Solved.optimalTaps], so this is stable
/// and reproducible for a given level, not an arbitrary pick.
String? nextClassicHint({
  required Graph graph,
  required Set<String> exampleSolution,
  required Set<String> tappedNodeIds,
}) {
  final candidates = exampleSolution.difference(tappedNodeIds);
  if (candidates.isEmpty) return null;

  final currentlyCovered = <int>{};
  for (final tappedId in tappedNodeIds) {
    currentlyCovered.addAll(graph.closedNeighborhood(graph.indexOf(tappedId)));
  }

  String? best;
  var bestNewCoverage = -1;
  for (final candidateId in candidates) {
    final closed = graph.closedNeighborhood(graph.indexOf(candidateId));
    final newCoverage =
        closed.where((i) => !currentlyCovered.contains(i)).length;
    if (newCoverage > bestNewCoverage) {
      bestNewCoverage = newCoverage;
      best = candidateId;
    }
  }
  return best;
}
