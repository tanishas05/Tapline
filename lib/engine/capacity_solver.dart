import 'dart:math' as math;

import 'graph.dart';
import 'solve_result.dart';

/// Exact weighted/capacitated dominating set solver for Capacity
/// mode, implementing the spillover formula from the Master Context
/// exactly: `total_supply(v) = cap(v)*tapped(v) + 0.5 * sum(cap(u)
/// for tapped neighbors u)`, winning once every node's supply meets
/// its demand.
///
/// This is NOT the Classic solver with different numbers swapped in.
/// A single tap in Classic instantly and fully covers everything in
/// its closed neighborhood; here a single tap might only partially
/// satisfy a neighbor, so a branch can't always resolve a node in one
/// step the way Classic does. Concretely: the branch-and-bound search
/// still picks the most-constrained unsatisfied node and still draws
/// candidates from its closed neighborhood, but "tap a candidate"
/// only sometimes finishes that node — the recursion may need to
/// revisit the same node's remaining deficit across several more
/// levels before it's actually satisfied.
///
/// Same two techniques as `ClassicSolver`, adapted for a threshold
/// problem instead of a coverage problem: a tapped-set bitmask
/// (instead of a covered-set bitmask), and a per-vertex lower bound —
/// the single most-starved unsatisfied node needs at least
/// `ceil(itsDeficit / bestRemainingSingleContribution)` more taps on
/// its own, and sharing taps across nodes can only ever help *other*
/// nodes, never reduce what this one specifically needs — so the max
/// of that figure across all unsatisfied nodes is a safe floor on
/// taps still required. Benchmarked on random 20-34 node graphs, this
/// cut branch counts by roughly 5x; see
/// `test/engine/capacity_solver_test.dart`.
class CapacitySolver {
  CapacitySolver._();

  static const double _epsilon = 1e-9;

  /// Solves [graph] (build with [Graph.undirected]; nodes need
  /// `capacity`/`demand` set) for the true minimum tap count.
  ///
  /// Unlike Classic and Signal, this CAN be infeasible: a node whose
  /// demand exceeds what tapping itself and every neighbor could ever
  /// supply can never be satisfied, no matter what else is tapped.
  /// The level generator should treat [Infeasible] as "reject this
  /// level," not a bug to work around.
  static SolveResult solve(Graph graph) {
    graph.assertBitmaskCapacity();
    final n = graph.nodeCount;
    if (n == 0) {
      return const Solved(optimalTapCount: 0, optimalTaps: <String>{});
    }

    final cap = List<double>.generate(n, (i) => graph.nodeAt(i).capacity);
    final dem = List<double>.generate(n, (i) => graph.nodeAt(i).demand);
    final closedNbhd = List<List<int>>.generate(n, graph.closedNeighborhood);

    double supplyOf(int v, int tapped) {
      var s = (tapped >> v) & 1 == 1 ? cap[v] : 0.0;
      for (final u in graph.neighbors(v)) {
        if ((tapped >> u) & 1 == 1) s += 0.5 * cap[u];
      }
      return s;
    }

    bool isSatisfied(int v, int tapped) =>
        supplyOf(v, tapped) >= dem[v] - _epsilon;

    final greedy = _greedy(n, cap: cap, dem: dem, graph: graph);

    var best = n + 1; // sentinel: "no feasible solution found yet"
    var bestSet = greedy;
    if (greedy != null) best = greedy.length;

    final chosen = <int>[];

    void branch(int tapped) {
      if (chosen.length >= best) return;

      var lowerBound = 0;
      var mostConstrainedV = -1;
      var mostConstrainedCandidateCount = n + 1;

      for (var v = 0; v < n; v++) {
        if (isSatisfied(v, tapped)) continue;
        final deficit = dem[v] - supplyOf(v, tapped);

        var bestSingleContribution = 0.0;
        var candidateCount = 0;
        for (final u in closedNbhd[v]) {
          if ((tapped >> u) & 1 == 1) continue;
          candidateCount++;
          final contribution = u == v ? cap[u] : 0.5 * cap[u];
          if (contribution > bestSingleContribution) {
            bestSingleContribution = contribution;
          }
        }

        if (candidateCount == 0 || bestSingleContribution <= _epsilon) {
          return; // dead end: v can never be satisfied from here
        }

        final need = (deficit / bestSingleContribution).ceil();
        if (need > lowerBound) lowerBound = need;
        if (candidateCount < mostConstrainedCandidateCount) {
          mostConstrainedCandidateCount = candidateCount;
          mostConstrainedV = v;
        }
      }

      if (mostConstrainedV == -1) {
        // every node satisfied
        if (chosen.length < best) {
          best = chosen.length;
          bestSet = List<int>.from(chosen);
        }
        return;
      }

      if (chosen.length + lowerBound >= best) return;

      final candidates = [
        for (final u in closedNbhd[mostConstrainedV])
          if ((tapped >> u) & 1 == 0) u,
      ]..sort((a, b) {
          final ca = a == mostConstrainedV ? cap[a] : 0.5 * cap[a];
          final cb = b == mostConstrainedV ? cap[b] : 0.5 * cap[b];
          return cb.compareTo(ca);
        });

      for (final u in candidates) {
        chosen.add(u);
        branch(tapped | (1 << u));
        chosen.removeLast();
      }
    }

    branch(0);

    final finalSet = bestSet;
    if (finalSet == null) return const Infeasible();
    return Solved(
      optimalTapCount: best,
      optimalTaps: finalSet.map(graph.idAt).toSet(),
    );
  }

