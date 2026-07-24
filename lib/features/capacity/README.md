# features/capacity

Capacity mode gameplay — weighted/capacitated dominating set with 50%
one-hop spillover. `total_supply(v) = cap(v)*tapped(v) + 0.5 *
sum(cap(u) for tapped neighbors u)`; win when every node's supply
meets its demand.

## Phase 4 — reusing Phase 3, not reimplementing it

Nothing in this folder reimplements win-check, star outcomes, retry,
the timer, or coin awarding — `capacity_gameplay_screen.dart` uses
`GameplayController` (`lib/features/shared/`) completely unmodified.
`isFullySatisfied` already dispatches to `CapacitySolver.verify()` via
the engine's own `verifyWin(graph, mode, taps)`, because a Capacity
`Level`'s `mode` is `GameMode.capacity` — that generic dispatch was
built once in Phase 3 and needed zero changes here.

What's actually new:

- `capacity_supply.dart` — pure `capacitySupplyOf()`, the exact Master
  Context formula per node. `CapacitySolver.verify()` only returns
  pass/fail for the whole graph; the live gauge and the hint engine
  both need the actual number, so it's computed here once and shared
  rather than duplicated between them. Cross-checked against
  `CapacitySolver.verify()` in its test file.
- `capacity_hint_engine.dart` — pure, two-part hint: the most
  under-supplied node right now, and separately, whichever untapped
  optimal node contributes the most toward THAT node's deficit
  specifically (not just "most capacity" — see the test file's
  distractor case, where a huge-capacity candidate correctly loses to
  a smaller one that's actually relevant).
- `capacity_node_gauge.dart` — the fill-ring gauge (Phase 4 item 1),
  wrapping the shared `ConvoyNodeGlyph` (extracted from `ConvoyNode`
  in Phase 4 specifically so this didn't have to duplicate the ring/
  fill/icon rendering).
- `capacity_gameplay_screen.dart` — node/pipe visual-state computation
  (supply vs. demand, not coverage), the spillover pipe visualization,
  and the two-ring pulsing hint decoration. Follows
  `classic_gameplay_screen.dart`'s structure closely on purpose.
- `capacity_level_select_screen.dart` — now a thin wrapper around
  `lib/features/shared/level_select_screen.dart`, factored out of
  Phase 3's Classic-only version once this needed the identical
  structure a second time.

## Design system changes this phase needed

- `ConvoyNode` split into `ConvoyNodeGlyph` (just the ring/fill/icon)
  + `ConvoyNode` (glyph + label), so Capacity's gauge could wrap the
  glyph in its own ring without duplicating it. `ConvoyNode`'s own
  public API is unchanged.
- `PipeState` gained a fourth value, `spillover` — dimmer, thinner
  than `active`. Every cross-node contribution in Capacity IS the
  0.5x spillover mechanic by definition, so Capacity pipes never use
  `active` at all; that state stays Classic's, where a pipe really
  does carry full-strength coverage.

## Legibility

This is the densest mode of the three — two numbers per node (supply,
demand), the spillover animation, and the timer UI all at once. The
gauge is deliberately layered rather than crammed into one glyph: the
RING is the glance-distance signal (how full, what color — red under,
amber satisfied, extra glow past ~115%), the TEXT underneath is the
close-up signal (exact numbers). See `style_guide_screen.dart`'s
"CAPACITY GAUGE" section for the fill-level progression on its own,
without needing to be mid-level to check it.

**This has not been visually verified on an actual device** — see the
top-level README's Phase 4 verification checklist. Nothing here can
substitute for the real "does this overlap, is this truncated, can I
tell red from amber at a glance" check the brief asks for.

## Testing it

`dart test test/features/capacity` for the pure pieces
(`capacity_supply.dart`, `capacity_hint_engine.dart`). The gauge
widget's animations, the pulsing hint rings, and the actual on-screen
density all need a running app — no way around that, same situation
Phase 3 was in.
