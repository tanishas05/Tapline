import 'package:tapline/data/slot_progress.dart';
import 'package:test/test.dart';

void main() {
  group('SlotProgress.unlocksNext', () {
    test('threeStar unlocks the next slot', () {
      const progress = SlotProgress(bestOutcome: SlotOutcome.threeStar);
      expect(progress.unlocksNext, isTrue);
    });

    test('twoStar alone does NOT unlock the next slot', () {
      const progress = SlotProgress(bestOutcome: SlotOutcome.twoStar);
      expect(progress.unlocksNext, isFalse);
    });

    test('twoStar + paidPast DOES unlock the next slot', () {
      const progress = SlotProgress(
        bestOutcome: SlotOutcome.twoStar,
        paidPast: true,
      );
      expect(progress.unlocksNext, isTrue);
    });

    test('none does not unlock the next slot', () {
      const progress = SlotProgress();
      expect(progress.unlocksNext, isFalse);
    });
  });

  group('slotOutcomeRank', () {
    test('orders none < twoStar < threeStar', () {
      expect(slotOutcomeRank(SlotOutcome.none),
          lessThan(slotOutcomeRank(SlotOutcome.twoStar)));
      expect(slotOutcomeRank(SlotOutcome.twoStar),
          lessThan(slotOutcomeRank(SlotOutcome.threeStar)));
    });
  });

  group('computeUnlockedSlots', () {
    test('empty track', () {
      expect(computeUnlockedSlots([]), isEmpty);
    });

    test('slot 0 is always unlocked, regardless of its own progress',
        () {
      final unlocked = computeUnlockedSlots([const SlotProgress()]);
      expect(unlocked, [true]);
    });

    test('a 3-starred slot unlocks the next one', () {
      final unlocked = computeUnlockedSlots([
        const SlotProgress(bestOutcome: SlotOutcome.threeStar),
        const SlotProgress(),
      ]);
      expect(unlocked, [true, true]);
    });

    test('a 2-starred (unpaid) slot does NOT unlock the next one', () {
      final unlocked = computeUnlockedSlots([
        const SlotProgress(bestOutcome: SlotOutcome.twoStar),
        const SlotProgress(),
      ]);
      expect(unlocked, [true, false]);
    });

    test('a paid-past 2-star DOES unlock the next one', () {
      final unlocked = computeUnlockedSlots([
        const SlotProgress(bestOutcome: SlotOutcome.twoStar, paidPast: true),
        const SlotProgress(),
      ]);
      expect(unlocked, [true, true]);
    });

    test(
      'unlocking slot 1 does not cascade to slot 2 on its own — slot '
      '1 still has to be cleared itself',
      () {
        final unlocked = computeUnlockedSlots([
          const SlotProgress(bestOutcome: SlotOutcome.threeStar), // slot 0
          const SlotProgress(), // slot 1: unlocked, but not cleared yet
          const SlotProgress(), // slot 2
        ]);
        expect(unlocked, [true, true, false]);
      },
    );

    test('a full chain of 3-stars unlocks the whole track in sequence',
        () {
      final unlocked = computeUnlockedSlots([
        const SlotProgress(bestOutcome: SlotOutcome.threeStar),
        const SlotProgress(bestOutcome: SlotOutcome.threeStar),
        const SlotProgress(bestOutcome: SlotOutcome.threeStar),
        const SlotProgress(), // last one: unlocked, not yet cleared
      ]);
      expect(unlocked, [true, true, true, true]);
    });

    test('a gap anywhere in the chain locks everything after it', () {
      final unlocked = computeUnlockedSlots([
        const SlotProgress(bestOutcome: SlotOutcome.threeStar),
        const SlotProgress(), // never cleared — the gap
        const SlotProgress(bestOutcome: SlotOutcome.threeStar), // unreachable
      ]);
      expect(unlocked, [true, true, false]);
    });
  });
}
