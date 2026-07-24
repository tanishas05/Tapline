// Pure data model for per-slot progress — split out from
// progress_store.dart specifically so this part is testable under
// plain `dart test`, not just `flutter test`. progress_store.dart
// needs shared_preferences (a Flutter plugin package) to actually
// persist anything, which pulls Flutter into that file's dependency
// graph; this file avoids that entirely, same reasoning as
// level_manifest.dart's split from level_loader.dart in Phase 2.

/// The best outcome ever recorded for a slot. Deliberately has no
/// "fail" member — Master Context: a fail never updates recorded
/// progress at all, so there's nothing between [none] and [twoStar]
/// worth representing here.
enum SlotOutcome { none, twoStar, threeStar }

/// Ordering for "best outcome ever seen" comparisons — a later
/// 2-star attempt must never downgrade a prior 3-star.
int slotOutcomeRank(SlotOutcome outcome) => switch (outcome) {
      SlotOutcome.none => 0,
      SlotOutcome.twoStar => 1,
      SlotOutcome.threeStar => 2,
    };

/// Recorded progress for one level-select slot.
class SlotProgress {
  const SlotProgress({
    this.bestOutcome = SlotOutcome.none,
    this.paidPast = false,
  });

  final SlotOutcome bestOutcome;

  /// True once the player has spent coins to unlock past a 2-star
  /// clear on this slot — Master Context: 2-star "does NOT
  /// auto-unlock the next level. Player is offered a choice: pay
  /// coins to unlock anyway, or replay."
  final bool paidPast;

  /// Whether clearing this slot unlocks the next one in sequence —
  /// true on an actual 3-star, OR on a 2-star the player paid past.
  bool get unlocksNext =>
      bestOutcome == SlotOutcome.threeStar || paidPast;

  @override
  String toString() =>
      'SlotProgress(${bestOutcome.name}${paidPast ? ', paidPast' : ''})';
}

/// Pure function: given the progress for every slot in a track, IN
/// TRACK ORDER, returns which are unlocked. Slot 0 is always
/// unlocked (the start of the track); slot i (i>0) is unlocked iff
/// slot i-1's [SlotProgress.unlocksNext] is true.
List<bool> computeUnlockedSlots(List<SlotProgress> slotsInOrder) {
  return [
    for (var i = 0; i < slotsInOrder.length; i++)
      i == 0 || slotsInOrder[i - 1].unlocksNext,
  ];
}
