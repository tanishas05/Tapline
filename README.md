# Convoy — Phase 0 through Phase 5

Phase 0: architecture and visual identity. Phase 1: the pure-Dart
graph engine. Phase 2: the level data pipeline. Phase 3: Classic, the
first fully playable mode, plus the shared gameplay controller. Phase
4: Capacity, built on Phase 3's shared pieces with zero controller
changes. Phase 5: Signal — same reuse rule again, plus two new pieces
of shared infrastructure (directed pipes, large-graph auto-fit) that
Signal needed and the other two modes get for free.

**All three modes are now playable.**

## What's here

```
lib/
  main.dart / app.dart         entry point, MaterialApp, theme, routes
  design_system/
    convoy_pipe.dart           curved bezier connector — 4 PipeStates,
                                plus Phase 5's `directed` arrowhead
                                rendering (wired automatically from
                                Level.directed, not a new per-call param)
    convoy_node.dart           ConvoyNodeGlyph (ring/fill/icon) +
                                ConvoyNode (glyph + label) — unchanged
                                since Phase 4
    mode_panel.dart / blueprint_grid.dart / design_system.dart
  features/
    shared/
      hub_screen.dart          all three modes route to real gameplay now
      style_guide_screen.dart  dev reference incl. CAPACITY GAUGE and
                                SIGNAL DIRECTED PIPE sections
      gameplay_controller.dart      Phase 3 — unmodified since. Every
                                     mode's isFullySatisfied comes from
                                     verifyWin(graph, mode, taps)
      outcome_logic.dart            Phase 3 — unmodified since
      level_graph_view.dart         Phase 3, extended Phase 4 (nodeBuilder
                                     override) and Phase 5 (directed pipes,
                                     auto-fit-to-viewport for large graphs)
      level_select_screen.dart      Phase 4 — shared by all three tracks
      coin_economy.dart             Phase 3 — unmodified since
      coming_soon_screen.dart       unused as of Phase 5 (all three modes
                                     have real destinations) — left in
                                     place, just unimported
    classic/     Phase 3 — gameplay screen, level select, hint engine
    capacity/    Phase 4 — gameplay screen, level select, hint engine,
                 supply math, the fill-ring gauge
    signal/      Phase 5 — gameplay screen, level select, hint engine,
                 reachability math
  engine/                      pure Dart, zero Flutter — lib/engine/README.md
  data/                        see lib/data/README.md
  generation/                  pure Dart, zero Flutter — lib/generation/README.md
assets/levels/                 curated level JSON + manifest.json (Phase 2)
tool/generate_levels.dart      offline curated-content CLI (Phase 2)
test/
  widget_test.dart             smoke test for the hub + navigation
  engine/  generation/  data/  dart-test-only
  features/
    shared/outcome_logic_test.dart
    classic/classic_hint_engine_test.dart
    capacity/capacity_supply_test.dart, capacity_hint_engine_test.dart
    signal/signal_reachability_test.dart, signal_hint_engine_test.dart
```

## Getting it running

Same situation as every prior phase: no Flutter SDK in the sandbox
this was built in, so none of this has been run. Replace `lib/`,
`test/`, and `pubspec.yaml` with the versions here and
`flutter pub get`. No new dependencies this phase.

## Verify against your checks

- [ ] **The density "aha" reads clearly** — play a level whose id
      contains `_teach_dense` (any tier's teaching-pair level, see
      `tool/generate_levels.dart`) and confirm the dismissible cyan
      callout appears, and that the level genuinely does need fewer
      drivers than its `_teach_sparse` counterpart at the same tier
      (same node count). Phase 2's generator already proves the
      underlying math at the data level (`generateTeachingPair`'s own
      tests); this check is about whether it also *reads* clearly in
      the running UI, which is a different question.
- [ ] **30-40 node levels stay readable** — open a `large`-tier Signal
      level (or the `_teach_dense` large one specifically) and confirm
      the graph doesn't open zoomed into one corner. It should
      auto-fit to roughly the whole viewport on first open — see
      `level_graph_view.dart`'s `_fitToViewportIfNeeded` doc comment
      for the exact mechanism, and note the explicit caveat there:
      **this was verified by hand-checking the arithmetic, not by
      looking at a screen.** If it opens zoomed wrong, that's the
      first place to look. Also confirm the timer/taps HUD text stays
      legible at that scale — it's a fixed-size overlay independent of
      canvas zoom, so it should be, but is worth eyes-on given how
      dense a 40-node graph gets.
