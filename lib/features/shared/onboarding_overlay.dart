// Mode-specific first-level tutorial overlay — Phase 6 item 4.
//
// Master Context: "a short, mode-specific first-level tutorial overlay
// per track (not a single generic intro dumped at app launch)." One
// reusable widget (this file) plus a `content` struct per mode, rather
// than three hand-copied overlay widgets — the same "factor out what's
// identical, parameterize what isn't" call level_select_screen.dart
// already made for Phase 4/5's level-select screens.
//
// Shown automatically the first time a player opens a mode's gameplay
// screen with `!progressStore.hasSeenOnboarding(mode)` (see each
// gameplay screen's initState), and never again after
// `markOnboardingSeen` — this widget itself has no opinion about WHEN
// to show, only how to render once asked to.

import 'package:flutter/material.dart';

import '../../design_system/design_system.dart';

class OnboardingContent {
  const OnboardingContent({
    required this.title,
    required this.body,
    required this.icon,
    required this.accentColor,
  });

  final String title;
  final String body;
  final IconData icon;
  final Color accentColor;
}

/// Content for each mode's first-level tutorial. Kept together in one
/// place (rather than defined inline in each gameplay screen) so the
/// three tutorials read consistently side by side when someone edits
/// the copy — the same reason difficulty_tiers.dart keeps all three
/// modes' tuning numbers in one file instead of scattering them.
class OnboardingCopy {
  OnboardingCopy._();

  static final classic = OnboardingContent(
    title: 'TAP TO SUPPLY',
    body:
        'Tap a tank to supply it, and every tank connected to it by a '
        'pipe gets covered too. Cover every tank on the board using the '
        'fewest taps you can.',
    icon: Icons.storage,
    accentColor: ConvoyColors.amber,
  );

  static final capacity = OnboardingContent(
    title: 'WATCH THE GAUGE',
    body:
        'Every tank has a demand it needs met. Tapping a tank fully '
        'supplies itself, and sends HALF its capacity to each neighbor. '
        'Partial help can stack. Check the gauge on tanks you didn\'t '
        'tap directly.',
    icon: Icons.speed,
    accentColor: ConvoyColors.amber,
  );

  static final signal = OnboardingContent(
    title: 'CONTROL FLOWS ONE WAY',
    body:
        'Pipes here only carry control in the direction of the arrow. '
        'Driving a tank sends control forward along every arrow it '
        'touches, hop after hop. Find the fewest tanks to drive so '
        'control reaches everyone.',
    icon: Icons.settings_input_antenna,
    accentColor: ConvoyColors.cyan,
  );
}

/// Full-screen scrim + centered card, dismissed with a single button.
/// Not a Material [Dialog] — same reasoning as [ModePanel] avoiding a
/// default [Card]: a flat surface with a hairline border and an
/// accent-ringed icon reads as this app's own instrument-panel
/// language rather than a borrowed system dialog shape.
class OnboardingOverlay extends StatelessWidget {
  const OnboardingOverlay({
    super.key,
    required this.content,
    required this.onDismiss,
  });

  final OnboardingContent content;
  final VoidCallback onDismiss;

  @override
  Widget build(BuildContext context) {
    return Positioned.fill(
      child: Container(
        color: ConvoyColors.background.withValues(alpha: 0.85),
        alignment: Alignment.center,
        padding: const EdgeInsets.all(ConvoySpacing.lg),
        child: Container(
          constraints: const BoxConstraints(maxWidth: 360),
          padding: const EdgeInsets.all(ConvoySpacing.lg),
          decoration: BoxDecoration(
            color: ConvoyColors.surface,
            borderRadius: BorderRadius.circular(4),
            border: Border.all(color: content.accentColor, width: 1.5),
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                width: 52,
                height: 52,
                alignment: Alignment.center,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: ConvoyColors.surfaceElevated,
                  border: Border.all(color: content.accentColor, width: 2),
                ),
                child: Icon(content.icon, color: content.accentColor, size: 26),
              ),
              const SizedBox(height: ConvoySpacing.md),
              Text(content.title, style: ConvoyTypography.panelTitle),
              const SizedBox(height: ConvoySpacing.sm),
              Text(content.body, style: ConvoyTypography.body),
              const SizedBox(height: ConvoySpacing.lg),
              Align(
                alignment: Alignment.centerRight,
                child: ElevatedButton(
                  onPressed: onDismiss,
                  child: const Text('GOT IT'),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
