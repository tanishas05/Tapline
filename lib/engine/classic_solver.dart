import 'graph.dart';
import 'solve_result.dart';

/// Exact Minimum Dominating Set solver for Classic mode.
///
/// [solve] always finds the TRUE minimum, never an approximation —
/// star ratings are computed against this value, so an approximate
/// solver would silently break scoring.
///
/// Two independent techniques keep this fast enough for the 8-40 node
/// levels Classic uses:
///
/// - Closed neighborhoods are packed into bitmasks, so "does this tap
///   set cover this node" is one bitwise AND instead of a set
///   intersection.
/// - Branches are cut using a REMAINING-WORK lower bound — at least
///   `ceil(uncovered / maxSingleTapCoverage)` more taps are always
///   needed — not just a running tap count.
///
/// That second point turned out to matter far more than the greedy
/// seed the Master Context asks for. Benchmarked against a 6x6 grid
/// graph (36 nodes, a structured, harder-than-typical case): greedy
/// seeding alone explored ~492,000 branch calls; adding the lower
/// bound cut that to ~4,300 — roughly two orders of magnitude — while
/// greedy seeding by itself measured within noise of doing nothing on
/// the same graph and across a 45-graph random sweep, because this
/// solver's own branch order (most-covering candidate first) already
/// behaves like a greedy construction on its very first attempt, so a
/// separately-computed greedy bound rarely beats what the search
/// finds on its own almost immediately anyway. The greedy seed is
/// still computed and used — it's cheap, never wrong to have, and the
/// Master Context asks for it — it just isn't the lever that matters.
/// See `test/engine/classic_solver_test.dart` for the benchmark this
/// is based on.
class ClassicSolver {
  ClassicSolver._();

  /// Solves [graph] (build with [Graph.undirected]) for its true
  /// minimum dominating set. Always feasible — tapping every node
  /// always covers every node — so this never needs [Infeasible].
  static Solved solve(Graph graph) {
    graph.assertBitmaskCapacity();
    final n = graph.nodeCount;
    if (n == 0) {
      return const Solved(optimalTapCount: 0, optimalTaps: <String>{});
    }

    final closedMask = List<int>.generate(n, graph.closedNeighborhoodMask);
    final full = (1 << n) - 1;

    final greedy = _greedy(n, closedMask, full);
    var best = greedy.length;
    var bestSet = greedy;

    final chosen = <int>[];

    void branch(int covered) {
      if (chosen.length >= best) return;
      if (covered == full) {
        if (chosen.length < best) {
          best = chosen.length;
          bestSet = List<int>.from(chosen);
        }
        return;
      }

      // Admissible lower bound: no single tap covers more than
      // `maxCover` of what's still uncovered, so at least
      // ceil(remaining / maxCover) more taps are unavoidable from
      // here — safe to prune on, since it can never overestimate the
      // true remaining work.
      final remaining = full & ~covered;
      var maxCover = 1;
      for (var u = 0; u < n; u++) {
        final cover = _popcount(closedMask[u] & remaining);
        if (cover > maxCover) maxCover = cover;
      }
      final remainingCount = _popcount(remaining);
      final lowerBound = (remainingCount + maxCover - 1) ~/ maxCover;
      if (chosen.length + lowerBound >= best) return;

      final v = _mostConstrainedUncovered(n, closedMask, covered);
      final candidates = _bitsOf(closedMask[v], n)
        ..sort((a, b) => _popcount(closedMask[b] & ~covered)
            .compareTo(_popcount(closedMask[a] & ~covered)));

      for (final u in candidates) {
        chosen.add(u);
        branch(covered | closedMask[u]);
        chosen.removeLast();
      }
    }

    branch(0);

    return Solved(
      optimalTapCount: best,
      optimalTaps: bestSet.map(graph.idAt).toSet(),
    );
  }

  /// Cheap pass/fail check for a player's tap set — O(V+E), meant to
  /// run at play time, unlike [solve] which only ever runs offline.
  static bool verify(Graph graph, Set<String> proposedTaps) {
    final n = graph.nodeCount;
    final covered = List<bool>.filled(n, false);
    for (final id in proposedTaps) {
      final index = graph.indexOf(id);
      covered[index] = true;
      for (final neighbor in graph.neighbors(index)) {
        covered[neighbor] = true;
      }
    }
    return covered.every((isCovered) => isCovered);
  }

  static List<int> _greedy(int n, List<int> closedMask, int full) {
    var covered = 0;
    final chosen = <int>[];
    while (covered != full) {
      var bestU = -1;
      var bestGain = -1;
      for (var u = 0; u < n; u++) {
        final gain = _popcount(closedMask[u] & ~covered);
        if (gain > bestGain) {
          bestGain = gain;
          bestU = u;
        }
      }
      chosen.add(bestU);
      covered |= closedMask[bestU];
    }
    return chosen;
  }

  static int _mostConstrainedUncovered(
    int n,
    List<int> closedMask,
    int covered,
  ) {
    var bestV = -1;
    var bestSize = n + 1;
    for (var v = 0; v < n; v++) {
      if ((covered >> v) & 1 == 1) continue;
      final size = _popcount(closedMask[v]);
      if (size < bestSize) {
        bestSize = size;
        bestV = v;
      }
    }
    return bestV;
  }

  static List<int> _bitsOf(int mask, int n) {
    final result = <int>[];
    for (var i = 0; i < n; i++) {
      if ((mask >> i) & 1 == 1) result.add(i);
    }
    return result;
  }

  static int _popcount(int x) {
    var count = 0;
    while (x != 0) {
      x &= x - 1;
      count++;
    }
    return count;
  }
}
