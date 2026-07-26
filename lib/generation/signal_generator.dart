// Signal level generator — Phase 2, extended with cycle-aware
// construction. Not part of the "shared, portable module" Phase 2
// item 2 asks for (that's explicitly scoped to Classic/Capacity) —
// Signal's directed-graph construction is a different enough problem
// (driver count via bipartite matching, not coverage) that it earns
// its own file, following the same construct-then-verify shape
// rather than sharing code with classic_capacity_generator.dart.
//
// CONSTRUCTION — k disjoint components, one of THREE shapes each,
// chosen so every shape independently needs exactly 1 driver — so
// total drivers = k always, by construction, same guarantee the
// original chains-only generator had, just now provable across three
// cases instead of one:
//
//   1. CHAIN (the original shape): c0 -> c1 -> ... -> c(m-1). Head
//      has in-degree 0 forever, so it's always an unmatched V_in node
//      = always a driver. Every other node has exactly one in-edge
//      (its predecessor), so the chain is already perfectly
//      self-matched — 1 driver, exactly.
//
//   2. STEM_BUD (a run that loops back on itself at the end):
//      s0 -> s1 -> ... -> s(k-1) -> b0 -> b1 -> ... -> b(j-1) -> b0.
//      Traced by hand against the actual matching algorithm below
//      (see test/generation/signal_generator_test.dart): s(k-1)'s
//      edge into b0 gets used as b0's match, the cycle's own forward
//      edges absorb every other bud node, and the closing edge
//      b(j-1)->b0 finds b0 already taken and simply goes unused — one
//      driver (s0), same as a plain chain, just with a loop hanging
//      off the end.
//
//   3. CYCLE (a standalone loop, no stem): b0 -> b1 -> ... ->
//      b(j-1) -> b0. Every node gets perfectly matched by the cycle's
//      own edges (a full cyclic permutation) — zero unmatched V_in
//      nodes internally. This is the case
//      signal_solver.dart's whole SCC/residual mechanism exists for:
//      with no stem feeding it, this component is unreached by every
//      other component's driver, so the residual pass finds it as an
//      unreached source SCC and adds exactly one driver for it. A
//      pure chains-only generator can never produce this shape, so
//      that part of the solver was previously untested by anything
//      this generator actually shipped.
//
// Because each shape is independently proven to cost exactly 1
// driver, mixing all three per generated level doesn't touch the
// "target drivers = k" contract generate() already relies on — no
// change needed to the outer construct-then-verify loop below.
//
// DECORATION's "never touch a chain head" rule generalizes to
// "never touch a component's PROTECTED node set": {head} for a chain
// or a stem_bud (only the very first node — the bud portion of a
// stem_bud is already reached via its own stem, so it's as safe to
// decorate as any interior chain node), and — new, and the one rule
// that has no analogue in the old chains-only version — EVERY node
// of a pure cycle. Pointing any external edge into ANY part of an
// isolated cycle would make it reachable from whatever fed that
// edge, letting the residual pass skip it entirely and silently drop
// the driver count by one — the exact "denser can need fewer
// drivers" phenomonon generateTeachingPair demonstrates deliberately
// via explicit merging, showing up here as an unwanted side effect
// if left unguarded. See [_ChainLayout.protectedTargets].
//
// Small tier stays chains-only (richness gated off below) — at
// 8-14 nodes across 2-4 components there's rarely enough headroom
// for a 2-node cycle or 3-node stem+bud to read as anything but
// cramped, and the small tier's whole point is to teach the mode's
// basic idea, not its harder cases.
//
// generateTeachingPair() below is untouched — chains only. Its
// "denser needs fewer drivers via explicit merging" demonstration is
// clearest kept simple; entangling it with cycle/stem_bud shapes
// would need its own separate driver-count proof for what merging a
// cycle into a chain costs, which isn't needed to make the point it
// already makes cleanly with chains alone.
//
// Regular decoration (visual density/texture, [SignalGenerator.
// generate]) adds directed edges between components, restricted by
// [_ChainLayout.protectedTargets] as above — construct-then-
// verify still runs afterward anyway (Phase 2's instruction applies
// uniformly), but it's not load-bearing on this path — confirmed
// empirically (180 prototype trials pre-richness, plus a further
// sweep across all three shapes post-richness, zero retries needed)
// as well as by the construction itself.
//
// Chain-merging ([SignalGenerator.generateTeachingPair]) is the
// opposite: it deliberately links one chain's tail into another
// chain's head, splicing them into one effective chain and dropping
// the driver count by exactly (mergedChains - 1). That reduction IS
// the deliberate "denser graphs can need fewer driver nodes" moment
// Phase 2 asks to make visible rather than hide — 30 prototype trials
// all landed on the exact predicted reduced count.
//
// No Dart SDK in the sandbox this was written in — same note as
// classic_capacity_generator.dart; this was prototyped and swept in
// Python first before hand-translation.

