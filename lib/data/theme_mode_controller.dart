// Exposes the persisted theme-mode preference (Phase 6 addition) as a
// plain ChangeNotifier, deliberately NOT a Riverpod
// StateNotifier/Notifier — same choice and the same reason
// gameplay_controller.dart's own doc comment already gives for that
// file: Riverpod's Notifier API has changed shape across versions,
// while plain Provider + ChangeNotifier hasn't. app.dart is the sole
// listener — reads this once and rebuilds itself via addListener, the
// same way every gameplay screen already rebuilds itself off its own
// GameplayController.

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
// Riverpod 3.x moved ChangeNotifierProvider (along with StateProvider,
// StateNotifierProvider) out of the main flutter_riverpod.dart export
// into this legacy import, to nudge people toward the new Notifier
// API — it still exists and is fully supported, just not exported by
// default. See this file's own doc comment above: this is exactly
// the kind of Riverpod API churn that made ThemeModeController a
// plain ChangeNotifier in the first place, so pinning to the legacy
// (stable) provider shape here rather than the newer Notifier API is
// consistent with that reasoning, not a contradiction of it.
import 'package:flutter_riverpod/legacy.dart';

import 'progress_providers.dart';

final themeModeControllerProvider =
    ChangeNotifierProvider<ThemeModeController>((ref) {
  return ThemeModeController(ref);
});

class ThemeModeController extends ChangeNotifier {
  ThemeModeController(this._ref) {
    _loadPersisted();
  }

  final Ref _ref;
  ThemeMode _mode = ThemeMode.system;
  ThemeMode get mode => _mode;

  Future<void> _loadPersisted() async {
    final progressStore = await _ref.read(progressStoreProvider.future);
    _mode = progressStore.themeMode;
    notifyListeners();
  }

  /// True if the *effective* theme is dark — resolves
  /// [ThemeMode.system] against the platform brightness so the
  /// header's toggle icon reads correctly even before the player has
  /// made an explicit choice. [platformBrightness] is passed in
  /// rather than read internally since this class has no
  /// [BuildContext] of its own — callers already have one (it's
  /// exactly what [MediaQuery.platformBrightnessOf] needs).
  bool isDark(Brightness platformBrightness) {
    if (_mode == ThemeMode.dark) return true;
    if (_mode == ThemeMode.light) return false;
    return platformBrightness == Brightness.dark;
  }

  Future<void> setThemeMode(ThemeMode mode) async {
    _mode = mode;
    notifyListeners();
    final progressStore = await _ref.read(progressStoreProvider.future);
    await progressStore.setThemeMode(mode);
  }

  /// Toggles between light and dark, ignoring "system" once the
  /// player has made an explicit choice — matches the single
  /// sun/moon icon-button UX in the hub header, which only ever shows
  /// two states.
  Future<void> toggle(Brightness platformBrightness) {
    return setThemeMode(
      isDark(platformBrightness) ? ThemeMode.light : ThemeMode.dark,
    );
  }
}