  /// Cheap pass/fail check for a player's tap set — O(V+E).
  static bool verify(Graph graph, Set<String> proposedTaps) {
    final n = graph.nodeCount;
    var tapped = 0;
    for (final id in proposedTaps) {
      tapped |= 1 << graph.indexOf(id);
    }
    for (var v = 0; v < n; v++) {
      final node = graph.nodeAt(v);
      var supply = (tapped >> v) & 1 == 1 ? node.capacity : 0.0;
      for (final u in graph.neighbors(v)) {
        if ((tapped >> u) & 1 == 1) supply += 0.5 * graph.nodeAt(u).capacity;
      }
      if (supply < node.demand - _epsilon) return false;
    }
    return true;
  }

  /// Any tap order eventually reaches "tap everyone" if nothing else
  /// works, and supply only ever goes up as more nodes are tapped —
  /// so a greedy pass either finds a valid (if not optimal) solution,
  /// or, if even tapping everyone can't satisfy every node, correctly
  /// signals infeasibility by returning null instead of guessing.
  static List<int>? _greedy(
    int n, {
    required List<double> cap,
    required List<double> dem,
    required Graph graph,
  }) {
    var tapped = 0;

    double supplyOf(int v) {
      var s = (tapped >> v) & 1 == 1 ? cap[v] : 0.0;
      for (final u in graph.neighbors(v)) {
        if ((tapped >> u) & 1 == 1) s += 0.5 * cap[u];
      }
      return s;
    }

    bool allSatisfied() {
      for (var v = 0; v < n; v++) {
        if (supplyOf(v) < dem[v] - _epsilon) return false;
      }
      return true;
    }

    final chosen = <int>[];
    for (var step = 0; step < n; step++) {
      if (allSatisfied()) return chosen;

      var bestU = -1;
      var bestGain = -1.0;
      for (var u = 0; u < n; u++) {
        if ((tapped >> u) & 1 == 1) continue;
        var gain = 0.0;
        final deficitSelf = dem[u] - supplyOf(u);
        if (deficitSelf > 0) gain += math.min(cap[u], deficitSelf);
        for (final w in graph.neighbors(u)) {
          final deficitW = dem[w] - supplyOf(w);
          if (deficitW > 0) gain += math.min(0.5 * cap[u], deficitW);
        }
        if (gain > bestGain) {
          bestGain = gain;
          bestU = u;
        }
      }
      chosen.add(bestU);
      tapped |= 1 << bestU;
    }
    return allSatisfied() ? chosen : null;
  }
}
