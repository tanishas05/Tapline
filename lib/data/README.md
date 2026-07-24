# data

Level JSON loading, plus (still to come) save/progress persistence —
star totals per track, unlocked cosmetics, coin balance (Master
Context: local/on-device storage only, no backend).

## Phase 2 — level loading (done)

- `level_schema.dart` — `Level` (the JSON envelope) and
  `DifficultyTier`. Reuses `lib/engine/`'s `GraphNode`/`GraphEdge`
  directly rather than parallel data classes — a `Level` *is* a graph
  plus scoring metadata, and `Level.toGraph()` is a zero-conversion
  handoff to the solvers. Pure Dart, zero Flutter imports, same
  discipline as `lib/engine/`.
- `level_manifest.dart` — parses `assets/levels/manifest.json` (which
  track has which curated files). Split out from `level_loader.dart`
  specifically so this part is testable under plain `dart test`, not
  just `flutter test`.
- `level_loader.dart` — the one file here that imports Flutter
  (`rootBundle` for asset access). Unifies curated JSON assets and
  `lib/generation/`'s on-device generator behind one API
  (`LevelLoader`), so gameplay screens (Phase 3+) never need to know
  which path a given attempt's layout came from.
- `level_providers.dart` — the Riverpod wiring (`levelLoaderProvider`,
  `levelCountsProvider`). hub_screen.dart's "N LEVELS LOADED" caption
  and Phase 3+ gameplay screens both read the same provider.

See `lib/generation/` for how the levels themselves get built, and
`tool/generate_levels.dart` for the offline curated-content script.

## Still to come

Save/progress persistence (star totals, unlocked cosmetics, coin
balance) — built once Phase 3+ gameplay actually produces progress to
save.
