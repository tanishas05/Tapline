import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'app.dart';

void main() {
  // ProviderScope wraps the app so Riverpod is wired up from the
  // start, per the project's default state-management choice — even
  // though Phase 0 has no providers of its own yet.
  runApp(const ProviderScope(child: ConvoyApp()));
}