import 'dart:math';

import '../data/level_schema.dart';
import '../engine/engine.dart';
import 'difficulty_tiers.dart';
import 'level_generation_exception.dart';

class SignalGenerator {
  SignalGenerator._();

  static const int maxAttempts = 25;

  /// How much of the per-component shape mix should be cycle/stem_bud
  /// rather than plain chain, by tier. Small stays chains-only — see
  /// this file's top doc comment for why. Large is richer than
  /// medium: more nodes per component gives more room for a cycle or
  /// stem+bud to read clearly rather than feeling cramped.
  static ({double cycleFraction, double stemBudFraction}) _richnessFor(
      DifficultyTier tier,
      ) {
    return switch (tier) {
      DifficultyTier.small => (cycleFraction: 0.0, stemBudFraction: 0.0),
      DifficultyTier.medium => (cycleFraction: 0.25, stemBudFraction: 0.25),
      DifficultyTier.large => (cycleFraction: 0.35, stemBudFraction: 0.35),
    };
  }

  /// Generates one verified regular [Level] for [GameMode.signal] at
  /// [tier]. See [ClassicCapacityGenerator.generate]'s doc comment
  /// re: [id]/[random] — same contract here.
  static Level generate({
    required DifficultyTier tier,
    required String id,
    Random? random,
  }) {
    final rng = random ?? Random();
    final nodeCountRange = signalNodeCount[tier]!;
    final chainCountRange = signalChainCount[tier]!;

    for (var attempt = 0; attempt < maxAttempts; attempt++) {
      final nodeCount = nodeCountRange.roll(rng);
      final feasibleMax = nodeCount; // a chain can be a single node
      final chainMax = min(chainCountRange.max, feasibleMax);
      final chainMin = min(chainCountRange.min, chainMax);
      final targetDrivers = chainMin + rng.nextInt(chainMax - chainMin + 1);

      final chains = _ChainLayout.buildMixed(
        nodeCount: nodeCount,
        chainCount: targetDrivers,
        random: rng,
        cycleFraction: _richnessFor(tier).cycleFraction,
        stemBudFraction: _richnessFor(tier).stemBudFraction,
      );

      final decorationCount = (signalDecorationFraction * chains.n).round();
      chains.addDecoration(decorationCount, rng);

      final level = _solveAndBuild(
        chains: chains,
        tier: tier,
        id: id,
        targetDrivers: targetDrivers,
      );
      if (level != null) return level;
    }

    throw LevelGenerationException(
      'SignalGenerator: no valid level verified for ${tier.name} '
          'within $maxAttempts attempts. Should be unreachable: every '
          'component shape (chain/stem_bud/cycle) provably needs exactly '
          '1 driver and decoration respects protectedTargets, so this '
          "cannot change the driver count (see this file's top doc "
          'comment); if this fires, check what changed in '
          'difficulty_tiers.dart or here.',
    );
  }

