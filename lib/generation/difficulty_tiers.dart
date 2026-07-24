// Single source of truth for every tunable number the Phase 2
// generators read — Phase 2 item 2: "define a single difficultyTier
// -> timeLimitSeconds table (a const Map or small config class) in
// one place, not scattered through the generator."
//
// TIME LIMITS ARE PLACEHOLDERS. Phase 2's brief is explicit that
// these aren't to be guessed as "real" numbers here — they need
// actual playtesting once gameplay (Phase 3+) exists to play against.
// Every value in [timeLimitSecondsByTier] is a TODO, not a balanced
// number. Node-count/cluster-count ranges are less arbitrary (they're
// load-bearing for the star-cluster/chain constructions and were
// swept for construct-then-verify safety — see
// classic_capacity_generator.dart and signal_generator.dart's doc
// comments) but the exact boundaries are still first-pass estimates,
// not the product of actual playtesting either.

import 'dart:math';

import '../data/level_schema.dart';

/// Inclusive min/max integer range, e.g. a node count or cluster
/// count for a tier.
class IntRange {
  const IntRange(this.min, this.max) : assert(min <= max);

  final int min;
  final int max;

  int roll(Random random) => min + random.nextInt(max - min + 1);
}

/// Inclusive min/max double range, e.g. a demand or capacity value.
class DoubleRange {
  const DoubleRange(this.min, this.max) : assert(min <= max);

  final double min;
  final double max;

  double roll(Random random) => min + random.nextDouble() * (max - min);
}

// ---------------------------------------------------------------------
// Shared: time limit
// ---------------------------------------------------------------------

/// TODO(playtesting): placeholder countdown values. Tier-keyed only —
/// Master Context: timeLimit scales off difficultyTier, never off
/// optimum, and Phase 2 asks for exactly one shared tier->seconds
/// table, not a separate one per mode.
const Map<DifficultyTier, int> timeLimitSecondsByTier = {
  DifficultyTier.small: 45,
  DifficultyTier.medium: 90,
  DifficultyTier.large: 150,
};

// ---------------------------------------------------------------------
// Classic / Capacity — shared node-count baseline (Phase 2 item 3:
// Capacity's difficulty lever is its demand/capacity distribution,
// "not just node count", so it reuses this same table rather than
// getting its own).
// ---------------------------------------------------------------------

const Map<DifficultyTier, IntRange> classicCapacityNodeCount = {
  DifficultyTier.small: IntRange(8, 12),
  DifficultyTier.medium: IntRange(13, 18),
  DifficultyTier.large: IntRange(19, 25),
};

/// Target optimum (= star-cluster count) by tier. INVARIANT, checked
/// in test/generation/difficulty_tiers_test.dart: every tier's
/// `nodeCount.min >= 2 * clusterCount.max`, since each cluster needs a
/// hub + >=1 leaf. Violating this doesn't crash generation (the
/// generator clamps down to whatever's feasible for the rolled node
/// count) but it does mean the clamp is silently overriding this
/// table, which defeats the point of tuning it here.
const Map<DifficultyTier, IntRange> classicCapacityClusterCount = {
  DifficultyTier.small: IntRange(2, 4),
  DifficultyTier.medium: IntRange(4, 6),
  DifficultyTier.large: IntRange(5, 9),
};

/// Fraction of node count added back as cross-cluster leaf<->leaf
/// decoration edges, for visual density and difficulty texture.
/// Restricted to leaf<->leaf and never touching a hub — see
/// classic_capacity_generator.dart — which makes this safe by
/// construction for Classic at values well beyond this one (stress-
/// tested to 1.5 during the Phase 2 prototype); 0.5 is a "reasonably
/// busy-looking graph" choice, not a safety ceiling.
const double classicCapacityDecorationFraction = 0.5;

// ---------------------------------------------------------------------
// Capacity-only: demand/capacity distribution (Phase 2 item 3's actual
// difficulty lever for this mode)
// ---------------------------------------------------------------------

/// Per-tier capacity/demand distribution knobs, layered on top of the
/// shared node/cluster ranges above.
class CapacityTierConfig {
  const CapacityTierConfig({
    required this.hungryFraction,
    required this.leafDemandRange,
    required this.hungryDemandMultiplier,
  });

  /// Fraction of leaves that get an extra demand multiplier applied —
  /// Phase 2's "hungry" high-demand/low-capacity nodes, "a difficulty
  /// lever, not just node count."
  final double hungryFraction;

  final DoubleRange leafDemandRange;
  final DoubleRange hungryDemandMultiplier;
}

/// Every leaf's capacity is drawn from this fixed range regardless of
/// tier — only demand pressure scales with tier via
/// [capacityTierConfig], so higher tiers read as "more nodes are
/// hungry" rather than just "the numbers got bigger."
const DoubleRange capacityLeafBaseCapacity = DoubleRange(1.0, 2.0);

/// Multiplier applied to `2 * (max leaf demand in the cluster)` when
/// setting a hub's own capacity, so a hub tapped alone can always
/// fully satisfy itself and spill `0.5*cap(hub)` to every leaf. `1.0`
/// is the exact theoretical minimum (verified during the Phase 2
/// prototype: values at or below 1.0 measurably increase
/// construct-then-verify retries); this margin exists so
/// floating-point rounding never flips a level from feasible to
/// infeasible by a hair — see capacity_solver.dart's `_epsilon`.
const double capacityHubCapacityMargin = 1.15;

const Map<DifficultyTier, CapacityTierConfig> capacityTierConfig = {
  DifficultyTier.small: CapacityTierConfig(
    hungryFraction: 0.2,
    leafDemandRange: DoubleRange(1.0, 2.5),
    hungryDemandMultiplier: DoubleRange(1.8, 2.2),
  ),
  DifficultyTier.medium: CapacityTierConfig(
    hungryFraction: 0.35,
    leafDemandRange: DoubleRange(1.0, 3.0),
    hungryDemandMultiplier: DoubleRange(1.8, 2.4),
  ),
  DifficultyTier.large: CapacityTierConfig(
    hungryFraction: 0.45,
    leafDemandRange: DoubleRange(1.5, 3.5),
    hungryDemandMultiplier: DoubleRange(2.0, 2.6),
  ),
};

// ---------------------------------------------------------------------
// Signal — its own node-count table (Phase 2: polynomial solve time
// means it "can scale node count more aggressively (30-40+)")
// ---------------------------------------------------------------------

const Map<DifficultyTier, IntRange> signalNodeCount = {
  DifficultyTier.small: IntRange(8, 14),
  DifficultyTier.medium: IntRange(15, 24),
  DifficultyTier.large: IntRange(25, 40),
};

/// Target driver count (= chain count) by tier. INVARIANT, checked in
/// test/generation/difficulty_tiers_test.dart: every tier's
/// `nodeCount.min >= chainCount.max`, since a chain needs >=1 node.
const Map<DifficultyTier, IntRange> signalChainCount = {
  DifficultyTier.small: IntRange(2, 4),
  DifficultyTier.medium: IntRange(3, 6),
  DifficultyTier.large: IntRange(4, 8),
};

/// Fraction of node count added back as decoration edges between
/// chains (never targeting a chain head — see signal_generator.dart —
/// so regular decoration can't itself change the driver count; only
/// the deliberate chain-merge path used for teaching-pair levels
/// does). Lower than Classic/Capacity's 0.5 by design: directed edges
/// already read as "busier" per edge than undirected ones, and Signal
/// levels are already the largest node counts in the game.
const double signalDecorationFraction = 0.3;
