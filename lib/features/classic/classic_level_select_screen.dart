// Level select for the Classic track — now a thin wrapper around the
// shared lib/features/shared/level_select_screen.dart (factored out
// in Phase 4 once Capacity needed the identical structure). See that
// file's doc comment for the scoping note on what "the track" means.

import 'package:flutter/material.dart';

import '../../data/level_providers.dart';
import '../../data/level_schema.dart';
import '../shared/level_select_screen.dart';
import 'classic_gameplay_screen.dart';

class ClassicLevelSelectScreen extends StatelessWidget {
  const ClassicLevelSelectScreen({super.key});

  static const routeName = '/classic';

  @override
  Widget build(BuildContext context) {
    return LevelSelectScreen(
      title: 'CLASSIC',
      trackProvider: classicTrackProvider,
      openGameplayScreen: _open,
    );
  }

  static void _open(BuildContext context, String slotId, Level initialLevel) {
    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (context) => ClassicGameplayScreen(
          slotId: slotId,
          initialLevel: initialLevel,
        ),
      ),
    );
  }
}
