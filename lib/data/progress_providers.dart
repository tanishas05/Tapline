// Riverpod wiring for Phase 3's persistence layer — mirrors
// level_providers.dart's shape exactly. A FutureProvider is the right
// fit for [ProgressStore] specifically because
// SharedPreferences.getInstance() is itself async; Riverpod caches
// the resolved instance after the first read, so this behaves as a
// lazy-initialized singleton without any extra bookkeeping here.

import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'progress_store.dart';

final progressStoreProvider = FutureProvider<ProgressStore>((ref) {
  return ProgressStore.create();
});
