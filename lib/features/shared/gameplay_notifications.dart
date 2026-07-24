// Small helpers shared by all three gameplay screens' outcome
// handling — Phase 6 items 3 and 4. Factored out once rather than
// hand-copied three times, the same call level_select_screen.dart
// already made for Phase 4/5: what's identical across modes lives
// here, what's mode-specific (Signal's density-aha check, Capacity's
// surplus-ratio check) stays in that mode's own gameplay screen.
//
// DELIBERATE DESIGN NOTE: [unlockIfNew] and [checkTrackMastery] return
// data (an [Achievement], or null) rather than showing a SnackBar
// themselves. A SnackBar fired from a mode's threeStar/twoStar branch
// would race against that same branch's outcome dialog — every
// gameplay screen's "CONTINUE"/"PAY TO UNLOCK" button pops the
// DIALOG and then IMMEDIATELY pops the GAMEPLAY SCREEN ITSELF in the
// same handler (see e.g. classic_gameplay_screen.dart's
// `_DialogAction('CONTINUE', () => Navigator.of(context).pop())`).
// A SnackBar shown after that dialog closes is shown against a
// context that's already mid-unmount most of the time, and silently
// does nothing. Folding the achievement text into the SAME outcome
// dialog's body — which each gameplay screen does with the
// [Achievement]? this returns — sidesteps that race entirely instead
// of fighting it with `mounted` checks and hoping for the best.

import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../data/achievements.dart';
import '../../data/level_schema.dart';
import '../../data/progress_providers.dart';
import '../../data/progress_store.dart';
import '../../data/slot_progress.dart';
import '../../engine/engine.dart';

/// Unlocks [id] via [progressStore] and returns the [Achievement] iff
/// THIS call is what newly unlocked it — null if it was already
/// unlocked. Callers only invoke this once they've already confirmed
/// the achievement's condition actually holds; this method has no
/// opinion about what that condition is, same as
/// [ProgressStore.unlockAchievement] itself doesn't.
Future<Achievement?> unlockIfNew(
  ProgressStore progressStore,
  AchievementId id,
) async {
  final isNew = await progressStore.unlockAchievement(id);
  return isNew ? achievementCatalog[id] : null;
}

/// Checks whether every slot in [trackLevels] is now 3-starred and, if
/// so, unlocks [achievementId] — returning the [Achievement] iff this
/// specific call newly unlocked it. Call this from a mode's threeStar
/// outcome branch AFTER `progressStore.recordOutcome` for the slot
/// just cleared, so that slot's new outcome is already reflected in
/// [ProgressStore.slotProgress] by the time this reads it, not the
/// stale pre-clear value.
Future<Achievement?> checkTrackMastery(
  ProgressStore progressStore,
  List<Level> trackLevels,
  AchievementId achievementId,
) async {
  final outcomes = <String, SlotOutcome>{
    for (final level in trackLevels)
      level.id: progressStore.slotProgress(level.id).bestOutcome,
  };
  final slotIds = [for (final level in trackLevels) level.id];
  if (!isTrackMastered(slotIds, outcomes)) return null;
  return unlockIfNew(progressStore, achievementId);
}

/// Renders an [Achievement]? as the extra paragraph appended to an
/// outcome dialog's body — empty string if null, so callers can
/// always do `'...base body...$achievementSuffix(unlocked)'` without
/// an extra branch at the call site.
String achievementSuffix(Achievement? unlocked) {
  if (unlocked == null) return '';
  return '\n\n\u{1F3C6} ACHIEVEMENT: ${unlocked.title}';
}

/// Whether [mode]'s first-level tutorial overlay should be shown right
/// now — true only the very first time this is called for that mode
/// (subsequent calls after [ProgressStore.markOnboardingSeen] always
/// return false). Gameplay screens call this once from `initState`,
/// via a post-frame callback so the async read doesn't race the
/// widget's first build.
Future<bool> shouldShowOnboarding(WidgetRef ref, GameMode mode) async {
  final progressStore = await ref.read(progressStoreProvider.future);
  return !progressStore.hasSeenOnboarding(mode);
}
