// Signal's hint selection — Phase 5 item 5: "highlight one required
// driver node ... not yet selected by the player." Among untapped
// nodes in the level's precomputed [Level.exampleSolution] (the
// unmatched-V_in driver set signal_solver.dart's Kuhn's-algorithm
// matching found, refined for any perfectly-matched components — see
// that file's doc comment), prioritizes by how much NEW ground
// tapping it would put under control — same "most new coverage" shape
// as classic_hint_engine.dart, just with reachability standing in for
// closed-neighborhood coverage.
//
// Pure function, same reasoning as every other hint engine in this
// project: worth a `dart test`-verifiable unit.

import '../../engine/engine.dart';
import 'signal_reachability.dart';

String? nextSignalHint({
  required Graph graph,
  required Set<String> exampleSolution,
  required Set<String> tappedNodeIds,
}) {
  final untappedRequired = exampleSolution.difference(tappedNodeIds);
  if (untappedRequired.isEmpty) return null;

  final currentlyReached = signalReachableFrom(graph, tappedNodeIds);

  String? best;
  var bestNewReach = -1;
  for (final candidateId in untappedRequired) {
    final reachIfAdded = signalReachableFrom(
      graph,
      {...tappedNodeIds, candidateId},
    );
    final newReach = reachIfAdded.difference(currentlyReached).length;
    if (newReach > bestNewReach) {
      bestNewReach = newReach;
      best = candidateId;
    }
  }
  return best;
}
