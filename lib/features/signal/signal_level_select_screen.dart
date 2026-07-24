// Level select for the Signal track — Phase 5 item 6, matching the
// established pattern via the shared
// lib/features/shared/level_select_screen.dart (see that file's doc
// comment for the scoping note on what "the track" means). Signal's
// track is 15 slots, not 12 — Phase 2's curated set included the
// teaching-pair levels (4 regular + a sparse/dense pair per tier,
// see tool/generate_levels.dart), which show up here as ordinary
// slots in manifest order like everything else; no special-casing
// needed at the level-select layer for them.

import 'package:flutter/material.dart';

import '../../data/level_providers.dart';
import '../../data/level_schema.dart';
import '../shared/level_select_screen.dart';
import 'signal_gameplay_screen.dart';

class SignalLevelSelectScreen extends StatelessWidget {
  const SignalLevelSelectScreen({super.key});

  static const routeName = '/signal';

  @override
  Widget build(BuildContext context) {
    return LevelSelectScreen(
      title: 'SIGNAL',
      trackProvider: signalTrackProvider,
      openGameplayScreen: _open,
    );
  }

  static void _open(BuildContext context, String slotId, Level initialLevel) {
    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (context) => SignalGameplayScreen(
          slotId: slotId,
          initialLevel: initialLevel,
        ),
      ),
    );
  }
}
