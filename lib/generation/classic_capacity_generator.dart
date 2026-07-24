// Shared, portable Classic/Capacity level generator — Phase 2 item 2:
// "Build the generation/validation logic for Classic and Capacity as
// a SHARED, PORTABLE module." One construction strategy, one
// verification path, branching only where the two modes actually
// differ (Capacity's capacity/demand assignment). Zero Flutter
// imports, living alongside the Phase 1 engine, per Phase 2's own
// wording — same discipline as lib/engine/, so this runs under plain
// `dart test test/generation` too.
//
// CONSTRUCTION — star clusters: k disjoint clusters (1 hub + >=1 leaf
// each), where k is the intended [Level.optimum]. A leaf only ever
// touches its own hub, so within one cluster the cheapest way to
// dominate it is always tapping the hub (1 tap) — tapping every leaf
// instead costs (clusterSize - 1) taps, never fewer. Decoration edges
// added afterward are restricted to leaf<->leaf, ACROSS different
// clusters, and never touch a hub — so every cluster's hub can still
// only ever be dominated by itself or one of its own leaves, meaning
// the dominating set needs >=1 node from each cluster's disjoint
// {hub}+leaves set no matter what decoration exists. For Classic
// that's a proof, not a hope. Capacity's numeric spillover threshold
// doesn't inherit that proof for free — it's a threshold problem, not
// a pure coverage one — which is exactly why the solver verification
// pass below still does real work for Capacity, not just formality.
//
// VERIFICATION: every candidate graph is solved for real via
// [checkSolvability] and only accepted if the result matches the
// intended optimum exactly (Capacity can also come back [Infeasible]
// if the demand assignment overshot what tapping a node and its
// neighbors could ever supply) — reject and regenerate otherwise, per
// Phase 2 item 2's "construct-then-verify."
//
// No Dart SDK in the sandbox this was written in (same constraint
// Phase 1 hit — see lib/engine/README.md), so this construction was
// prototyped and swept in Python first: 360 trials across all three
// tiers and both modes, every one matching its intended optimum on
// the FIRST construct-then-verify attempt, plus targeted stress tests
// (1.5x decoration density, a deliberately-broken capacity margin to
// confirm the reject-and-retry path actually engages rather than
// being dead code). [maxAttempts] below exists as a guardrail for if
// difficulty_tiers.dart's tunables ever drift somewhere unsafe, not
// because retries are expected in normal operation.

import 'dart:math';

import '../data/level_schema.dart';
import '../engine/engine.dart';
import 'difficulty_tiers.dart';
import 'level_generation_exception.dart';

class ClassicCapacityGenerator {
  ClassicCapacityGenerator._();

  static const int maxAttempts = 25;

  /// Generates one verified [Level] for [mode] (must be
  /// [GameMode.classic] or [GameMode.capacity]) at [tier].
  ///
  /// [id] is caller-supplied — the offline CLI script
  /// (tool/generate_levels.dart) assigns sequential ids for curated
  /// content; the on-device retry path (LevelLoader) mints a fresh
  /// one per attempt. Pass [random] for reproducible output (the CLI
  /// seeds it, so re-running it reproduces the same curated set);
  /// omit it for real on-device variety — defaults to an unseeded
  /// `Random()`, so a player's retries actually differ, satisfying
  /// the Master Context's "never reuse the exact layout just
  /// attempted" retry rule.
  static Level generate({
    required GameMode mode,
    required DifficultyTier tier,
    required String id,
    Random? random,
  }) {
    if (mode == GameMode.signal) {
      throw ArgumentError.value(
        mode,
        'mode',
        'ClassicCapacityGenerator only handles classic/capacity. '
            'Signal has its own generator (signal_generator.dart) '
            'because its construction strategy is fundamentally '
            'different (directed chains, not star clusters).',
      );
    }

    final rng = random ?? Random();
    final nodeCountRange = classicCapacityNodeCount[tier]!;
    final clusterCountRange = classicCapacityClusterCount[tier]!;

    for (var attempt = 0; attempt < maxAttempts; attempt++) {
      final nodeCount = nodeCountRange.roll(rng);

      // Each cluster needs a hub + >=1 leaf, so more clusters than
      // nodeCount~/2 is infeasible outright — clamp rather than
      // build something impossible. difficulty_tiers.dart's ranges
      // are designed so this clamp never actually engages (see that
      // file's INVARIANT comment); it's a guardrail, not a lever.
      final feasibleMax = nodeCount ~/ 2;
      final clusterMax = min(clusterCountRange.max, feasibleMax);
      final clusterMin = min(clusterCountRange.min, clusterMax);
      final targetOptimum =
          clusterMin + rng.nextInt(clusterMax - clusterMin + 1);

      final cluster = _StarClusterLayout.build(
        nodeCount: nodeCount,
        clusterCount: targetOptimum,
        random: rng,
      );

      final decorationCount =
          (classicCapacityDecorationFraction * cluster.n).round();
      cluster.addLeafDecoration(decorationCount, rng);

      final capacity = List<double>.filled(cluster.n, 0);
      final demand = List<double>.filled(cluster.n, 0);
      if (mode == GameMode.capacity) {
        _assignCapacityAndDemand(
          tier: tier,
          cluster: cluster,
          capacity: capacity,
          demand: demand,
          random: rng,
        );
      }

      final positions = cluster.layoutPositions();
      final nodes = <GraphNode>[
        for (var i = 0; i < cluster.n; i++)
          GraphNode(
            id: cluster.ids[i],
            position: positions[i],
            capacity: capacity[i],
            demand: demand[i],
          ),
      ];
      final edges = cluster.buildEdges();

      final graph = Graph.undirected(nodes: nodes, edges: edges);
      final result = checkSolvability(graph, mode);

      final level = switch (result) {
        Solved(:final optimalTapCount, :final optimalTaps)
            when optimalTapCount == targetOptimum =>
          Level(
            id: id,
            mode: mode,
            difficultyTier: tier,
            nodes: nodes,
            edges: edges,
            optimum: optimalTapCount,
            exampleSolution: optimalTaps,
            timeLimitSeconds: timeLimitSecondsByTier[tier]!,
          ),
        _ => null,
      };
      if (level != null) return level;
    }

    throw LevelGenerationException(
      'ClassicCapacityGenerator: no valid level verified for $mode at '
      '${tier.name} within $maxAttempts attempts. This should be '
      'unreachable with difficulty_tiers.dart\'s current tunables — '
      'if it fires, something in that table drifted into unsafe '
      'territory (see this file\'s doc comment).',
    );
  }
}

