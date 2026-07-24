import 'package:tapline/data/achievements.dart';
import 'package:tapline/data/slot_progress.dart';
import 'package:test/test.dart';

void main() {
  group('isTrackMastered', () {
    test('every slot 3-starred is mastered', () {
      final result = isTrackMastered(
        ['a', 'b', 'c'],
        {
          'a': SlotOutcome.threeStar,
          'b': SlotOutcome.threeStar,
          'c': SlotOutcome.threeStar,
        },
      );
      expect(result, isTrue);
    });

    test('one slot at 2-star instead of 3 is NOT mastered', () {
      final result = isTrackMastered(
        ['a', 'b', 'c'],
        {
          'a': SlotOutcome.threeStar,
          'b': SlotOutcome.twoStar,
          'c': SlotOutcome.threeStar,
        },
      );
      expect(result, isFalse);
    });

    test('a slot missing from the outcomes map (never attempted) is '
        'treated the same as SlotOutcome.none — not mastered, and '
        'callers do not need to pre-fill every id first', () {
      final result = isTrackMastered(
        ['a', 'b'],
        {'a': SlotOutcome.threeStar}, // 'b' absent entirely
      );
      expect(result, isFalse);
    });

    test('an empty track is never "mastered" — not a vacuous true', () {
      final result = isTrackMastered([], {});
      expect(result, isFalse);
    });

    test('extra unrelated entries in the outcomes map are ignored', () {
      final result = isTrackMastered(
        ['a'],
        {
          'a': SlotOutcome.threeStar,
          'unrelated_other_track_slot': SlotOutcome.none,
        },
      );
      expect(result, isTrue);
    });
  });

  group('achievementCatalog', () {
    test('every AchievementId has a catalog entry with a matching id',
        () {
      for (final id in AchievementId.values) {
        final entry = achievementCatalog[id];
        expect(entry, isNotNull, reason: '$id is missing from the catalog');
        expect(entry!.id, id);
      }
    });

    test('no two achievements share a title (would be confusing in the '
        'achievements screen)', () {
      final titles = achievementCatalog.values.map((a) => a.title).toSet();
      expect(titles.length, achievementCatalog.length);
    });
  });
}
