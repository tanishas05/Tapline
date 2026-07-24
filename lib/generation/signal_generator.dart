// Signal level generator — Phase 2. Not part of the "shared, portable
// module" Phase 2 item 2 asks for (that's explicitly scoped to
// Classic/Capacity) — Signal's directed-graph construction is a
// different enough problem (driver count via bipartite matching, not
// coverage) that it earns its own file, following the same
// construct-then-verify shape rather than sharing code with
// classic_capacity_generator.dart.
//
// CONSTRUCTION — disjoint directed chains: k disjoint directed chains
// (c0_0 -> c0_1 -> ...), where k is the intended driver count. An
// isolated chain's head has no incoming edge, so Kuhn's algorithm has
// nothing to match it TO — it's always an unmatched V_in node, i.e.
// always a driver — and every other node in the chain is reachable by
// following the chain forward from that head. k disjoint chains ->
// exactly k drivers (see signal_solver.dart's matching + the
// perfectly-matched-component fix; a chain is never perfectly
// matched, so that fix never adds an extra driver here).
//
// Regular decoration (visual density/texture, [SignalGenerator.
// generate]) adds directed edges between chains but NEVER into a
// chain head — so it can never turn a head from unmatched to matched,
// meaning it provably can't change the driver count at all.
// construct-then-verify still runs afterward anyway (Phase 2's
// instruction applies uniformly), but it's not load-bearing on this
// path — confirmed empirically (180 prototype trials, zero retries
// needed) as well as by the construction itself.
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

      final chains = _ChainLayout.build(
        nodeCount: nodeCount,
        chainCount: targetDrivers,
        random: rng,
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
      'within $maxAttempts attempts. Should be unreachable: regular '
      'decoration never touches a chain head, so it cannot change the '
      'driver count (see this file\'s top doc comment); if this '
      'fires, check what changed in difficulty_tiers.dart or here.',
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

/// Mutable construction state for one disjoint-chains graph — node
/// indices, directed adjacency, and chain bookkeeping the generator
/// and the merge/decoration steps both need. Not exported — an
/// implementation detail of this file only.
class _ChainLayout {
  _ChainLayout._({
    required this.n,
    required this.outAdjacency,
    required this.ids,
    required this.chainNodes,
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
    );
  }

  final int n;
  final List<List<int>> outAdjacency;
  final List<String> ids;
  final List<List<int>> chainNodes;

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
    );
  }

  /// Adds up to [decorationCount] random directed edges between
  /// DIFFERENT chains, never targeting another chain's head (index 0)
  /// — see this file's top doc comment for why that specific
  /// restriction is what makes regular decoration provably unable to
  /// change the driver count.
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
      final nonHeadB = chainNodes[chainB].skip(1).toList();
      if (nonHeadB.isEmpty) continue;
      final a = nodesA[random.nextInt(nodesA.length)];
      final b = nonHeadB[random.nextInt(nonHeadB.length)];
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
