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

          // The strict "no edge ever targets a _0 node" invariant only
          // held back when every component was a plain chain. With
          // cycle/stem_bud shapes now in the mix (see
          // signal_generator.dart's top doc comment), a cycle
          // component's OWN closing edge legitimately targets its
          // local index-0 node — that's expected, not a violation.
          // The real invariant — driver count is exactly what was
          // targeted, for whatever shape mix got built — is what the
          // checkSolvability() call above already proves end to end,
          // for every trial, regardless of shape. See the dedicated
          // richness checks below for confirmation that cycle/
          // stem_bud shapes are actually being produced, not just
          // theoretically possible.
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

  group('SignalGenerator richness (cycle/stem_bud shapes)', () {
    // Enough trials that "richness exists but got unlucky" isn't a
    // plausible false negative: at medium/large's ~0.5-0.7 combined
    // cycle+stem_bud fraction per component, the odds every single
    // component across every single trial rolled plain chain are
    // astronomically small if the shape-mixing code is wired up at
    // all. This is a "the new code path actually fires" check, not a
    // proof — that proof is the re-solve above, which runs regardless
    // of shape.
    const trials = 20;

    test('small tier never contains a directed cycle', () {
      for (var trial = 0; trial < trials; trial++) {
        final level = SignalGenerator.generate(
          tier: DifficultyTier.small,
          id: 'richness_small_$trial',
          random: Random(5000 + trial),
        );
        expect(
          _hasDirectedCycle(level),
          isFalse,
          reason: 'small tier should stay chains-only: level ${level.id}',
        );
      }
    });

    for (final tier in [DifficultyTier.medium, DifficultyTier.large]) {
      test('${tier.name} tier actually produces directed cycles '
          'across a trial run (not just theoretically able to)', () {
        var sawACycle = false;
        for (var trial = 0; trial < trials; trial++) {
          final level = SignalGenerator.generate(
            tier: tier,
            id: 'richness_${tier.name}_$trial',
            random: Random(6000 + trial),
          );
          if (_hasDirectedCycle(level)) sawACycle = true;
        }
        expect(
          sawACycle,
          isTrue,
          reason: 'no directed cycle appeared in $trials ${tier.name} '
              'trials — richness gating may be broken',
        );
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

/// Plain DFS cycle detection over [level]'s directed edges — used
/// only by the richness sanity checks above, independent of anything
/// in signal_generator.dart or signal_solver.dart, so it can't share
/// a bug with the code it's checking.
bool _hasDirectedCycle(Level level) {
  final outEdges = <String, List<String>>{};
  for (final edge in level.edges) {
    (outEdges[edge.from] ??= <String>[]).add(edge.to);
  }

  const unvisited = 0, inStack = 1, done = 2;
  final state = <String, int>{for (final node in level.nodes) node.id: unvisited};

  bool dfs(String node) {
    state[node] = inStack;
    for (final next in outEdges[node] ?? const <String>[]) {
      if (state[next] == inStack) return true;
      if (state[next] == unvisited && dfs(next)) return true;
    }
    state[node] = done;
    return false;
  }

  for (final node in level.nodes) {
    if (state[node.id] == unvisited && dfs(node.id)) return true;
  }
  return false;
}