  /// Generates a linked PAIR of levels at the same [tier] and same
  /// node count — a sparse baseline (chains left alone) and a denser
  /// variant (some of those same chains spliced together) — built
  /// specifically to make Phase 2's pedagogical hook concrete: "denser
  /// graphs can need fewer driver nodes than sparse ones." Both are
  /// independently solver-verified, and the denser one is only
  /// accepted if it verifies to STRICTLY fewer drivers than the
  /// sparse one, so this can never silently ship a pair that doesn't
  /// actually demonstrate the point. Deliberately has no random
  /// decoration on top of the chains/merge — the point is for the
  /// merge links themselves to be the visible, traceable reason the
  /// driver count dropped, not buried in unrelated extra edges.
  ///
  /// Intended for curated/offline use (tool/generate_levels.dart) at
  /// hand-picked slots, not the general on-device retry path — a
  /// retry just needs *a* valid level, not a matched teaching pair.
  static ({Level sparse, Level dense}) generateTeachingPair({
    required DifficultyTier tier,
    required String sparseId,
    required String denseId,
    Random? random,
  }) {
    final rng = random ?? Random();
    final nodeCountRange = signalNodeCount[tier]!;
    final chainCountRange = signalChainCount[tier]!;

    for (var attempt = 0; attempt < maxAttempts; attempt++) {
      final nodeCount = nodeCountRange.roll(rng);
      final chainMax = min(chainCountRange.max, nodeCount);
      // need >=2 chains to have anything to merge
      if (chainMax < 2) continue;
      final chainMin = min(max(chainCountRange.min, 2), chainMax);
      final sparseDrivers = chainMin + rng.nextInt(chainMax - chainMin + 1);

      final chains = _ChainLayout.build(
        nodeCount: nodeCount,
        chainCount: sparseDrivers,
        random: rng,
      );

      final sparseLevel = _solveAndBuild(
        chains: chains,
        tier: tier,
        id: sparseId,
        targetDrivers: sparseDrivers,
      );
      if (sparseLevel == null) continue;

      // Merge a random, cycle-safe subset of chains into one long
      // chain: shuffle all chain indices, take a random-length prefix
      // as the merge set, splice that set tail-to-head in sequence.
      // Any chain index appears at most once in the splice sequence,
      // so the links always form one strictly-linear path through
      // distinct chains — never a loop back to an earlier one.
      final order = List<int>.generate(chains.chainCount, (i) => i)
        ..shuffle(rng);
      final mergeSpan = 2 + rng.nextInt(chains.chainCount - 1);
      final toMerge = order.take(mergeSpan).toList();

      final denseChains = chains.copy();
      denseChains.mergeChainsInOrder(toMerge);

      final expectedDenseDrivers = sparseDrivers - (mergeSpan - 1);
      final denseLevel = _solveAndBuild(
        chains: denseChains,
        tier: tier,
        id: denseId,
        targetDrivers: expectedDenseDrivers,
      );
      if (denseLevel == null) continue;

      // Belt-and-suspenders: this should already be guaranteed by the
      // exact-match check inside _solveAndBuild above, but the point
      // of a teaching pair is specifically "dense has fewer drivers,"
      // so that invariant gets its own explicit check rather than
      // resting entirely on the arithmetic being right.
      if (denseLevel.optimum >= sparseLevel.optimum) continue;

      return (sparse: sparseLevel, dense: denseLevel);
    }

    throw LevelGenerationException(
      'SignalGenerator.generateTeachingPair: no valid pair verified '
          'for ${tier.name} within $maxAttempts attempts.',
    );
  }

  static Level? _solveAndBuild({
    required _ChainLayout chains,
    required DifficultyTier tier,
    required String id,
    required int targetDrivers,
  }) {
    final positions = chains.layoutPositions();
    final nodes = <GraphNode>[
      for (var i = 0; i < chains.n; i++)
        GraphNode(id: chains.ids[i], position: positions[i]),
    ];
    final edges = chains.buildEdges();

    final graph = Graph.directed(nodes: nodes, edges: edges);
    final result = checkSolvability(graph, GameMode.signal);

    return switch (result) {
      Solved(:final optimalTapCount, :final optimalTaps)
      when optimalTapCount == targetDrivers =>
          Level(
            id: id,
            mode: GameMode.signal,
            difficultyTier: tier,
            nodes: nodes,
            edges: edges,
            optimum: optimalTapCount,
            exampleSolution: optimalTaps,
            timeLimitSeconds: timeLimitSecondsByTier[tier]!,
          ),
      _ => null,
    };
  }
}

/// Which of the three provably-1-driver shapes a component takes —
/// see this file's top doc comment for the matching proof behind
/// each. Only [_ChainLayout.buildMixed] ever produces [cycle] or
/// [stemBud]; the plain [_ChainLayout.build] factory (used by
/// [SignalGenerator.generateTeachingPair]) only ever produces [chain].
enum _ComponentShape { chain, stemBud, cycle }

/// Mutable construction state for one disjoint-components graph —
/// node indices, directed adjacency, and per-component bookkeeping
/// the generator and the merge/decoration steps both need. Not
/// exported — an implementation detail of this file only.
class _ChainLayout {
  _ChainLayout._({
    required this.n,
    required this.outAdjacency,
    required this.ids,
    required this.chainNodes,
    required this.protectedTargets,
  });

  factory _ChainLayout.build({
    required int nodeCount,
    required int chainCount,
    required Random random,
  }) {
    assert(chainCount >= 1);
    assert(
    nodeCount >= chainCount,
    'nodeCount=$nodeCount too small for $chainCount chains of >=1 '
        'node each',
    );

    final sizes = List<int>.filled(chainCount, 1);
    var remaining = nodeCount - chainCount;
    while (remaining > 0) {
      sizes[random.nextInt(chainCount)]++;
      remaining--;
    }

    final outAdjacency = <List<int>>[];
    final ids = <String>[];
    final chainNodes = <List<int>>[];
    var n = 0;

    for (var c = 0; c < chainCount; c++) {
      final nodesInChain = <int>[];
      for (var j = 0; j < sizes[c]; j++) {
        outAdjacency.add(<int>[]);
        ids.add('s${c}_$j');
        nodesInChain.add(n);
        n++;
      }
      for (var j = 0; j < nodesInChain.length - 1; j++) {
        outAdjacency[nodesInChain[j]].add(nodesInChain[j + 1]);
      }
      chainNodes.add(nodesInChain);
    }

    return _ChainLayout._(
      n: n,
      outAdjacency: outAdjacency,
      ids: ids,
      chainNodes: chainNodes,
      protectedTargets: [for (final nodes in chainNodes) {nodes.first}],
    );
  }

