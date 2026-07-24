// Placeholder coin economy — Phase 6 owns the real tunable tables
// (Master Context: "Coin payout on a 3-star scales with the level's
// difficultyTier via a tunable lookup table... never a fixed constant
// ... The coin cost to unlock past a 2-star is a SEPARATE tunable
// number, not derived from the 3-star payout amount"). Phase 3 needs
// something real to call so the controller's outcome handling
// actually does something, not a stub — these numbers are exactly as
// provisional as difficulty_tiers.dart's timeLimitSecondsByTier was
// in Phase 2: clearly placeholder, not a balanced result of
// playtesting. TODO(playtesting, Phase 6): tune for real.

import '../../data/level_schema.dart';

const Map<DifficultyTier, int> coinPayoutByTier = {
  DifficultyTier.small: 10,
  DifficultyTier.medium: 20,
  DifficultyTier.large: 35,
};

/// Separate tunable from [coinPayoutByTier], per Master Context — not
/// derived from it.
const Map<DifficultyTier, int> unlockPastTwoStarCostByTier = {
  DifficultyTier.small: 15,
  DifficultyTier.medium: 25,
  DifficultyTier.large: 40,
};

/// Flat (not tier-scaled) costs for the two paid replay options offered
/// on a 2-star clear or a failed attempt (out of taps / out of time —
/// see each gameplay screen's outcome dialog). Same-layout costs MORE
/// than new-layout on purpose: replaying the exact layout you were
/// just one tap over on (or already know the shape of) is a
/// near-guaranteed 3-star, so it's priced as the "safe bet" option;
/// a new layout is priced lower since it's a fresh, unsolved puzzle
/// with no such guarantee. TODO(playtesting, Phase 6): also a
/// placeholder, same caveat as the tables above.
const int replayNewLayoutCost = 10;
const int replaySameLayoutCost = 20;

/// TODO(playtesting, Phase 6): also a placeholder. Gates how many
/// hints a player can use on one attempt before a hint costs coins —
/// Master Context doesn't specify a number, only that there IS a
/// limited free allotment plus a paid top-up.
const int freeHintsPerAttempt = 2;

/// Cost in coins for one hint once the free allotment is used up.
const int hintCoinCost = 5;
