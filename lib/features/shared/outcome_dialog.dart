// Shared outcome-dialog presentation (Phase 6) — every gameplay
// screen's win/2-star/fail popup, unified here so the star row,
// layout, and button styling stay identical across Classic/Capacity/
// Signal instead of three hand-copied AlertDialogs slowly drifting
// apart. Each mode's gameplay screen still owns all of the BUSINESS
// logic — what the body text says, which actions exist and what they
// do, whether a next slot exists to offer — this only renders what
// it's given. Same "shared = presentational, mode-specific = logic"
// split level_graph_view.dart already uses.

import 'package:flutter/material.dart';

import '../../design_system/design_system.dart';

/// A single button in an outcome dialog's action list.
class OutcomeDialogAction {
  const OutcomeDialogAction(
    this.label,
    this.onPressed, {
    this.primary = false,
  });

  final String label;

  /// Null disables the button (e.g. "not enough coins") rather than
  /// omitting it — the player still sees the option exists.
  final VoidCallback? onPressed;

  /// Filled/highlighted rather than the plain outlined treatment —
  /// for the one action that's the obvious next step (e.g. NEXT
  /// LEVEL on a 3-star clear), so it stands out from the secondary
  /// replay/skip options listed under it. At most one action per
  /// dialog should set this.
  final bool primary;
}

/// Row of three star icons — [filled] of them solid amber, the rest
/// outline-only in a muted tone. Used at the top of every outcome
/// dialog so a 2-star or 3-star clear reads as an actual star rating
/// at a glance, the same way the level-select screen's own
/// [Icons.star] badges already do, not just a "2 STARS" text title.
class OutcomeStarRow extends StatelessWidget {
  const OutcomeStarRow({super.key, required this.filled, this.size = 32});

  final int filled;
  final double size;

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        for (var i = 0; i < 3; i++)
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 2),
            child: Icon(
              i < filled ? Icons.star : Icons.star_border,
              color: i < filled ? ConvoyColors.amber : ConvoyColors.outline,
              size: size,
            ),
          ),
      ],
    );
  }
}

/// Shows the dialog. [starCount] null means no star row at all (the
/// fail states — out of taps / out of time — never showed a partial
/// star rating, and still don't).
Future<void> showOutcomeDialog({
  required BuildContext context,
  required String title,
  required Color accent,
  required String body,
  int? starCount,
  required List<OutcomeDialogAction> actions,
}) {
  return showDialog<void>(
    context: context,
    barrierDismissible: false,
    builder: (context) {
      return AlertDialog(
        backgroundColor: ConvoyColors.surface,
        title: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            if (starCount != null) ...[
              OutcomeStarRow(filled: starCount),
              const SizedBox(height: ConvoySpacing.sm),
            ],
            Text(
              title,
              textAlign: TextAlign.center,
              style: ConvoyTypography.panelTitle.copyWith(color: accent),
            ),
          ],
        ),
        content: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Text(body, style: ConvoyTypography.body),
              const SizedBox(height: ConvoySpacing.lg),
              for (final action in actions) ...[
                _OutcomeActionButton(action: action),
                const SizedBox(height: ConvoySpacing.sm),
              ],
            ],
          ),
        ),
      );
    },
  );
}

class _OutcomeActionButton extends StatelessWidget {
  const _OutcomeActionButton({required this.action});

  final OutcomeDialogAction action;

  @override
  Widget build(BuildContext context) {
    // Pop the dialog first, then run the action — matches the
    // original per-screen dialog's behavior exactly (see e.g.
    // classic_gameplay_screen.dart's history): whichever screen the
    // action itself navigates to (or stays on) happens with the
    // dialog already off the Navigator stack, not underneath it.
    final onTap = action.onPressed == null
        ? null
        : () {
            Navigator.of(context).pop();
            action.onPressed!();
          };

    if (action.primary) {
      return ElevatedButton(
        onPressed: onTap,
        child: Text(action.label, style: ConvoyTypography.buttonLabel),
      );
    }
    return OutlinedButton(
      onPressed: onTap,
      style: OutlinedButton.styleFrom(
        foregroundColor: ConvoyColors.textPrimary,
        side: BorderSide(color: ConvoyColors.outline),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(4),
        ),
        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 14),
      ),
      child: Text(action.label, style: ConvoyTypography.buttonLabel),
    );
  }
}
