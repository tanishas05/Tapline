import 'package:tapline/features/shared/outcome_logic.dart';
import 'package:test/test.dart';

void main() {
  group('evaluateOutcome — the four defined rows', () {
    test('satisfied at exactly optimum -> 3 stars', () {
      final result = evaluateOutcome(
        isFullySatisfied: true,
        tapsUsed: 3,
        optimum: 3,
        elapsedSeconds: 10,
        timeLimitSeconds: 60,
      );
      expect(result, GameplayOutcome.threeStar);
    });

    test('satisfied at exactly optimum+1 (maxTaps) -> 2 stars', () {
      final result = evaluateOutcome(
        isFullySatisfied: true,
        tapsUsed: 4,
        optimum: 3,
        elapsedSeconds: 10,
        timeLimitSeconds: 60,
      );
      expect(result, GameplayOutcome.twoStar);
    });

    test('not satisfied, tapsUsed exceeds maxTaps -> fail (taps)', () {
      final result = evaluateOutcome(
        isFullySatisfied: false,
        tapsUsed: 5,
        optimum: 3,
        elapsedSeconds: 10,
        timeLimitSeconds: 60,
      );
      expect(result, GameplayOutcome.failTaps);
    });

    test('not satisfied, time elapsed reaches the limit -> fail (time)', () {
      final result = evaluateOutcome(
        isFullySatisfied: false,
        tapsUsed: 2,
        optimum: 3,
        elapsedSeconds: 60,
        timeLimitSeconds: 60,
      );
      expect(result, GameplayOutcome.failTime);
    });

    test('not satisfied, under both limits -> still playing', () {
      final result = evaluateOutcome(
        isFullySatisfied: false,
        tapsUsed: 2,
        optimum: 3,
        elapsedSeconds: 10,
        timeLimitSeconds: 60,
      );
      expect(result, GameplayOutcome.playing);
    });
  });

  group('evaluateOutcome — boundaries', () {
    test('tapsUsed exactly at maxTaps but not satisfied is NOT a fail — '
        'the player can still swap a wrong tap for a different one', () {
      final result = evaluateOutcome(
        isFullySatisfied: false,
        tapsUsed: 4, // == maxTaps (optimum 3 + 1)
        optimum: 3,
        elapsedSeconds: 10,
        timeLimitSeconds: 60,
      );
      expect(result, GameplayOutcome.playing);
    });

    test('elapsedSeconds just under the limit is NOT a fail yet', () {
      final result = evaluateOutcome(
        isFullySatisfied: false,
        tapsUsed: 1,
        optimum: 3,
        elapsedSeconds: 59.9,
        timeLimitSeconds: 60,
      );
      expect(result, GameplayOutcome.playing);
    });
  });

  group('evaluateOutcome — the gap case this function resolves', () {
    test(
      'satisfied but tapsUsed > maxTaps resolves to FAIL, not an '
      'unscored win — see this function\'s doc comment for why the '
      'Master Context\'s table leaves this case undefined and how '
      'that\'s resolved here',
      () {
        final result = evaluateOutcome(
          isFullySatisfied: true,
          tapsUsed: 5, // maxTaps is 4 (optimum 3 + 1)
          optimum: 3,
          elapsedSeconds: 10,
          timeLimitSeconds: 60,
        );
        expect(result, GameplayOutcome.failTaps);
      },
    );

    test('fail-taps is checked before fail-time when both would '
        'independently apply', () {
      final result = evaluateOutcome(
        isFullySatisfied: false,
        tapsUsed: 10, // way past maxTaps
        optimum: 3,
        elapsedSeconds: 999, // way past the time limit too
        timeLimitSeconds: 60,
      );
      expect(result, GameplayOutcome.failTaps);
    });
  });

  group('evaluateOutcome — degenerate optimum=0', () {
    test('a trivially-satisfied level (optimum 0) with zero taps is '
        '3 stars, not stuck at "playing"', () {
      final result = evaluateOutcome(
        isFullySatisfied: true,
        tapsUsed: 0,
        optimum: 0,
        elapsedSeconds: 0,
        timeLimitSeconds: 30,
      );
      expect(result, GameplayOutcome.threeStar);
    });
  });

  group('maxTapsFor', () {
    test('is always optimum + 1', () {
      expect(maxTapsFor(0), 1);
      expect(maxTapsFor(3), 4);
      expect(maxTapsFor(17), 18);
    });
  });
}
