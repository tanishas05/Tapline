import 'package:flutter/material.dart';

import '../../design_system/design_system.dart';

/// Placeholder destination for a mode panel tap. Each mode's real
/// gameplay screen replaces this one-for-one in a later phase — the
/// hub screen doesn't need to change when that happens, just its
/// `onTap` target.
class ComingSoonScreen extends StatelessWidget {
  const ComingSoonScreen({super.key, required this.modeName});

  final String modeName;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text(modeName.toUpperCase())),
      body: Stack(
        children: [
          const BlueprintGrid(),
          Center(
            child: Padding(
              padding: const EdgeInsets.all(ConvoySpacing.lg),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(
                    Icons.construction,
                    size: 48,
                    color: ConvoyColors.textSecondary,
                  ),
                  const SizedBox(height: ConvoySpacing.md),
                  Text(
                    '${modeName.toUpperCase()} MODE',
                    style: ConvoyTypography.panelTitle,
                  ),
                  const SizedBox(height: ConvoySpacing.sm),
                  Text(
                    'Gameplay lands in a later phase. This screen is a '
                    'Phase 0 placeholder so the hub has somewhere to go.',
                    textAlign: TextAlign.center,
                    style: ConvoyTypography.panelSubtitle,
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}
