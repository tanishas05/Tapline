// Level select for the Capacity track — Phase 4 item 6, matching
// Phase 3's pattern exactly via the shared
// lib/features/shared/level_select_screen.dart (see that file's doc
// comment for the scoping note on what "the track" means).

import 'package:flutter/material.dart';

import '../../data/level_providers.dart';
import '../../data/level_schema.dart';
import '../shared/level_select_screen.dart';
import 'capacity_gameplay_screen.dart';

class CapacityLevelSelectScreen extends StatelessWidget {
  const CapacityLevelSelectScreen({super.key});

  static const routeName = '/capacity';

  @override
  Widget build(BuildContext context) {
    return LevelSelectScreen(
      title: 'CAPACITY',
      trackProvider: capacityTrackProvider,
      openGameplayScreen: _open,
    );
  }

  static void _open(BuildContext context, String slotId, Level initialLevel) {
    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (context) => CapacityGameplayScreen(
          slotId: slotId,
          initialLevel: initialLevel,
        ),
      ),
    );
  }
}
