// Convenience barrel export for the pure-Dart level generation module.
// Zero Flutter imports anywhere in this folder (see each file's own
// doc comment) — same discipline as lib/engine/, so this whole
// barrel resolves fine under plain `dart test`/`dart analyze` too,
// not just through the Flutter toolchain.
export 'classic_capacity_generator.dart';
export 'difficulty_tiers.dart';
export 'level_generation_exception.dart';
export 'signal_generator.dart';
