/// The result of solving a level for its true optimum.
///
/// Use a switch to handle both cases — the sealed hierarchy makes the
/// analyzer flag it if a case is missed:
/// ```dart
/// switch (result) {
///   case Solved(:final optimalTapCount, :final optimalTaps):
///     print('optimum is $optimalTapCount taps: $optimalTaps');
///   case Infeasible():
///     print('reject this level');
/// }
/// ```
sealed class SolveResult {
  const SolveResult();
}

/// A level that can be won. Star thresholds must be computed from
/// [optimalTapCount] alone — never by comparing to [optimalTaps]
/// directly — since a symmetric level can have several equally-valid
/// optimal solutions of the same size.
final class Solved extends SolveResult {
  const Solved({required this.optimalTapCount, required this.optimalTaps});

  final int optimalTapCount;
  final Set<String> optimalTaps;

  @override
  String toString() => 'Solved($optimalTapCount taps: $optimalTaps)';
}

/// A level that cannot be won even by tapping every node. Only
/// possible for Capacity mode — see `CapacitySolver`. The level
/// generator should treat this as "reject and regenerate," not
/// something to special-case around downstream.
final class Infeasible extends SolveResult {
  const Infeasible();

  @override
  String toString() => 'Infeasible()';
}
