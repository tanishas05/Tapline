import 'capacity_solver.dart';
import 'classic_solver.dart';
import 'graph.dart';
import 'signal_solver.dart';
import 'solve_result.dart';

/// Which of Convoy's three graph problems a [Graph] represents —
/// determines which solver [checkSolvability] and [verifyWin]
/// dispatch to.
enum GameMode { classic, capacity, signal }

/// The entry point the Phase 2 level generator calls for every
/// candidate level: solves [graph] for the given [mode] and reports
/// whether it's valid and winnable, plus — when it is — the exact
/// optimum for star-threshold storage.
///
/// Classic and Signal are always feasible by construction (see
/// `ClassicSolver` and `SignalSolver`); this only meaningfully varies
/// for [GameMode.capacity], where a node's demand can exceed what
/// tapping it and every neighbor could ever supply. The generator
/// should treat [Infeasible] as "reject this candidate and generate
/// another," not something to special-case around downstream.
SolveResult checkSolvability(Graph graph, GameMode mode) {
  return switch (mode) {
    GameMode.classic => ClassicSolver.solve(graph),
    GameMode.capacity => CapacitySolver.solve(graph),
    GameMode.signal => SignalSolver.solve(graph),
  };
}

/// Cheap runtime pass/fail check for a player's proposed tap set,
/// dispatching to the right mode's O(V+E) verify. Never re-solves —
/// this is safe to call on every tap during play, unlike
/// [checkSolvability] which is offline-only.
bool verifyWin(Graph graph, GameMode mode, Set<String> proposedTaps) {
  return switch (mode) {
    GameMode.classic => ClassicSolver.verify(graph, proposedTaps),
    GameMode.capacity => CapacitySolver.verify(graph, proposedTaps),
    GameMode.signal => SignalSolver.verify(graph, proposedTaps),
  };
}
