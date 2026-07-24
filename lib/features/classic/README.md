# features/classic

Classic mode gameplay — Minimum Dominating Set on an undirected graph.
Tap a node to supply it and its one-hop neighbors; win when every node
is supplied.

## Phase 3 — the first fully playable mode

- `classic_gameplay_screen.dart` — wires everything together: renders
  the level via `LevelGraphView` (shared), owns a `GameplayController`
  (shared) for tap/timer/outcome bookkeeping, computes Classic's own
  node/pipe visual states (coverage via `Graph.closedNeighborhood`),
  and handles all four outcomes (3-star, 2-star, fail-taps, fail-time)
  with the dialogs/choices the Master Context specifies.
- `classic_level_select_screen.dart` — the 12 curated slots (5 small +
  4 medium + 3 large), each showing lock state and best recorded
  outcome. See its own doc comment for exactly what "12 slots" means
  as a Phase 3 scoping choice, not a permanent ceiling.
- `classic_hint_engine.dart` — pure, `dart test`-verifiable hint
  selection: among untapped optimal-solution nodes, the one covering
  the most currently-uncovered nodes.

## What's shared vs. Classic-specific

Shared (`lib/features/shared/`), built generically so Capacity/Signal
reuse them directly:
- `gameplay_controller.dart` — tap state, countdown timer, the win
  outcome state machine. Mode-agnostic via the engine's own
  `verifyWin(graph, mode, taps)` dispatcher, not a Classic-specific
  check.
- `level_graph_view.dart` — renders any level's nodes/pipes from its
  stored layout; takes pre-computed visual states as input rather
  than deciding what "supplied" means itself.
- `outcome_logic.dart` — the pure win-check function
  `gameplay_controller.dart` calls. Has its own doc comment on a
  genuine gap in the Master Context's WIN CHECK table (a satisfied-but
  -over-tapped state the table doesn't assign an outcome to) and how
  it's resolved.
- `coin_economy.dart` — placeholder tier-based coin tables, same
  "clearly provisional" spirit as Phase 2's `difficulty_tiers.dart`
  time limits.

Classic-specific, because they aren't the same computation per mode
even though they're conceptually parallel: hint selection (coverage
vs. Capacity's demand contribution vs. Signal's reachability) and the
node/pipe visual-state computation (coverage vs. supply threshold vs.
driver reachability).

## Persistence

`lib/data/progress_store.dart` (coin balance, per-slot best outcome)
is new in Phase 3 — local-only via `shared_preferences`, per the
Master Context. `lib/data/slot_progress.dart` has the pure data model
and the unlock-sequencing logic, split out the same way
`level_manifest.dart` was split from `level_loader.dart` in Phase 2,
so it's testable under plain `dart test`.

## Testing it

`dart test test/features/shared test/features/classic` for the pure
pieces (`outcome_logic.dart`, `classic_hint_engine.dart`,
`slot_progress.dart`). The screens themselves, `GameplayController`'s
`Timer`-driven behavior, and `ProgressStore`'s actual persistence all
need a running app or `flutter test` — see the top-level README's
Phase 3 section for what that leaves genuinely unverified here.