void _assignCapacityAndDemand({
  required DifficultyTier tier,
  required _StarClusterLayout cluster,
  required List<double> capacity,
  required List<double> demand,
  required Random random,
}) {
  final config = capacityTierConfig[tier]!;
  for (var c = 0; c < cluster.leavesOfCluster.length; c++) {
    final leaves = cluster.leavesOfCluster[c];
    var maxLeafDemand = 0.0;
    for (final leaf in leaves) {
      final isHungry = random.nextDouble() < config.hungryFraction;
      var d = config.leafDemandRange.roll(random);
      if (isHungry) d *= config.hungryDemandMultiplier.roll(random);
      demand[leaf] = d;
      capacity[leaf] = capacityLeafBaseCapacity.roll(random);
      if (d > maxLeafDemand) maxLeafDemand = d;
    }
    final hub = cluster.hubOfCluster[c];
    // See capacityHubCapacityMargin's doc comment: this is what makes
    // "tap every hub" a valid witness solution, independent of the
    // solver — the solver verification pass is what actually decides
    // acceptance, this is just what makes acceptance likely.
    final hubCap = max(2.0 * maxLeafDemand, 1.0) * capacityHubCapacityMargin;
    capacity[hub] = hubCap;
    demand[hub] = hubCap * 0.5;
  }
}

/// Mutable construction state for one star-cluster graph: node
/// indices, adjacency, and the hub/leaf bookkeeping the generator and
/// [_assignCapacityAndDemand] both need. Not exported — an
/// implementation detail of this file only.
class _StarClusterLayout {
  _StarClusterLayout._({
    required this.n,
    required this.adjacency,
    required this.ids,
    required this.hubOfCluster,
    required this.leavesOfCluster,
  });

  factory _StarClusterLayout.build({
    required int nodeCount,
    required int clusterCount,
    required Random random,
  }) {
    assert(clusterCount >= 1);
    assert(
      nodeCount >= clusterCount * 2,
      'nodeCount=$nodeCount too small for $clusterCount clusters of '
      '>=2 nodes each',
    );

    // every cluster starts at the minimum size (hub + 1 leaf); spare
    // nodes are handed out to random clusters one at a time so sizes
    // come out organically uneven rather than perfectly even.
    final sizes = List<int>.filled(clusterCount, 2);
    var remaining = nodeCount - 2 * clusterCount;
    while (remaining > 0) {
      sizes[random.nextInt(clusterCount)]++;
      remaining--;
    }

    final adjacency = <Set<int>>[];
    final ids = <String>[];
    final hubOfCluster = <int>[];
    final leavesOfCluster = <List<int>>[];
    var n = 0;

    for (var c = 0; c < clusterCount; c++) {
      final hub = n++;
      adjacency.add(<int>{});
      ids.add('c${c}_hub');
      hubOfCluster.add(hub);

      final leaves = <int>[];
      for (var j = 0; j < sizes[c] - 1; j++) {
        final leaf = n++;
        adjacency.add(<int>{});
        ids.add('c${c}_leaf$j');
        leaves.add(leaf);
        adjacency[hub].add(leaf);
        adjacency[leaf].add(hub);
      }
      leavesOfCluster.add(leaves);
    }

    return _StarClusterLayout._(
      n: n,
      adjacency: adjacency,
      ids: ids,
      hubOfCluster: hubOfCluster,
      leavesOfCluster: leavesOfCluster,
    );
  }

