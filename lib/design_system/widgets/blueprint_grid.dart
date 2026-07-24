import 'package:flutter/material.dart';

import '../convoy_colors.dart';

/// The faint graph-paper backdrop behind Convoy's chrome screens — the
/// "hand-drawn blueprint schematic" half of the Industrial
/// Cartography identity. Deliberately restrained: thin lines, low
/// contrast against [ConvoyColors.background], a few coordinate ticks
/// along the top edge like the margin of an architectural drawing —
/// never competing with foreground content.
///
/// Must be used as a direct child of a [Stack]; it positions itself
/// with [Positioned.fill].
class BlueprintGrid extends StatelessWidget {
  const BlueprintGrid({super.key, this.spacing = 28});

  final double spacing;

  @override
  Widget build(BuildContext context) {
    return Positioned.fill(
      child: IgnorePointer(
        child: CustomPaint(
          painter: _BlueprintGridPainter(spacing: spacing),
        ),
      ),
    );
  }
}

class _BlueprintGridPainter extends CustomPainter {
  _BlueprintGridPainter({required this.spacing});

  final double spacing;

  @override
  void paint(Canvas canvas, Size size) {
    final linePaint = Paint()
      ..color = ConvoyColors.gridLine
      ..strokeWidth = 1;

    for (double x = 0; x <= size.width; x += spacing) {
      canvas.drawLine(Offset(x, 0), Offset(x, size.height), linePaint);
    }
    for (double y = 0; y <= size.height; y += spacing) {
      canvas.drawLine(Offset(0, y), Offset(size.width, y), linePaint);
    }

    // Coordinate tick marks along the top edge — every 4th gridline
    // gets a slightly longer, slightly brighter tick.
    final tickPaint = Paint()
      ..color = ConvoyColors.outline.withValues(alpha: 0.6)
      ..strokeWidth = 1;
    var i = 0;
    for (double x = 0; x <= size.width; x += spacing) {
      if (i % 4 == 0) {
        canvas.drawLine(Offset(x, 0), Offset(x, 6), tickPaint);
      }
      i++;
    }
  }

  @override
  bool shouldRepaint(covariant _BlueprintGridPainter oldDelegate) {
    // Always repaint rather than diffing fields: this reads
    // ConvoyColors.gridLine/outline directly inside paint(), which
    // can change (a theme toggle) without `spacing` changing, so a
    // spacing-only comparison would miss it and leave the grid on
    // the old palette until spacing next changes. Cheap at this
    // scale — a few dozen lines — same call other painters in this
    // codebase already make.
    return true;
  }
}
