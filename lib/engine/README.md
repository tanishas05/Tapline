# engine

Pure Dart graph engine — models and solvers for all three modes. Zero
Flutter imports anywhere in this folder; test it with `dart test
test/engine`, no widget harness, no emulator.

```
graph.dart            GraphPoint, GraphNode, GraphEdge, Graph
solve_result.dart      SolveResult / Solved / Infeasible
classic_solver.dart    exact Minimum Dominating Set (bitmask B&B)
capacity_solver.dart   exact weighted dominating set w/ spillover
signal_solver.dart     structural controllability (Kuhn's matching)
solvability.dart       GameMode + checkSolvability() + verifyWin()
engine.dart            barrel export
```

## Two places this goes beyond a literal reading of the brief

**Classic and Capacity both got a lower-bound prune the brief didn't
ask for.** The brief's pruning was "stop once the partial solution
already matches the best complete one found" plus a greedy seed.
Benchmarked on a 6x6 grid graph (36 nodes — a harder, more structured
case than typical hand-built levels), greedy seeding alone explored
~492,000 branch calls; adding a *remaining-work* lower bound — at
least `ceil(uncovered / maxSingleTapCoverage)` more taps are always
needed, not just "however many we've used so far" — cut that to
~4,300. Across a 45-graph random sweep, greedy seeding by itself
measured within noise of doing nothing, because both solvers' own
branch order already behaves like a greedy construction on the first
attempt, making a separately-computed greedy bound mostly redundant.
The greedy seed is still there — cheap, never wrong to keep, and
explicitly requested — it just isn't the lever that matters. Capacity
got the analogous per-vertex version: the single most-starved
unsatisfied node needs at least `ceil(itsDeficit /
bestRemainingSingleContribution)` more taps on its own, and sharing
taps across nodes only ever helps *other* nodes, never this one — so
the max of that across all unsatisfied nodes is a safe floor. Full
numbers are in each solver's doc comment and in the benchmark tests.

**Signal's driver-selection got a fix for perfectly-matched
components.** The brief says "nodes in V_in left unmatched are the
required driver nodes," full stop. Taken completely literally, a
directed cycle (or a union of them) — every node matched, zero
unmatched V_in nodes — reports **zero** drivers. Reachability from an
empty set is empty, so a level like that could never actually be won,
which contradicts the mode's own win condition. This is a known gap in
that simplified phrasing, not a new problem: the original
Liu-Slotine-Barabási paper's actual result is `max(N - |M|, 1)`
drivers *per structural component*, and the "1" is exactly for this
case. The fix: after collecting the unmatched-V_in drivers, check
reachability, and if anything's still unreached (which can only happen
inside a perfectly-matched cycle), add one more driver from it and
recheck — repeat per disconnected cycle. `signal_solver_test.dart` has
a pure-3-cycle case (needs 1 driver, not 0) and a two-disjoint-cycles
case (needs 2) demonstrating this concretely, plus a case showing the
"denser graphs can need fewer drivers" phenomenon still holds with the
fix in place.

## On the performance numbers specifically

I don't have Dart installed in the sandbox I write code in, so
everything above was algorithmically verified in a Python port first
(same test cases, same graphs) and only then translated to Dart by
hand — see the "Verification" note in the top-level README for what
that did and didn't cover. Call-count reductions (492,000 → 4,300) are
a property of the search tree shape, not the language, so those should
carry over. Wall-clock numbers won't — Dart's native 64-bit ints and
compiled execution should make the bitmask approach look better
relative to a set-based one than it did in Python, where the opposite
showed up in my prototype (boxed-int overhead in CPython cutting the
other way). `classic_solver_test.dart` and `capacity_solver_test.dart`
both have benchmark tests that log real timing — run those on your
machine for real numbers before trusting anything above as more than
"the search tree is smaller, which can only help."

## Solvability

`checkSolvability(graph, mode)` is the Phase 2 entry point — solves
for the given mode and returns `Solved` (with the exact optimum + one
optimal tap set, for star thresholds) or `Infeasible`. Classic and
Signal can't be infeasible by construction; only Capacity can, when a
node's demand exceeds what tapping it and every neighbor could ever
supply. `verifyWin(graph, mode, proposedTaps)` is the cheap O(V+E)
runtime check for actual play — never re-solves.
