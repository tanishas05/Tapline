// Local-only persistence for coin balance, per-slot progress,
// unlocked achievements, and app settings — Master Context: "Coin
// balance is local/on-device storage only — no backend, no network
// sync," and more generally "A single local persistence module... is
// the durable source of truth" for everything that needs to survive a
// restart. Phase 6 adds achievements and settings (sound/haptics) to
// this same file rather than standing up a second SharedPreferences
// wrapper beside it — that would be exactly the "scattered ad-hoc
// values" pattern difficulty_tiers.dart was written to avoid, just at
// the persistence layer instead of the tuning-constants layer.
//
// The one file in lib/data/ (besides level_loader.dart) that isn't
// zero-Flutter — shared_preferences is a Flutter plugin package. See
// slot_progress.dart for the pure data model the slot-progress half of
// this wraps, and achievements.dart for the pure catalog/evaluation
// half — both ARE testable under plain `dart test`; this file itself
// needs `flutter test` for the same rootBundle-style reason
// level_loader.dart does.

import 'package:flutter/material.dart' show ThemeMode;
import 'package:shared_preferences/shared_preferences.dart';

import '../engine/engine.dart';
import 'achievements.dart';
import 'slot_progress.dart';

class ProgressStore {
  ProgressStore._(this._prefs);

  final SharedPreferences _prefs;

  static Future<ProgressStore> create() async {
    return ProgressStore._(await SharedPreferences.getInstance());
  }

  static const _coinBalanceKey = 'coin_balance';

  // ---- coins --------------------------------------------------------------

  int get coinBalance => _prefs.getInt(_coinBalanceKey) ?? 0;

  /// Earned ONLY at the moment of an actual 3-star clear (Master
  /// Context) — callers are responsible for only calling this then;
  /// this method itself has no opinion about when it's appropriate,
  /// same as `_prefs.setInt` wouldn't.
  Future<void> addCoins(int amount) async {
    assert(amount >= 0, 'addCoins expects a non-negative amount');
    await _prefs.setInt(_coinBalanceKey, coinBalance + amount);
  }

  /// Spends [amount] if the balance covers it; returns false (and
  /// spends nothing) otherwise.
  Future<bool> spendCoins(int amount) async {
    assert(amount >= 0, 'spendCoins expects a non-negative amount');
    if (coinBalance < amount) return false;
    await _prefs.setInt(_coinBalanceKey, coinBalance - amount);
    return true;
  }

  // ---- slot progress --------------------------------------------------

  SlotProgress slotProgress(String slotId) {
    final outcomeName = _prefs.getString('slot_outcome_$slotId');
    final outcome = SlotOutcome.values.firstWhere(
      (o) => o.name == outcomeName,
      orElse: () => SlotOutcome.none,
    );
    final paidPast = _prefs.getBool('slot_paid_$slotId') ?? false;
    return SlotProgress(bestOutcome: outcome, paidPast: paidPast);
  }

  /// Records [outcome] for [slotId], keeping only the best ever
  /// seen — a later 2-star clear never downgrades a prior 3-star.
  Future<void> recordOutcome(String slotId, SlotOutcome outcome) async {
    final current = slotProgress(slotId);
    if (slotOutcomeRank(outcome) > slotOutcomeRank(current.bestOutcome)) {
      await _prefs.setString('slot_outcome_$slotId', outcome.name);
    }
  }

  Future<void> markPaidPast(String slotId) async {
    await _prefs.setBool('slot_paid_$slotId', true);
  }

  // ---- achievements -----------------------------------------------------

  static const _achievementsKey = 'achievements_unlocked';

  Set<String> get unlockedAchievementIds =>
      (_prefs.getStringList(_achievementsKey) ?? const <String>[]).toSet();

  /// Unlocks [id] if it isn't already, and returns whether it was
  /// actually newly unlocked by this call — callers use that to decide
  /// whether to show a one-time "achievement unlocked" notification,
  /// rather than re-notifying on every subsequent 3-star clear that
  /// would ALSO satisfy an already-unlocked achievement's condition.
  Future<bool> unlockAchievement(AchievementId id) async {
    final current = unlockedAchievementIds;
    if (current.contains(id.name)) return false;
    await _prefs.setStringList(_achievementsKey, [...current, id.name]);
    return true;
  }

  // ---- onboarding ---------------------------------------------------------

  /// Whether the mode-specific first-level tutorial overlay (Phase 6
  /// item 4) has already been shown for [mode] — checked once per mode
  /// on entering that track's gameplay screen, never re-shown after.
  bool hasSeenOnboarding(GameMode mode) =>
      _prefs.getBool('onboarding_seen_${mode.name}') ?? false;

  Future<void> markOnboardingSeen(GameMode mode) async {
    await _prefs.setBool('onboarding_seen_${mode.name}', true);
  }

  // ---- settings -----------------------------------------------------------

  static const _soundEnabledKey = 'settings_sound_enabled';
  static const _hapticsEnabledKey = 'settings_haptics_enabled';

  bool get soundEnabled => _prefs.getBool(_soundEnabledKey) ?? true;
  bool get hapticsEnabled => _prefs.getBool(_hapticsEnabledKey) ?? true;

  Future<void> setSoundEnabled(bool value) async {
    await _prefs.setBool(_soundEnabledKey, value);
  }

  Future<void> setHapticsEnabled(bool value) async {
    await _prefs.setBool(_hapticsEnabledKey, value);
  }

  static const _themeModeKey = 'settings_theme_mode';

  /// Defaults to following the system theme until the player
  /// explicitly toggles it — same default as the sound/haptics
  /// settings above, "on/following-system until told otherwise."
  ThemeMode get themeMode {
    switch (_prefs.getString(_themeModeKey)) {
      case 'light':
        return ThemeMode.light;
      case 'dark':
        return ThemeMode.dark;
      default:
        return ThemeMode.system;
    }
  }

  Future<void> setThemeMode(ThemeMode mode) async {
    await _prefs.setString(_themeModeKey, mode.name);
  }

  // ---- reset ----------------------------------------------------------

  /// Clears coins, every slot's progress, and unlocked achievements —
  /// deliberately does NOT touch [soundEnabled]/[hapticsEnabled] or the
  /// onboarding-seen flags. "Reset progress" in a settings screen reads
  /// as "start the game over," not "forget my sound preference and
  /// make me sit through three tutorials again" — those aren't
  /// progress, they're app configuration, so a scoped key sweep here
  /// rather than `_prefs.clear()` is a deliberate choice, not an
  /// oversight of what clear() would also wipe.
  Future<void> resetAllProgress() async {
    final keysToRemove = _prefs.getKeys().where(
          (key) =>
              key == _coinBalanceKey ||
              key == _achievementsKey ||
              key.startsWith('slot_outcome_') ||
              key.startsWith('slot_paid_'),
        );
    for (final key in keysToRemove.toList(growable: false)) {
      await _prefs.remove(key);
    }
  }
}
