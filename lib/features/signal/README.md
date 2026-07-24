# features/signal

Signal mode gameplay — Structural Controllability on a directed graph.
Bipartite max matching (Kuhn's algorithm) finds the minimum driver
node set; win when every node is reachable from it.

## Phase 5 — reusing Phase 3, not reimplementing it (same rule as Phase 4)

Nothing here reimplements win-check, star outcomes, retry, the timer,
or coin awarding — `signal_gameplay_screen.dart` uses
`GameplayController` completely unmodified. `isFullySatisfied` already
dispatches to `signal_solver.dart`'s `verify()` (reachability from the
selected driver set) via the engine's own
`verifyWin(graph, mode, taps)`, because a Signal `Level`'s `mode` is
`GameMode.signal` — same generic dispatch Capacity used in Phase 4,
unchanged again here.

What's actually new:

- `signal_reachability.dart` — pure `signalReachableFrom()`, plain
  forward BFS/DFS from the driver set. `verifyWin` only returns
  pass/fail for the whole graph; the live per-node visualization
  (driver / controlled / uncontrolled) and the hint engine both need
  the actual reached set, so it's computed once here and shared,
  same reasoning as `capacity_supply.dart` in Phase 4.
- `signal_hint_engine.dart` — pure hint selection: among untapped
  nodes in the level's precomputed driver set
  (`Level.exampleSolution`), prioritizes whichever reaches the most
  currently-unreached ground — same "most new X" shape as
  `classic_hint_engine.dart`, with reachability standing in for
  closed-neighborhood coverage.
- `signal_gameplay_screen.dart` — turned out closer to
  `classic_gameplay_screen.dart` than
  `capacity_gameplay_screen.dart` structurally: a single hint
  highlight (reuses `LevelGraphView`'s existing `highlightedNodeId`,
  no custom `nodeBuilder` needed) and the standard tapped/supplied/
  decaying node mapping, rather than Capacity's two-ring gauge
  treatment. Also has the density "aha" callout (Phase 5 item 4) — a
  dismissible inline banner, shown specifically on levels whose id
  matches Phase 2's `_teach_dense` convention, not a modal.
- `signal_level_select_screen.dart` — thin wrapper around
  `lib/features/shared/level_select_screen.dart`, same pattern as
  Classic/Capacity. 15 slots, not 12 — Signal's curated set includes
  the teaching pairs.

## Design system changes this phase needed

- `ConvoyPipe` gained a `directed` parameter (Phase 5 item 1):
  arrowheads drawn along the curve's own tangent at the endpoint (not
  a straight line from start to end — see that file's doc comment for
  why the distinction matters once a pipe has any real curvature),
  pulled back from the node center so the node glyph painted on top
  doesn't bury the arrowhead. Wired automatically in
  `level_graph_view.dart` from `Level.directed` — Signal didn't need
  a new LevelGraphView parameter for this, since directedness is
  already data the level carries.
- `LevelGraphView` gained an auto-fit-to-viewport pass on first layout
  (Phase 5 item 6) — Signal's 30-40+ node levels would otherwise
  render at a flat starting scale that shows only a small corner of
  the canvas on a phone screen. See that file's
  `_fitToViewportIfNeeded` doc comment. This is shared infrastructure,
  not Signal-specific, but Signal is the mode that actually needed it.

## Directed pipe states are simpler than Classic/Capacity's

`_pipeStates()` only ever produces `active` (source node is under
control) or `inactive` — never `decaying`. An undirected pipe in
Classic/Capacity can touch an unsupplied node and read as a problem;
a directed edge's source being reachable automatically means its
destination is too (that's what forward reachability means), so
there's no "half-broken" case for a Signal edge the way there is for
an undirected one. See `signal_gameplay_screen.dart`'s `_pipeStates`
doc comment.

## Testing it

`dart test test/features/signal` for the pure pieces
(`signal_reachability.dart`, `signal_hint_engine.dart`). The arrowhead
rendering, the auto-fit behavior at real 30-40 node scale, and the
density callout's actual legibility all need a running app — no way
around that, same situation Phase 3/4 were in. The auto-fit especially
is worth real device time: the math was checked by hand (see
`level_graph_view.dart`'s doc comment), not by looking at a screen.
