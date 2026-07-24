// In-app level loader — Phase 2 item 4: unifies curated JSON assets
// and the on-device generator behind one API, so "the mode-specific
// gameplay screens (Phases 3-5) shouldn't need to know or care which
// path a given attempt's layout came from, only that it arrives
// pre-verified with optimum, timeLimitSeconds, and difficultyTier
// set."
//
// This is the one file in lib/data/ that imports Flutter (for
// rootBundle asset access) — see level_manifest.dart for the
// pure-Dart manifest parsing this delegates to (testable under plain
// `dart test`) and level_schema.dart for Level itself. This file's
// own tests need `flutter test`, same as any widget test, since
// rootBundle only resolves inside a Flutter test binding — not
// exercised in the sandbox this was written in (no Flutter SDK
// available there either; see PHASE2_NOTES.md).

import 'dart:convert';

import 'package:flutter/services.dart' show AssetBundle, rootBundle;

import '../engine/engine.dart';
import '../generation/classic_capacity_generator.dart';
import '../generation/difficulty_tiers.dart';
import '../generation/signal_generator.dart';
import 'level_manifest.dart';
import 'level_schema.dart';

class LevelLoader {
  LevelLoader({AssetBundle? bundle}) : _bundle = bundle ?? rootBundle;

  final AssetBundle _bundle;
  LevelManifest? _cachedManifest;

  Future<LevelManifest> _loadManifest() async {
    final cached = _cachedManifest;
    if (cached != null) return cached;
    final raw = await _bundle.loadString('assets/levels/manifest.json');
    final manifest =
        LevelManifest.fromJson(jsonDecode(raw) as Map<String, dynamic>);
    _cachedManifest = manifest;
    return manifest;
  }

  /// Loads every curated level for [mode], in manifest order.
  Future<List<Level>> loadTrack(GameMode mode) async {
    final manifest = await _loadManifest();
    final levels = <Level>[];
    for (final path in manifest.pathsFor(mode)) {
      final raw = await _bundle.loadString('assets/$path');
      levels.add(Level.fromJson(jsonDecode(raw) as Map<String, dynamic>));
    }
    return levels;
  }

  /// Curated level count per track. Phase 2's verification checklist:
  /// "The app can load and list levels per track on the hub screen
  /// from Phase 0, even with no interactive gameplay yet" — this is
  /// what hub_screen.dart calls to show it.
  Future<Map<GameMode, int>> countPerTrack() async {
    final manifest = await _loadManifest();
    return {
      for (final mode in GameMode.values) mode: manifest.countFor(mode),
    };
  }

  /// A brand-new, freshly-verified layout at [tier] for [mode].
  /// Master Context's retry rule: "always call
  /// generateNewLevelSameDifficulty() for a brand-new layout at the
  /// same difficulty tier. NEVER reuse the exact layout just
  /// attempted." Gameplay screens (Phase 3+) call this one method
  /// regardless of mode on a 2-star decline or either fail type —
  /// which generator actually runs is this loader's problem, not
  /// theirs. Synchronous and on-device: both generators are pure Dart
  /// with no I/O, so there's nothing to await here.
  Level generateNewLevelSameDifficulty({
    required GameMode mode,
    required DifficultyTier tier,
  }) {
    final id = '${mode.name}_${tier.name}_retry_'
        '${DateTime.now().microsecondsSinceEpoch}';
    if (mode == GameMode.signal) {
      return SignalGenerator.generate(tier: tier, id: id);
    }
    return ClassicCapacityGenerator.generate(mode: mode, tier: tier, id: id);
  }
}
