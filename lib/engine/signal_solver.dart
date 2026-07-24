import 'graph.dart';
import 'solve_result.dart';

/// Structural controllability solver for Signal mode (Liu-Slotine-
/// Barabási), using Kuhn's algorithm for maximum bipartite matching.
///
/// One addition beyond a literal "unmatched V_in nodes are the driver
/// set" reading: a graph where every node ends up matched — a perfect
/// matching, which happens for any directed cycle, or a union of
/// them — would otherwise report ZERO driver nodes. Reachability from
/// an empty set is empty, so that result could never actually win,
/// contradicting the mode's own win condition. This is the textbook
/// `max(N - |M|, 1)`-per-component refinement from the original LSB
/// paper: after the unmatched-V_in drivers are collected, any node
/// still unreached (which can only happen inside a perfectly-matched
/// component) needs an additional driver.
///
/// That refinement step used to just walk unreached nodes in index
/// order, adding whichever came first as the next driver. That's
/// wrong when multiple perfectly-matched components are chained
/// together by a one-way edge: picking a "downstream" component first
/// wastes a driver, since a downstream component can't reach back to
/// an "upstream" one that would have covered it for free. Concretely:
/// two 2-node cycles 0<->1 and 2<->3 joined by a single edge 3->0 —
/// index order picks 0 first, which only reaches {0,1}, so a second
/// driver ends up needed for {2,3} too (total 2), when picking
/// anywhere in {2,3} alone reaches all four nodes via 2->3->0->1
/// (total 1). Fixed by treating the unreached region as what it
/// actually is — a small DAG of components, via
/// [_sourceDriversForResidual] — rather than an unordered pile of
/// individual nodes. See `test/engine/signal_solver_test.dart` for
/// that exact case as a regression test, alongside a pure-cycle case
/// showing the original zero-drivers problem this whole mechanism
/// exists for, and a case showing the "denser can need fewer drivers"
/// phenomenon this preserves rather than breaks.
class SignalSolver {
  SignalSolver._();

  /// Solves [graph] (build with [Graph.directed]) for the minimum
  /// driver set. Always feasible by construction — see the class doc
  /// comment above — so this never needs [Infeasible].
  static Solved solve(Graph graph) {
    final n = graph.nodeCount;
    if (n == 0) {
      return const Solved(optimalTapCount: 0, optimalTaps: <String>{});
    }

    // matchToIn[j] = which V_out node is currently matched to V_in
    // node j, or -1 if j is unmatched. graph.neighbors(u) already IS
    // the bipartite adjacency: j in graph.neighbors(u) iff the
    // directed edge u -> j exists, which is exactly the bipartite
    // edge (V_out u -- V_in j) the Master Context describes.
    final matchToIn = List<int>.filled(n, -1);

    bool tryAugment(int u, List<bool> visited) {
      for (final j in graph.neighbors(u)) {
        if (visited[j]) continue;
        visited[j] = true;
        if (matchToIn[j] == -1 || tryAugment(matchToIn[j], visited)) {
          matchToIn[j] = u;
          return true;
        }
      }
      return false;
    }

    for (var u = 0; u < n; u++) {
      tryAugment(u, List<bool>.filled(n, false));
    }

    final drivers = <int>{
      for (var j = 0; j < n; j++)
        if (matchToIn[j] == -1) j,
    };

    final reached = _forwardReachable(graph, drivers);
    if (reached.length < n) {
      final unreached = <int>{
        for (var v = 0; v < n; v++)
          if (!reached.contains(v)) v,
      };
      drivers.addAll(_sourceDriversForResidual(graph, unreached));
    }

    assert(
      _forwardReachable(graph, drivers).length == n,
      'SignalSolver internal error: drivers do not reach every node',
    );

    return Solved(
      optimalTapCount: drivers.length,
      optimalTaps: drivers.map(graph.idAt).toSet(),
    );
  }

  /// The remaining half of the perfectly-matched-component refinement
  /// described in the class doc comment: given the nodes still
  /// unreached after the initial unmatched-V_in drivers, adds exactly
  /// one driver per "source" component — one with no incoming edge
  /// from another still-unreached component. That's both necessary (a
  /// source can't be reached any other way) and sufficient (every
  /// node in a DAG is reachable from some source) for full coverage
  /// at the minimum possible count — no iteration needed, unlike the
  /// old index-order loop: one pass always finds every driver this
  /// step will ever need.
  ///
  /// Implementation: Kosaraju's SCC algorithm restricted to the
  /// induced subgraph on [unreached] — edges to/from already-reached
  /// nodes are irrelevant here. They can't matter: every unreached
  /// node's matched predecessor is itself unreached (if it weren't,
  /// the edge from it would already have reached this node), so
  /// nothing reached ever points back into the unreached region.
  static Set<int> _sourceDriversForResidual(Graph graph, Set<int> unreached) {
    final n = graph.nodeCount;

    // Pass 1: DFS over the induced subgraph, recording finish order.
    final finishOrder = <int>[];
    final visited = List<bool>.filled(n, false);
    void dfsForward(int u) {
      visited[u] = true;
      for (final v in graph.neighbors(u)) {
        if (unreached.contains(v) && !visited[v]) dfsForward(v);
      }
      finishOrder.add(u);
    }

    for (final u in unreached) {
      if (!visited[u]) dfsForward(u);
    }

    // Pass 2: DFS over the transpose, in reverse finish order, to
    // assign each node a component id — standard Kosaraju's.
    final reverseAdjacency = <int, List<int>>{};
    for (final u in unreached) {
      for (final v in graph.neighbors(u)) {
        if (unreached.contains(v)) {
          (reverseAdjacency[v] ??= <int>[]).add(u);
        }
      }
    }

    final sccId = List<int>.filled(n, -1);
    var sccCount = 0;
    void dfsReverse(int u, int id) {
      sccId[u] = id;
      for (final w in reverseAdjacency[u] ?? const <int>[]) {
        if (sccId[w] == -1) dfsReverse(w, id);
      }
    }

    for (final u in finishOrder.reversed) {
      if (sccId[u] == -1) {
        dfsReverse(u, sccCount);
        sccCount++;
      }
    }

    // A component is a "source" if no edge enters it from a
    // different component still in `unreached`.
    final hasExternalIncoming = List<bool>.filled(sccCount, false);
    for (final u in unreached) {
      for (final v in graph.neighbors(u)) {
        if (unreached.contains(v) && sccId[u] != sccId[v]) {
          hasExternalIncoming[sccId[v]] = true;
        }
      }
    }

    // One representative node per source component — which node
    // within it doesn't matter, since every node in a component can
    // reach every other node in it by definition of "strongly
    // connected."
    final representative = List<int>.filled(sccCount, -1);
    for (final u in unreached) {
      if (representative[sccId[u]] == -1) representative[sccId[u]] = u;
    }

    return {
      for (var id = 0; id < sccCount; id++)
        if (!hasExternalIncoming[id]) representative[id],
    };
  }

  /// Cheap pass/fail check — pure forward reachability, O(V+E).
  static bool verify(Graph graph, Set<String> proposedTaps) {
    final sources = proposedTaps.map(graph.indexOf).toSet();
    return _forwardReachable(graph, sources).length == graph.nodeCount;
  }

  static Set<int> _forwardReachable(Graph graph, Set<int> sources) {
    final seen = Set<int>.of(sources);
    final stack = List<int>.of(sources);
    while (stack.isNotEmpty) {
      final u = stack.removeLast();
      for (final v in graph.neighbors(u)) {
        if (seen.add(v)) stack.add(v);
      }
    }
    return seen;
  }
}
