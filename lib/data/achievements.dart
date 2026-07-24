// Achievement catalog + pure evaluation helpers — Phase 6 item 3.
//
// Same split as slot_progress.dart/progress_store.dart: this file is
// zero-Flutter (a catalog + a couple of pure functions), so it's
// testable under plain `dart test`. The actual unlocked-id persistence
// lives in progress_store.dart (which already wraps SharedPreferences
// for coins/slot progress) rather than a second competing storage
// module — Master Context: "A single local persistence module... is
// the durable source of truth," and that principle doesn't stop
// applying just because this phase adds a new kind of thing to store.
//
// Mode-specific unlock CONDITIONS (density-aha's id check, Capacity's
// surplus-ratio math) deliberately do NOT live here — they live beside
// the mode they belong to (signal_gameplay_screen.dart,
// capacity_supply.dart), the same way each mode already owns its own
// hint engine instead of a shared one. This file owns only what's
// genuinely cross-mode: the catalog itself, and "is every slot in this
// track 3-starred," which is identical logic for all three tracks.

import 'slot_progress.dart';

enum AchievementId {
  classicMastery,
  capacityMastery,
  signalMastery,
  signalDensityAha,
  capacityEfficient,
}

class Achievement {
  const Achievement({
    required this.id,
    required this.title,
    required this.description,
  });

  final AchievementId id;
  final String title;
  final String description;
}

/// Every achievement in the game, in display order. A `const` map
/// keyed by [AchievementId] rather than a list, so
/// `achievementCatalog[id]!` reads naturally at every call site that
/// already has an id (e.g. from [ProgressStore.unlockedAchievementIds]).
const Map<AchievementId, Achievement> achievementCatalog = {
  AchievementId.classicMastery: Achievement(
    id: AchievementId.classicMastery,
    title: 'FULLY DOMINATED',
    description: '3-star every level in the Classic track.',
  ),
  AchievementId.capacityMastery: Achievement(
    id: AchievementId.capacityMastery,
    title: 'AT CAPACITY',
    description: '3-star every level in the Capacity track.',
  ),
  AchievementId.signalMastery: Achievement(
    id: AchievementId.signalMastery,
    title: 'FULL CONTROL',
    description: '3-star every level in the Signal track.',
  ),
  AchievementId.signalDensityAha: Achievement(
    id: AchievementId.signalDensityAha,
    title: 'MORE PIPES, FEWER DRIVERS',
    description:
        'Solve a Signal level where a denser layout needed fewer driver '
        'nodes than a sparser one would have.',
  ),
  AchievementId.capacityEfficient: Achievement(
    id: AchievementId.capacityEfficient,
    title: 'NO SPILLAGE',
    description:
        '3-star a Capacity level with almost no wasted over-supply.',
  ),
};

/// True iff every slot id in [slotIdsInTrack] has a recorded best
/// outcome of [SlotOutcome.threeStar] in [outcomesBySlotId]. A slot
/// missing from the map (never attempted) counts as NOT mastered —
/// [SlotOutcome.none] would too, this just also covers "not present at
/// all" the same way, so callers don't need to pre-fill every slot id
/// with [SlotOutcome.none] before calling this.
///
/// Empty [slotIdsInTrack] returns false rather than the vacuously-true
/// "every element of the empty set satisfies X" — an empty track isn't
/// something to award mastery for, it's a loading/error state.
bool isTrackMastered(
  List<String> slotIdsInTrack,
  Map<String, SlotOutcome> outcomesBySlotId,
) {
  if (slotIdsInTrack.isEmpty) return false;
  return slotIdsInTrack.every(
    (id) => outcomesBySlotId[id] == SlotOutcome.threeStar,
  );
}
