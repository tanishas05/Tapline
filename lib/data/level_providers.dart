// Riverpod providers for Phase 2's level loading — the first
// providers in the app (Phase 0's ProviderScope had nothing to wire
// up yet). Deliberately thin: [levelLoaderProvider] is the single
// shared [LevelLoader] instance, and everything else is a plain
// method call on it, so Phase 3+ gameplay screens reach for exactly
// the same provider hub_screen.dart already uses here — no
// screen-specific level-loading logic anywhere.

import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../engine/engine.dart';
import 'level_loader.dart';
import 'level_schema.dart';

final levelLoaderProvider = Provider<LevelLoader>((ref) => LevelLoader());

/// Curated level count per track. Phase 2's verification checklist:
/// "The app can load and list levels per track on the hub screen from
/// Phase 0, even with no interactive gameplay yet" — this is what
/// hub_screen.dart watches to show it.
final levelCountsProvider = FutureProvider<Map<GameMode, int>>((ref) {
  return ref.watch(levelLoaderProvider).countPerTrack();
});

/// The Classic track's curated levels, in slot order — Phase 3's
/// level select screen watches this. One provider per mode rather
/// than a single family isn't needed yet since only Classic exists;
/// Capacity/Signal (Phase 4/5) can add their own the same way, or
/// this can become a `.family(GameMode)` provider at that point
/// without changing how this one is used.
final classicTrackProvider = FutureProvider<List<Level>>((ref) {
  return ref.watch(levelLoaderProvider).loadTrack(GameMode.classic);
});

/// The Capacity track's curated levels, in slot order — Phase 4's
/// level select screen watches this. Same shape as
/// [classicTrackProvider] on purpose.
final capacityTrackProvider = FutureProvider<List<Level>>((ref) {
  return ref.watch(levelLoaderProvider).loadTrack(GameMode.capacity);
});

/// The Signal track's curated levels, in slot order — Phase 5's level
/// select screen watches this. Same shape as the other two tracks.
final signalTrackProvider = FutureProvider<List<Level>>((ref) {
  return ref.watch(levelLoaderProvider).loadTrack(GameMode.signal);
});
