// Thin wrapper around [HapticFeedback] that respects the player's
// haptics setting persisted in [ProgressStore.hapticsEnabled] (see
// settings_screen.dart / progress_store.dart). Before this file, the
// HAPTICS toggle in Settings only wrote a preference — nothing in
// the app ever actually called HapticFeedback, so the switch had no
// effect. Every gameplay call site should go through the functions
// here rather than calling HapticFeedback directly, so the setting
// has a single enforcement point instead of each screen needing to
// remember to check it.

import 'package:flutter/services.dart';

import '../../data/progress_store.dart';

/// A light tick on every node tap/untap — mirrors the iOS "selection
/// changed" feel, since a node toggle is exactly that: a selection
/// change, not a destructive or confirming action.
void hapticNodeTap(ProgressStore? store) {
  if (store == null || !store.hapticsEnabled) return;
  HapticFeedback.selectionClick();
}

/// A firmer pulse for a 2-star or 3-star clear.
void hapticSuccess(ProgressStore? store) {
  if (store == null || !store.hapticsEnabled) return;
  HapticFeedback.mediumImpact();
}

/// The heaviest pulse, reserved for a failed attempt (out of taps or
/// out of time) — distinct from success so the two never feel the
/// same with eyes off the screen.
void hapticFailure(ProgressStore? store) {
  if (store == null || !store.hapticsEnabled) return;
  HapticFeedback.heavyImpact();
}
