// A small opaque background chip behind a text label — Phase 6
// legibility pass. Every node/edge label in this codebase before this
// (ConvoyNode's position number, CapacityNodeGauge's supply/demand
// reading) was bare Text with no background, sized to its nominal
// font metrics with no allowance for what's actually drawn behind it.
// That's fine in isolation, but this app's whole visual identity is
// curved pipes threading between and behind nodes — at real density
// (a crowded Capacity board, decoration edges crossing between
// clusters) a label can end up sitting directly over a pipe stroke in
// a similarly muted gray tone, and even though the label technically
// paints on top (Stack ordering — see level_graph_view.dart), a pipe
// running immediately behind or beside small gray-on-white text reads
// as visual noise the eye has to fight through, not a legible number.
//
// [ConvoyLabelChip] exists to give every label a guaranteed-opaque
// backing regardless of what's drawn under it, rather than relying on
// contrast alone. Deliberately minimal — a rounded-rect fill plus a
// thin outline, no elevation/shadow — so it reads as "a label," not
// as another interactive element competing with the node/pipe it's
// attached to.

import 'package:flutter/material.dart';

import '../convoy_colors.dart';
import '../convoy_spacing.dart';
import '../convoy_typography.dart';

class ConvoyLabelChip extends StatelessWidget {
  const ConvoyLabelChip({
    super.key,
    required this.text,
    this.style,
    this.borderColor,
  });

  final String text;

  /// Defaults to [ConvoyTypography.monoLabel] — every current call
  /// site wants that, but a caller with a different emphasis need
  /// (e.g. a warmer/danger color) can override without needing a
  /// second near-identical widget.
  final TextStyle? style;

  /// Defaults to [ConvoyColors.outline] — a caller can tint this to
  /// match a semantic color (e.g. the gauge's own amber/red) so the
  /// chip's border echoes what it's labeling instead of always
  /// reading as neutral chrome.
  final Color? borderColor;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(
        horizontal: ConvoySpacing.xs,
        vertical: 1,
      ),
      decoration: BoxDecoration(
        // Fully opaque — the whole point is to guarantee legibility
        // regardless of what's drawn underneath, not to blend in.
        color: ConvoyColors.surfaceElevated,
        borderRadius: BorderRadius.circular(3),
        border: Border.all(color: borderColor ?? ConvoyColors.outline),
      ),
      child: Text(
        text,
        style: style ?? ConvoyTypography.monoLabel,
        textAlign: TextAlign.center,
      ),
    );
  }
}