- [ ] **Arrows are unambiguous** — every Signal pipe should show a
      clear directional arrowhead, pointing the right way, not hidden
      under the destination node. Compare against a Classic level
      side-by-side — Signal should read as visually distinct at a
      glance, per the brief's explicit ask.
- [ ] **All four outcomes, via the shared controller** — same list as
      Phase 3/4. `tapsUsed` here counts selected drivers, compared
      against `optimum` (minimum driver count) the same way tap counts
      work in the other two modes.
- [ ] **`dart test test/features/signal`** — the two pure pieces this
      phase added.

## Notes on a few choices

- **Signal's pipe states are simpler than Classic/Capacity's** — only
  `active`/`inactive`, no `decaying`. A directed edge's source being
  reachable automatically means its destination is too (that's what
  forward reachability means), so there's no "half-broken" case the
  way an undirected pipe touching an unsupplied node has one. See
  `signal_gameplay_screen.dart`'s `_pipeStates` doc comment.
- **Arrowheads point along the curve's own tangent, not a straight
  line to the node** — a pipe with any real curvature would visibly
  disagree with a naively-straight arrowhead. The bezier math for this
  is spelled out in `convoy_pipe.dart`'s doc comments; worth reading
  before touching that file again given how easy the geometry is to
  get subtly wrong.
- **The density callout triggers off a level id convention
  (`_teach_dense`), not a dynamic recomputation** — the alternative
  (comparing against "what a sparser version would have needed") isn't
  answerable from data a `Level` actually carries (chain structure
  isn't stored, only the final nodes/edges/optimum), so this leans on
  Phase 2's own generator convention instead. Documented in
  `signal_gameplay_screen.dart`.
- **`LevelGraphView`'s auto-fit only ever zooms OUT, never in** — a
  small Classic/Capacity level at typical size renders exactly as it
  did in Phase 3/4; the fit logic only engages once a canvas is
  actually bigger than the viewport, which in practice is a
  Signal-only situation given the other two modes' node-count ranges.
- **`ComingSoonScreen` is dead code as of this phase** — nothing
  imports it anymore now that all three modes have real destinations.
  Left the file in place rather than deleting it; it's harmless
  unimported, and might be useful again for a hypothetical future mode.

## Phase 5 — Signal, reusing Phase 3 again

Same reuse rule as Phase 4: nothing here reimplements win-check, star
outcomes, retry, the timer, or coin awarding.
`GameplayController`/`outcome_logic.dart` are byte-for-byte unchanged
from Phase 3 — `isFullySatisfied` dispatches to `signal_solver.dart`'s
`verify()` via the same generic `verifyWin(graph, mode, taps)` Capacity
used. What Signal actually needed: reachability math
(`signal_reachability.dart`), a hint engine prioritizing by new
reachable ground (`signal_hint_engine.dart`), the density callout, and
two pieces of SHARED infrastructure that happened to only be
Signal-relevant in practice: directed pipe arrows and large-graph
auto-fit, both in `level_graph_view.dart`/`convoy_pipe.dart` rather
than Signal-specific files, since neither is conceptually tied to
Signal — a future mode with directed edges or big levels gets both for
free.

**Testing it:** `dart test test/features/signal` for the pure pieces.
The arrowhead rendering, the auto-fit at real 30-40 node scale, and
the density callout's actual legibility all need a running app — no
dart-test substitute for "does this look right," and the auto-fit
specifically is the piece of this phase with the least amount of
hands-on verification behind it (checked by arithmetic, not a screen).

## Phase 4 — Capacity

`lib/features/capacity/` — full writeup in that folder's README.
**Testing it:** `dart test test/features/capacity`.

## Phase 3 — the first fully playable mode

`lib/features/shared/` was built mode-agnostic from the start —
Phase 4 and Phase 5 are both proof that paid off; neither needed
`GameplayController` touched.
**Testing it:** `dart test test/features/shared test/features/classic
test/data/slot_progress_test.dart`.

## Phase 1 & 2 — engine and data pipeline

`lib/engine/README.md`, `lib/generation/README.md`.
**Testing it:** `dart test test/engine`, `dart test test/generation`,
`dart test test/data/level_manifest_test.dart test/data/level_schema_test.dart`.

## Coming up

All three modes are playable. Natural next steps from here: real
save/progress UI polish (star totals per track unlocking cosmetics,
per the Master Context's meta-progression layer — not built yet, only
per-slot progress is), Phase 6's real coin-economy tuning (every
number in `coin_economy.dart` is still a placeholder), and replacing
the placeholder mode icons with real tank/gauge/beacon glyphs.
