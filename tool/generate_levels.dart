// Offline curated-level generator — Phase 2 item 2a: "OFFLINE, via a
// Dart CLI script, to produce an initial curated baseline set of
// levels (useful for hand-tuned early/tutorial slots, and for
// regression-testing the generator itself)."
//
// Run from the project root:
//   dart run tool/generate_levels.dart
//
// Regenerates assets/levels/ from scratch and writes
// assets/levels/manifest.json for level_loader.dart to read. Fully
// deterministic (every level's Random is seeded from its mode/tier/
// index, not wall-clock time) — re-running reproduces byte-identical
// output unless the generators or difficulty_tiers.dart change.
//
// NOTE ON PROVENANCE: the assets/levels/ content shipped alongside
// this script in the Phase 2 delivery was NOT produced by running
// this file — there was no Dart SDK available in the sandbox this was
// written in (see PHASE2_NOTES.md for the full explanation), so that
// content was produced by a Python line-for-line mirror of this exact
// construction strategy and tier table instead, and independently
// re-verified by re-solving every output file with separate solver
// ports. This script is the real, permanent source going forward —
// running it replaces that content with fresh output from the actual
// Dart generators. It won't be byte-identical to the Python-emitted
// set (different RNG implementations across the two languages), but
// it's built from the identical construction strategy and the exact
// same difficulty_tiers.dart tunables, and goes through the same
// construct-then-verify path either way.

import 'dart:convert';
import 'dart:io';
import 'dart:math';

import 'package:tapline/data/level_schema.dart';
import 'package:tapline/engine/engine.dart';
import 'package:tapline/generation/generation.dart';

const Map<DifficultyTier, int> _curatedCountsClassicCapacity = {
  DifficultyTier.small: 5,
  DifficultyTier.medium: 4,
  DifficultyTier.large: 3,
};

const Map<DifficultyTier, int> _curatedCountsSignalRegular = {
  DifficultyTier.small: 4,
  DifficultyTier.medium: 3,
  DifficultyTier.large: 2,
};

void main() {
  final outRoot = Directory('assets/levels');
  if (outRoot.existsSync()) {
    outRoot.deleteSync(recursive: true);
  }
  outRoot.createSync(recursive: true);

  final manifest = <String, List<String>>{
    'classic': <String>[],
    'capacity': <String>[],
    'signal': <String>[],
  };
  final summaryLines = <String>[];

  for (final mode in [GameMode.classic, GameMode.capacity]) {
    for (final tier in DifficultyTier.values) {
      final count = _curatedCountsClassicCapacity[tier]!;
      final optima = <int>[];
      for (var i = 1; i <= count; i++) {
        final id =
            '${mode.name}_${tier.name}_${i.toString().padLeft(3, '0')}';
        final level = ClassicCapacityGenerator.generate(
          mode: mode,
          tier: tier,
          id: id,
          random: Random(_seedFor(mode, tier, i)),
        );
        _writeLevel(outRoot, mode.name, tier.name, level, manifest);
        optima.add(level.optimum);
      }
      summaryLines.add(
        '${mode.name.padRight(10)}${tier.name.padRight(8)}'
        '${count.toString().padRight(7)}$optima',
      );
    }
  }

  for (final tier in DifficultyTier.values) {
    final count = _curatedCountsSignalRegular[tier]!;
    final optima = <int>[];
    for (var i = 1; i <= count; i++) {
      final id = 'signal_${tier.name}_${i.toString().padLeft(3, '0')}';
      final level = SignalGenerator.generate(
        tier: tier,
        id: id,
        random: Random(_seedFor(GameMode.signal, tier, i)),
      );
      _writeLevel(outRoot, 'signal', tier.name, level, manifest);
      optima.add(level.optimum);
    }

    final pair = SignalGenerator.generateTeachingPair(
      tier: tier,
      sparseId: 'signal_${tier.name}_teach_sparse',
      denseId: 'signal_${tier.name}_teach_dense',
      random: Random(_seedFor(GameMode.signal, tier, 900)),
    );
    _writeLevel(outRoot, 'signal', tier.name, pair.sparse, manifest);
    _writeLevel(outRoot, 'signal', tier.name, pair.dense, manifest);
    optima
      ..add(pair.sparse.optimum)
      ..add(pair.dense.optimum);

    summaryLines.add(
      'signal    ${tier.name.padRight(8)}'
      '${(count + 2).toString().padRight(7)}$optima',
    );
  }

  final manifestFile = File('${outRoot.path}/manifest.json');
  manifestFile.writeAsStringSync(
    '${const JsonEncoder.withIndent('  ').convert(manifest)}\n',
  );

  stdout.writeln('mode      tier    count  optima');
  for (final line in summaryLines) {
    stdout.writeln(line);
  }
  final total =
      manifest.values.fold<int>(0, (sum, list) => sum + list.length);
  stdout.writeln('\ntotal curated levels: $total');
  stdout.writeln('manifest: ${manifestFile.path}');
}

/// Deterministic, hashCode-independent seed — plain arithmetic over
/// each enum's `.index` rather than `Object.hashCode`, which Dart
/// doesn't guarantee stable across SDK versions. Reproducibility here
/// only needs to hold for re-runs of this exact script, but there's
/// no reason to risk it on an unspecified hash algorithm when this is
/// just as simple.
int _seedFor(GameMode mode, DifficultyTier tier, int index) {
  return mode.index * 100000 + tier.index * 10000 + index;
}

void _writeLevel(
  Directory outRoot,
  String modeSlug,
  String tierSlug,
  Level level,
  Map<String, List<String>> manifest,
) {
  final dir = Directory('${outRoot.path}/$modeSlug/$tierSlug')
    ..createSync(recursive: true);
  final file = File('${dir.path}/${level.id}.json');
  file.writeAsStringSync(
    '${const JsonEncoder.withIndent('  ').convert(level.toJson())}\n',
  );
  manifest[modeSlug]!.add('levels/$modeSlug/$tierSlug/${level.id}.json');
}
