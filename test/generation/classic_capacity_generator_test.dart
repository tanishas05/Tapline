import 'dart:math';

import 'package:tapline/data/level_schema.dart';
import 'package:tapline/engine/engine.dart';
import 'package:tapline/generation/generation.dart';
import 'package:test/test.dart';

/// Trials per (mode, tier) combination. The construction was already
/// swept 60x per tier in the Python prototype this was translated
/// from (all first-attempt matches); this Dart-side count is smaller
/// on purpose — it exists to confirm the translation didn't introduce
/// a bug, not to re-run the same statistical sweep.
const _trialsPerCombo = 8;

void main() {
  group('ClassicCapacityGenerator', () {
    for (final mode in [GameMode.classic, GameMode.capacity]) {
      for (final tier in DifficultyTier.values) {
        test(
            '${mode.name}/${tier.name}: every generated level '
            're-verifies to its own stated optimum', () {
          final nodeRange = classicCapacityNodeCount[tier]!;

          for (var trial = 0; trial < _trialsPerCombo; trial++) {
            final level = ClassicCapacityGenerator.generate(
              mode: mode,
              tier: tier,
              id: 'test_${mode.name}_${tier.name}_$trial',
              random: Random(1000 + trial),
            );

            expect(level.mode, mode);
            expect(level.difficultyTier, tier);
            expect(level.directed, isFalse);
            expect(level.timeLimitSeconds, timeLimitSecondsByTier[tier]);
            expect(
              level.nodes.length,
              inInclusiveRange(nodeRange.min, nodeRange.max),
            );
            expect(level.exampleSolution.length, level.optimum);

            // independent re-solve of the exact graph this level
            // carries must land on the exact same optimum.
            final graph = level.toGraph();
            final resolved = checkSolvability(graph, mode);
            expect(resolved, isA<Solved>());
            expect((resolved as Solved).optimalTapCount, level.optimum);

            // the stored exampleSolution must itself be a valid,
            // fully-winning witness — not just the right size.
            expect(
              verifyWin(graph, mode, level.exampleSolution),
              isTrue,
              reason:
                  'stored exampleSolution does not actually win: level '
                  '${level.id}',
            );
          }
        });
      }
    }

    test('rejects GameMode.signal', () {
      expect(
        () => ClassicCapacityGenerator.generate(
          mode: GameMode.signal,
          tier: DifficultyTier.small,
          id: 'bad',
        ),
        throwsArgumentError,
      );
    });

    test('decoration edges never touch a hub (Classic proof invariant)',
        () {
      // Every generated edge should have at least one endpoint whose
      // id contains "_leaf", UNLESS it's a hub-to-own-leaf edge (id
      // contains "_hub" AND the other end is a leaf of the SAME
      // cluster prefix). What must never appear is hub<->hub or
      // hub<->leaf-of-a-DIFFERENT-cluster.
      for (var trial = 0; trial < 5; trial++) {
        final level = ClassicCapacityGenerator.generate(
          mode: GameMode.classic,
          tier: DifficultyTier.large,
          id: 'hub_check_$trial',
          random: Random(2000 + trial),
        );
        for (final edge in level.edges) {
          final fromIsHub = edge.from.endsWith('_hub');
          final toIsHub = edge.to.endsWith('_hub');
          if (fromIsHub || toIsHub) {
            // one endpoint is a hub: the other MUST be a leaf from
            // that same cluster (own-cluster star edge), never a
            // cross-cluster decoration edge and never hub<->hub.
            final hubSide = fromIsHub ? edge.from : edge.to;
            final otherSide = fromIsHub ? edge.to : edge.from;
            final hubCluster = hubSide.split('_').first;
            final otherCluster = otherSide.split('_').first;
            expect(
              otherIsOwnLeaf(otherSide, hubCluster, otherCluster),
              isTrue,
              reason: 'edge $edge touches a hub in a way that is not a '
                  "same-cluster star edge — breaks this file's safety "
                  'proof',
            );
          }
        }
      }
    });

    test('JSON round-trip preserves solvability', () {
      final level = ClassicCapacityGenerator.generate(
        mode: GameMode.capacity,
        tier: DifficultyTier.medium,
        id: 'roundtrip_test',
        random: Random(42),
      );
      final decoded = Level.fromJson(level.toJson());

      expect(decoded.optimum, level.optimum);
      expect(decoded.exampleSolution, level.exampleSolution);
      expect(decoded.nodes.length, level.nodes.length);
      expect(decoded.edges.length, level.edges.length);
      expect(decoded.timeLimitSeconds, level.timeLimitSeconds);
      expect(decoded.mode, level.mode);
      expect(decoded.difficultyTier, level.difficultyTier);

      final resolved = checkSolvability(decoded.toGraph(), decoded.mode);
      expect(resolved, isA<Solved>());
      expect((resolved as Solved).optimalTapCount, level.optimum);
    });
  });
}

bool otherIsOwnLeaf(String otherSide, String hubCluster, String otherCluster) {
  return otherSide.contains('_leaf') && otherCluster == hubCluster;
}