  /// Builds [chainCount] components, each independently rolled as
  /// [_ComponentShape.cycle] (probability [cycleFraction]),
  /// [_ComponentShape.stemBud] (probability [stemBudFraction]), or
  /// otherwise a plain chain — with an automatic fallback to chain
  /// whenever the component's remaining node budget can't afford a
  /// richer shape's minimum size (cycle needs >=2 nodes, stem_bud
  /// needs >=3: >=1 stem node + >=2 bud nodes). Every shape is
  /// independently proven (top doc comment) to need exactly 1 driver,
  /// so mixing them freely never disturbs the "chainCount drivers
  /// total" contract [SignalGenerator.generate] relies on.
  factory _ChainLayout.buildMixed({
    required int nodeCount,
    required int chainCount,
    required Random random,
    required double cycleFraction,
    required double stemBudFraction,
  }) {
    assert(chainCount >= 1);
    assert(
    nodeCount >= chainCount,
    'nodeCount=$nodeCount too small for $chainCount components of '
        '>=1 node each',
    );

    const minSizeFor = {
      _ComponentShape.chain: 1,
      _ComponentShape.stemBud: 3,
      _ComponentShape.cycle: 2,
    };

    // Roll a shape per component, left to right, downgrading to
    // chain whenever the remaining budget can't cover this
    // component's richer minimum PLUS 1 node reserved for each
    // component still to come. Order is shuffled first so an early
    // component doesn't systematically get first claim on richness
    // every time.
    final order = List<int>.generate(chainCount, (i) => i)..shuffle(random);
    final shapes = List<_ComponentShape>.filled(chainCount, _ComponentShape.chain);
    var budget = nodeCount;
    for (var i = 0; i < order.length; i++) {
      final componentsLeftAfterThis = order.length - i - 1;
      final roll = random.nextDouble();
      var shape = roll < cycleFraction
          ? _ComponentShape.cycle
          : roll < cycleFraction + stemBudFraction
          ? _ComponentShape.stemBud
          : _ComponentShape.chain;
      final affordable =
          budget - componentsLeftAfterThis >= minSizeFor[shape]!;
      if (!affordable) shape = _ComponentShape.chain;
      shapes[order[i]] = shape;
      budget -= minSizeFor[shape]!;
    }

    // Start every component at its shape's minimum, then hand out
    // the leftover nodes randomly — same distribution approach as
    // the original chains-only build().
    final sizes = [for (final shape in shapes) minSizeFor[shape]!];
    var remaining = nodeCount - sizes.fold(0, (a, b) => a + b);
    while (remaining > 0) {
      sizes[random.nextInt(chainCount)]++;
      remaining--;
    }

    final outAdjacency = <List<int>>[];
    final ids = <String>[];
    final chainNodes = <List<int>>[];
    final protectedTargets = <Set<int>>[];
    var n = 0;

    for (var c = 0; c < chainCount; c++) {
      final componentNodes = <int>[];
      for (var j = 0; j < sizes[c]; j++) {
        outAdjacency.add(<int>[]);
        ids.add('s${c}_$j');
        componentNodes.add(n);
        n++;
      }
      chainNodes.add(componentNodes);

      switch (shapes[c]) {
        case _ComponentShape.chain:
          for (var j = 0; j < componentNodes.length - 1; j++) {
            outAdjacency[componentNodes[j]].add(componentNodes[j + 1]);
          }
          protectedTargets.add({componentNodes.first});

        case _ComponentShape.cycle:
          for (var j = 0; j < componentNodes.length; j++) {
            final next = componentNodes[(j + 1) % componentNodes.length];
            outAdjacency[componentNodes[j]].add(next);
          }
          // Every node, not just one — see top doc comment for why
          // a pure cycle can't safely expose ANY decoration target.
          protectedTargets.add(componentNodes.toSet());

        case _ComponentShape.stemBud:
        // stemLen in [1, size-2] guarantees the bud gets >=2 nodes.
          final stemLen = 1 + random.nextInt(componentNodes.length - 2);
          final stem = componentNodes.sublist(0, stemLen);
          final bud = componentNodes.sublist(stemLen);
          for (var j = 0; j < stem.length - 1; j++) {
            outAdjacency[stem[j]].add(stem[j + 1]);
          }
          outAdjacency[stem.last].add(bud.first);
          for (var j = 0; j < bud.length; j++) {
            final next = bud[(j + 1) % bud.length];
            outAdjacency[bud[j]].add(next);
          }
          protectedTargets.add({stem.first});
      }
    }

    return _ChainLayout._(
      n: n,
      outAdjacency: outAdjacency,
      ids: ids,
      chainNodes: chainNodes,
      protectedTargets: protectedTargets,
    );
  }

