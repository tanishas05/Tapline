// Sound effects gated by [ProgressStore.soundEnabled] (see
// settings_screen.dart / progress_store.dart). Before this file, the
// SOUND toggle in Settings only wrote a preference — nothing in the
// app ever played audio, so the switch had no effect.
//
// Node-tap feedback stays on Flutter's built-in [SystemSound] — no
// asset or player needed for a plain click. Win/fail use real,
// user-supplied clips (assets/sounds/win.mp3, assets/sounds/fail.mp3)
// played through [AudioPlayer] (package:audioplayers), so the two
// outcomes are actually distinguishable by ear instead of both
// falling back to the same generic system alert.
//
// One [AudioPlayer] instance is reused across calls rather than
// created per-play — cheaper, and avoids overlapping instances if a
// second outcome fires in quick succession (e.g. after a fast
// retry).

import 'package:audioplayers/audioplayers.dart';
import 'package:flutter/foundation.dart' show debugPrint;
import 'package:flutter/services.dart';

import '../../data/progress_store.dart';

final AudioPlayer _effectsPlayer = AudioPlayer()
  ..setReleaseMode(ReleaseMode.stop);

/// A short click on every node tap/untap.
void soundNodeTap(ProgressStore? store) {
  if (store == null || !store.soundEnabled) return;
  SystemSound.play(SystemSoundType.click);
}

/// Played on a 2-star or 3-star clear.
void soundSuccess(ProgressStore? store) {
  if (store == null || !store.soundEnabled) return;
  _effectsPlayer.play(AssetSource('sounds/win.mp3')).catchError((Object e) {
    debugPrint('soundSuccess failed to play assets/sounds/win.mp3: $e');
  });
}

/// Played on a failed attempt (out of taps or out of time).
void soundFailure(ProgressStore? store) {
  if (store == null || !store.soundEnabled) return;
  _effectsPlayer.play(AssetSource('sounds/fail.mp3')).catchError((Object e) {
    debugPrint('soundFailure failed to play assets/sounds/fail.mp3: $e');
  });
}