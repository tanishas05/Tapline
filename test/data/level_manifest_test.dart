import 'package:tapline/data/level_manifest.dart';
import 'package:tapline/engine/engine.dart';
import 'package:test/test.dart';

void main() {
  group('LevelManifest.fromJson', () {
    test('parses paths per mode using GameMode enum names as keys', () {
      final manifest = LevelManifest.fromJson({
        'classic': [
          'levels/classic/small/a.json',
          'levels/classic/small/b.json',
        ],
        'capacity': ['levels/capacity/small/c.json'],
        'signal': <String>[],
      });

      expect(manifest.pathsFor(GameMode.classic), [
        'levels/classic/small/a.json',
        'levels/classic/small/b.json',
      ]);
      expect(manifest.countFor(GameMode.classic), 2);
      expect(
        manifest.pathsFor(GameMode.capacity),
        ['levels/capacity/small/c.json'],
      );
      expect(manifest.countFor(GameMode.signal), 0);
    });

    test('a missing mode key defaults to an empty list, not a crash', () {
      final manifest = LevelManifest.fromJson({
        'classic': ['levels/classic/small/a.json'],
        // capacity and signal keys deliberately absent
      });
      expect(manifest.countFor(GameMode.capacity), 0);
      expect(manifest.countFor(GameMode.signal), 0);
      expect(manifest.pathsFor(GameMode.capacity), isEmpty);
    });

    test('an empty manifest is valid and reports zero for every mode',
        () {
      final manifest = LevelManifest.fromJson({});
      for (final mode in GameMode.values) {
        expect(manifest.countFor(mode), 0);
      }
    });
  });
}
