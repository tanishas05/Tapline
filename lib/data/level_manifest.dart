// Pure-Dart parsing for the curated level manifest
// (assets/levels/manifest.json) — split out from level_loader.dart
// specifically so this part is testable under plain `dart test`, not
// just `flutter test`. level_loader.dart needs Flutter's rootBundle to
// actually fetch the manifest file from the asset bundle, which pulls
// a Flutter import into that file's dependency graph; this file
// avoids that entirely, same reasoning as graph.dart's GraphPoint
// avoiding dart:ui.

import '../engine/engine.dart';

/// The curated level manifest: for each mode, the list of asset paths
/// (relative to the Flutter `assets/` root — i.e. already prefixed
/// with `levels/...`, ready to hand to `rootBundle.loadString`
/// after prepending `assets/`) of every curated level file for that
/// track. Written by tool/generate_levels.dart; read by
/// level_loader.dart.
class LevelManifest {
  const LevelManifest(this.pathsByMode);

  final Map<GameMode, List<String>> pathsByMode;

  List<String> pathsFor(GameMode mode) => pathsByMode[mode] ?? const [];

  int countFor(GameMode mode) => pathsFor(mode).length;

  factory LevelManifest.fromJson(Map<String, dynamic> json) {
    final pathsByMode = <GameMode, List<String>>{};
    for (final mode in GameMode.values) {
      final raw = json[mode.name];
      pathsByMode[mode] =
          raw == null ? const [] : (raw as List).map((e) => e as String).toList();
    }
    return LevelManifest(pathsByMode);
  }
}