  final int n;
  final List<Set<int>> adjacency;
  final List<String> ids;
  final List<int> hubOfCluster;
  final List<List<int>> leavesOfCluster;

  /// Adds up to [decorationCount] random leaf<->leaf edges strictly
  /// between DIFFERENT clusters, never touching a hub — see this
  /// file's top doc comment for why that specific restriction is what
  /// makes decoration provably safe for Classic.
  void addLeafDecoration(int decorationCount, Random random) {
    final clusterCount = leavesOfCluster.length;
    if (clusterCount < 2) return;

    var added = 0;
    var attempts = 0;
    final attemptBudget = decorationCount * 20;
    while (added < decorationCount && attempts < attemptBudget) {
      attempts++;
      final clusterA = random.nextInt(clusterCount);
      final clusterB = random.nextInt(clusterCount);
      if (clusterA == clusterB) continue;
      final leavesA = leavesOfCluster[clusterA];
      final leavesB = leavesOfCluster[clusterB];
      if (leavesA.isEmpty || leavesB.isEmpty) continue;
      final a = leavesA[random.nextInt(leavesA.length)];
      final b = leavesB[random.nextInt(leavesB.length)];
      if (adjacency[a].contains(b)) continue;
      adjacency[a].add(b);
      adjacency[b].add(a);
      added++;
    }
  }

  List<GraphEdge> buildEdges() {
    final edges = <GraphEdge>[];
    for (var i = 0; i < n; i++) {
      for (final j in adjacency[i]) {
        if (j > i) edges.add(GraphEdge(ids[i], ids[j]));
      }
    }
    return edges;
  }

  /// Deterministic "wheel of clusters" layout: cluster hubs evenly
  /// spaced on a ring, leaves evenly spaced on a smaller ring around
  /// their own hub. Purely cosmetic — no solver ever reads this.
  ///
  /// Both ring radii are derived from the actual cluster/leaf counts
  /// rather than fixed constants — a fixed 350/90 (the original
  /// version of this method) spaces hubs the SAME ~700-unit diameter
  /// apart whether there are 2 clusters or 8, which for a low
  /// clusterCount (exactly what Small/Medium tiers roll most often,
  /// since clusterCount == the level's optimum) put the canvas at
  /// roughly the same footprint as a much bigger level while covering
  /// it with far fewer, far more sparsely placed nodes. On a phone
  /// viewport that reads as: a tight little clump of 2-3 nodes in one
  /// corner, with pipes running off toward other clusters positioned
  /// hundreds of logical pixels away, most of which land outside the
  /// visible/auto-fit viewport entirely.
  List<GraphPoint> layoutPositions() {
    const centerX = 500.0;
    const centerY = 500.0;
    const nodeDiameter = 64.0;
    const minGap = 26.0; // clearance between adjacent node edges
    const nodeChord = nodeDiameter + minGap;

    // Enough radius that `count` points evenly spaced on a ring keep
    // at least `minChord` between adjacent points. Chord length
    // between neighbors at angular spacing (2*pi/count) is
    // 2*R*sin(pi/count); solve for R given the minimum chord needed.
    double ringRadiusFor(int count, double minChord, double minRadius) {
      if (count <= 1) return minRadius;
      final angularHalfStep = pi / count;
      final radius = minChord / (2 * sin(angularHalfStep));
      return radius < minRadius ? minRadius : radius;
    }

    final clusterCount = leavesOfCluster.length;
    final leafRingRadiusByCluster = [
      for (final leaves in leavesOfCluster)
        ringRadiusFor(leaves.length, nodeChord, nodeChord),
    ];

    // The cluster ring needs to keep neighboring clusters' own leaf
    // rings from overlapping each other, not just their hubs — so
    // the chord required between adjacent cluster hubs is the sum of
    // both clusters' leaf-ring reach (worst case: the largest leaf
    // ring on both sides) plus a full node's clearance.
    final maxLeafRingRadius = leafRingRadiusByCluster.fold(
      0.0,
      (a, b) => a > b ? a : b,
    );
    final clusterMinChord = maxLeafRingRadius * 2 + nodeChord;
    final clusterRingRadius = clusterCount <= 1
        ? 0.0
        : ringRadiusFor(clusterCount, clusterMinChord, clusterMinChord / 2);

    final positions = List<GraphPoint?>.filled(n, null);

    for (var c = 0; c < clusterCount; c++) {
      final angle = 2 * pi * c / clusterCount;
      final hubX = centerX + clusterRingRadius * cos(angle);
      final hubY = centerY + clusterRingRadius * sin(angle);
      positions[hubOfCluster[c]] = GraphPoint(hubX, hubY);

      final leaves = leavesOfCluster[c];
      final leafRingRadius = leafRingRadiusByCluster[c];
      for (var j = 0; j < leaves.length; j++) {
        final leafAngle = 2 * pi * j / leaves.length;
        positions[leaves[j]] = GraphPoint(
          hubX + leafRingRadius * cos(leafAngle),
          hubY + leafRingRadius * sin(leafAngle),
        );
      }
    }

    return [for (final p in positions) p!];
  }
}
