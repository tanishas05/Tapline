import 'package:flutter/material.dart';

import '../convoy_colors.dart';
import '../convoy_spacing.dart';
import '../convoy_typography.dart';

/// A large tappable entry point for one of Convoy's three modes.
///
/// Deliberately NOT a Material [Card] — no default elevation shadow.
/// A flat fill plus a hairline border and a small accent-ringed icon
/// reads as an instrument panel rather than a lifted sheet of paper.
class ModePanel extends StatelessWidget {
  const ModePanel({
    super.key,
    required this.title,
    required this.description,
    required this.icon,
    required this.accentColor,
    required this.onTap,
  });

  final String title;
  final String description;
  final IconData icon;
  final Color accentColor;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(4),
        splashColor: accentColor.withValues(alpha: 0.12),
        highlightColor: accentColor.withValues(alpha: 0.05),
        child: Container(
          padding: const EdgeInsets.all(ConvoySpacing.md),
          decoration: BoxDecoration(
            color: ConvoyColors.surface,
            borderRadius: BorderRadius.circular(4),
            border: Border.all(color: ConvoyColors.outline),
          ),
          child: Row(
            children: [
              Container(
                width: 52,
                height: 52,
                alignment: Alignment.center,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: ConvoyColors.surfaceElevated,
                  border: Border.all(color: accentColor, width: 2),
                ),
                child: Icon(icon, color: accentColor, size: 26),
              ),
              const SizedBox(width: ConvoySpacing.md),
              Expanded(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(title, style: ConvoyTypography.panelTitle),
                    const SizedBox(height: 4),
                    Text(description, style: ConvoyTypography.panelSubtitle),
                  ],
                ),
              ),
              const SizedBox(width: ConvoySpacing.sm),
              Icon(
                Icons.chevron_right,
                color: ConvoyColors.textSecondary,
              ),
            ],
          ),
        ),
      ),
    );
  }
}
