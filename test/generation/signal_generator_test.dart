import 'dart:math';

import 'package:tapline/data/level_schema.dart';
import 'package:tapline/engine/engine.dart';
import 'package:tapline/generation/generation.dart';
import 'package:test/test.dart';

/// See classic_capacity_generator_test.dart's doc comment on
/// `_trialsPerCombo` — same reasoning (this was swept 60x per tier in
/// the Python prototype already; this just confirms the translation).
const _trialsPerTier = 8;

void main() {
  group('SignalGenerator.generate', () {
    for (final tier in DifficultyTier.values) {
      test(
          '${tier.name}: every generated level re-verifies to its own '
          'stated driver count', () {
        final nodeRange = signalNodeCount[tier]!;

        for (var trial = 0; trial < _trialsPerTier; trial++) {
          final level = SignalGenerator.generate(
            tier: tier,
            id: 'test_signal_${tier.name}_$trial',
            random: Random(3000 + trial),
          );

          expect(level.mode, GameMode.signal);
          expect(level.difficultyTier, tier);
          expect(level.directed, isTrue);
          expect(level.timeLimitSeconds, timeLimitSecondsByTier[tier]);
          expect(
            level.nodes.length,
            inInclusiveRange(nodeRange.min, nodeRange.max),
          );
          expect(level.exampleSolution.length, level.optimum);

          final graph = level.toGraph();
          final resolved = checkSolvability(graph, GameMode.signal);
          expect(resolved, isA<Solved>());
          expect((resolved as Solved).optimalTapCount, level.optimum);

          expect(
            verifyWin(graph, GameMode.signal, level.exampleSolution),
            isTrue,
            reason: 'stored driver set does not actually reach every '
                'node: level ${level.id}',
          );

          // Regular decoration never targets a chain head (id ends in
          // "_0") and neither do a chain's own internal edges (they
          // only ever point forward from index j to j+1, so index 0
          // is never a target either way) — so for a *regular*
          // generated level, no edge should target a "_0" node at
          // all. This is what makes the driver count provably stable
          // under regular decoration (see signal_generator.dart's top
          // doc comment) — checked here, not just asserted in prose.
          expect(
            level.edges.any((e) => e.to.endsWith('_0')),
            isFalse,
            reason: 'a regular (non-merged) level has an edge into a '
                'chain head — decoration safety invariant broken: '
                'level ${level.id}',
          );
        }
      });
    }
  });

  group('SignalGenerator.generateTeachingPair', () {
    for (final tier in DifficultyTier.values) {
      test('${tier.name}: dense variant verifies to strictly fewer '
          'drivers than the sparse baseline, same node count', () {
        for (var trial = 0; trial < 5; trial++) {
          final pair = SignalGenerator.generateTeachingPair(
            tier: tier,
            sparseId: 'teach_sparse_${tier.name}_$trial',
            denseId: 'teach_dense_${tier.name}_$trial',
            random: Random(4000 + trial),
          );

          expect(pair.dense.optimum, lessThan(pair.sparse.optimum));
          expect(pair.dense.nodes.length, pair.sparse.nodes.length);

          // sparse baseline: same "no edge into a chain head"
          // invariant as the regular generator (it's built from the
          // same chain construction, just without regular decoration
          // on top).
          expect(
            pair.sparse.edges.any((e) => e.to.endsWith('_0')),
            isFalse,
          );
          // dense variant: the whole point is that it DOES have at
          // least one edge into a chain head — that's the merge link
          // that dropped the driver count, and it should be visible,
          // not incidental.
          expect(
            pair.dense.edges.any((e) => e.to.endsWith('_0')),
            isTrue,
            reason: 'dense variant has no merge edge into a chain '
                'head — the driver-count drop should be traceable to '
                'a visible edge, not a coincidence',
          );

          // both independently re-verify
          for (final level in [pair.sparse, pair.dense]) {
            final graph = level.toGraph();
            final resolved = checkSolvability(graph, GameMode.signal);
            expect(resolved, isA<Solved>());
            expect((resolved as Solved).optimalTapCount, level.optimum);
            expect(
              verifyWin(graph, GameMode.signal, level.exampleSolution),
              isTrue,
            );
          }
        }
      });
    }
  });

  test('JSON round-trip preserves solvability', () {
    final level = SignalGenerator.generate(
      tier: DifficultyTier.large,
      id: 'roundtrip_test',
      random: Random(99),
    );
    final decoded = Level.fromJson(level.toJson());

    expect(decoded.optimum, level.optimum);
    expect(decoded.exampleSolution, level.exampleSolution);
    expect(decoded.nodes.length, level.nodes.length);
    expect(decoded.edges.length, level.edges.length);
    expect(decoded.directed, isTrue);

    final resolved = checkSolvability(decoded.toGraph(), GameMode.signal);
    expect(resolved, isA<Solved>());
    expect((resolved as Solved).optimalTapCount, level.optimum);
  });
}
