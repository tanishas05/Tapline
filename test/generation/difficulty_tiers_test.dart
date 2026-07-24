import 'dart:math';

import 'package:tapline/data/level_schema.dart';
import 'package:tapline/generation/generation.dart';
import 'package:test/test.dart';

void main() {
  group('timeLimitSecondsByTier', () {
    test('has a positive entry for every tier, increasing with tier', () {
      for (final tier in DifficultyTier.values) {
        expect(timeLimitSecondsByTier.containsKey(tier), isTrue);
        expect(timeLimitSecondsByTier[tier], greaterThan(0));
      }
      expect(
        timeLimitSecondsByTier[DifficultyTier.small]!,
        lessThan(timeLimitSecondsByTier[DifficultyTier.medium]!),
      );
      expect(
        timeLimitSecondsByTier[DifficultyTier.medium]!,
        lessThan(timeLimitSecondsByTier[DifficultyTier.large]!),
      );
    });
  });

  group('Classic/Capacity tier tables', () {
    test(
        'every tier satisfies nodeCount.min >= 2*clusterCount.max '
        '(each cluster needs a hub + >=1 leaf)', () {
      for (final tier in DifficultyTier.values) {
        final nodeRange = classicCapacityNodeCount[tier]!;
        final clusterRange = classicCapacityClusterCount[tier]!;
        expect(
          nodeRange.min >= 2 * clusterRange.max,
          isTrue,
          reason: '$tier: nodeCount.min=${nodeRange.min} must be >= '
              '2*clusterCount.max=${2 * clusterRange.max}, or '
              'ClassicCapacityGenerator silently clamps below what '
              "this table intends — see that file's feasibleMax logic",
        );
      }
    });

    test('capacityTierConfig covers every tier with sane fractions', () {
      for (final tier in DifficultyTier.values) {
        final config = capacityTierConfig[tier];
        expect(config, isNotNull, reason: 'missing tier: $tier');
        expect(config!.hungryFraction, inInclusiveRange(0, 1));
      }
    });
  });

  group('Signal tier tables', () {
    test(
        'every tier satisfies nodeCount.min >= chainCount.max '
        '(a chain needs >=1 node)', () {
      for (final tier in DifficultyTier.values) {
        final nodeRange = signalNodeCount[tier]!;
        final chainRange = signalChainCount[tier]!;
        expect(
          nodeRange.min >= chainRange.max,
          isTrue,
          reason: '$tier: nodeCount.min=${nodeRange.min} must be >= '
              'chainCount.max=${chainRange.max}',
        );
      }
    });

    test('node counts scale up more aggressively than Classic/Capacity',
        () {
      // Phase 2: Signal "can scale node count more aggressively
      // (30-40+)" since it's polynomial-time.
      expect(
        signalNodeCount[DifficultyTier.large]!.max,
        greaterThanOrEqualTo(30),
      );
      expect(
        signalNodeCount[DifficultyTier.large]!.max,
        greaterThan(classicCapacityNodeCount[DifficultyTier.large]!.max),
      );
    });
  });

  group('IntRange / DoubleRange', () {
    test('roll() always stays within [min, max]', () {
      final random = Random(1);
      const intRange = IntRange(3, 7);
      for (var i = 0; i < 200; i++) {
        final v = intRange.roll(random);
        expect(v, inInclusiveRange(3, 7));
      }
      const doubleRange = DoubleRange(2.0, 5.0);
      for (var i = 0; i < 200; i++) {
        final v = doubleRange.roll(random);
        expect(v, greaterThanOrEqualTo(2.0));
        expect(v, lessThanOrEqualTo(5.0));
      }
    });

    test('degenerate range (min == max) always returns that value', () {
      final random = Random(2);
      const range = IntRange(4, 4);
      for (var i = 0; i < 20; i++) {
        expect(range.roll(random), 4);
      }
    });
  });
}