  final int n;
  final List<List<int>> outAdjacency;
  final List<String> ids;
  final List<List<int>> chainNodes;

  /// Per component, the node indices decoration must never target —
  /// see this file's top doc comment. `{head}` for a chain or
  /// stem_bud; every node for a pure cycle.
  final List<Set<int>> protectedTargets;

  int get chainCount => chainNodes.length;

  /// Deep-enough copy for the teaching-pair path, which needs to
  /// mutate a merged variant without touching the sparse baseline
  /// that was already built from the same layout.
  _ChainLayout copy() {
    return _ChainLayout._(
      n: n,
      outAdjacency: [for (final list in outAdjacency) List<int>.from(list)],
      ids: List<String>.from(ids),
      chainNodes: [for (final list in chainNodes) List<int>.from(list)],
      protectedTargets: [for (final s in protectedTargets) Set<int>.from(s)],
    );
  }

  /// Adds up to [decorationCount] random directed edges between
  /// DIFFERENT components, never targeting a node in that component's
  /// [protectedTargets] — see this file's top doc comment for why
  /// that's what makes regular decoration provably unable to change
  /// the driver count, for every shape a component can take.
  void addDecoration(int decorationCount, Random random) {
    if (chainCount < 2) return;

    var added = 0;
    var attempts = 0;
    final attemptBudget = decorationCount * 20;
    while (added < decorationCount && attempts < attemptBudget) {
      attempts++;
      final chainA = random.nextInt(chainCount);
      final chainB = random.nextInt(chainCount);
      if (chainA == chainB) continue;
      final nodesA = chainNodes[chainA];
      final eligibleB = chainNodes[chainB]
          .where((node) => !protectedTargets[chainB].contains(node))
          .toList();
      if (eligibleB.isEmpty) continue;
      final a = nodesA[random.nextInt(nodesA.length)];
      final b = eligibleB[random.nextInt(eligibleB.length)];
      if (outAdjacency[a].contains(b)) continue;
      outAdjacency[a].add(b);
      added++;
    }
  }

  /// Splices the chains named in [order] into one long chain,
  /// tail-to-head, in that sequence — e.g. `[2, 0, 1]` links chain 2's
  /// tail into chain 0's head, then chain 0's tail into chain 1's
  /// head. Always cycle-safe: each chain index appears at most once in
  /// [order], so the links form one strictly-linear sequence through
  /// distinct chains, never a loop back to an earlier one.
  void mergeChainsInOrder(List<int> order) {
    for (var i = 0; i < order.length - 1; i++) {
      final tailOfThis = chainNodes[order[i]].last;
      final headOfNext = chainNodes[order[i + 1]].first;
      outAdjacency[tailOfThis].add(headOfNext);
    }
  }

  List<GraphEdge> buildEdges() {
    final edges = <GraphEdge>[];
    for (var i = 0; i < n; i++) {
      for (final j in outAdjacency[i]) {
        edges.add(GraphEdge(ids[i], ids[j]));
      }
    }
    return edges;
  }

  /// Deterministic layout: chains run left-to-right as roughly
  /// horizontal rows, stacked top-to-bottom — reads like a signal-flow
  /// schematic rather than Classic/Capacity's circular "wheel of
  /// clusters." Purely cosmetic, same caveat as
  /// classic_capacity_generator.dart's layoutPositions.
  List<GraphPoint> layoutPositions() {
    const marginX = 100.0;
    const marginY = 100.0;
    const rowHeight = 120.0;
    const nodeSpacing = 110.0;

    final positions = List<GraphPoint?>.filled(n, null);
    for (var c = 0; c < chainCount; c++) {
      final y = marginY + c * rowHeight;
      final nodes = chainNodes[c];
      for (var j = 0; j < nodes.length; j++) {
        positions[nodes[j]] = GraphPoint(marginX + j * nodeSpacing, y);
      }
    }
    return [for (final p in positions) p!];
  }
}