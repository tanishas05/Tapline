import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../convoy_colors.dart';
import '../convoy_typography.dart';

/// The visual state of a node's supply ring.
///
/// [supplied] and [tapped] are deliberately different states, not two
/// names for the same thing: a gameplay screen (Phase 3+) needs to
/// show "this node is covered because I tapped it" and "this node is
/// covered because a neighbor is tapped" as visually distinct — a
/// player scanning the board for what's actually doing work needs
/// that at a glance, not just "everything amber is fine."
enum NodeVisualState { inactive, tapped, supplied, decaying }

/// Just the circular glyph — icon, ring, fill — with none of
/// [ConvoyNode]'s label or tap handling. Extracted specifically so
/// Capacity mode (Phase 4) can wrap this in its own supply/demand
/// gauge ring and compose its own label (a supply/demand reading
/// instead of a plain position number) without duplicating the ring/
/// fill/icon rendering [ConvoyNode] already gets right.
///
/// Renders as a pipe valve wheel (rim + spokes + center hub) —
/// closed/dim when unlit, open/glowing bright once tapped/supplied —
/// regardless of the [icon] a caller passes. A lightbulb read as the
/// wrong metaphor once the rest of the app committed to a plumbing/
/// pipe visual language (see [PipeMazeArt], [ConvoyPipe]'s tube
/// rendering); a valve you turn to open the flow fits that world
/// instead. Hand-drawn with [CustomPaint] rather than a stock icon so
/// the spoke count/proportions can be tuned precisely. [icon] is kept
/// (rather than removed) purely so existing call sites don't need
/// updating; it's unused for rendering now.
class ConvoyNodeGlyph extends StatelessWidget {
  const ConvoyNodeGlyph({
    super.key,
    required this.icon,
    this.state = NodeVisualState.inactive,
    this.diameter = 64,
  });

  final IconData icon;
  final NodeVisualState state;
  final double diameter;

  bool get _isLit =>
      state == NodeVisualState.tapped || state == NodeVisualState.supplied;

  Color get _ringColor {
    switch (state) {
      case NodeVisualState.inactive:
        return ConvoyColors.outline;
      case NodeVisualState.tapped:
        return ConvoyColors.amber;
      case NodeVisualState.supplied:
        return ConvoyColors.amber;
      case NodeVisualState.decaying:
        return ConvoyColors.redDecay;
    }
  }

  Color get _glyphColor {
    switch (state) {
      case NodeVisualState.inactive:
        return ConvoyColors.textSecondary;
      case NodeVisualState.tapped:
        return ConvoyColors.background;
      case NodeVisualState.supplied:
        return ConvoyColors.amber;
      case NodeVisualState.decaying:
        return ConvoyColors.redDecay;
    }
  }

  /// Only [tapped] fills solid — the "this is an active source" read.
  /// [supplied] stays an outline-only ring, same shell color as
  /// everything else, so "covered" and "the reason it's covered"
  /// don't look like the same fact.
  Color get _fillColor {
    return state == NodeVisualState.tapped
        ? ConvoyColors.amber
        : ConvoyColors.surfaceElevated;
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedContainer(
      duration: const Duration(milliseconds: 280),
      curve: Curves.easeOut,
      width: diameter,
      height: diameter,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        color: _fillColor,
        border: Border.all(color: _ringColor, width: 2),
        // A richer, two-layer glow when open: a wide soft outer wash
        // plus a tighter, hotter inner ring, instead of one flat
        // shadow — reads more like a valve actively passing supply.
        boxShadow: _isLit
            ? [
                BoxShadow(
                  color: ConvoyColors.amber.withValues(alpha: 0.25),
                  blurRadius: 22,
                  spreadRadius: 4,
                ),
                BoxShadow(
                  color: ConvoyColors.amber.withValues(alpha: 0.45),
                  blurRadius: 10,
                  spreadRadius: 0,
                ),
              ]
            : const [],
      ),
      child: CustomPaint(
        size: Size.square(diameter * 0.5),
        painter: _ValveWheelPainter(color: _glyphColor),
      ),
    );
  }
}

/// A pipe valve wheel: an outer rim ring, four spokes to a center
/// hub, and a small hub cap — the classic "turn to open the flow"
/// handle shape, drawn to whatever size it's given.
class _ValveWheelPainter extends CustomPainter {
  _ValveWheelPainter({required this.color});

  final Color color;

  @override
  void paint(Canvas canvas, Size size) {
    final center = size.center(Offset.zero);
    final radius = size.shortestSide / 2;
    final strokeWidth = radius * 0.22;

    final rimPaint = Paint()
      ..color = color
      ..style = PaintingStyle.stroke
      ..strokeWidth = strokeWidth
      ..strokeCap = StrokeCap.round;

    // Outer rim — inset so the stroke doesn't clip against the
    // widget's own bounds.
    canvas.drawCircle(center, radius - strokeWidth / 2, rimPaint);

    // Four spokes from the hub out to just inside the rim.
    final spokePaint = Paint()
      ..color = color
      ..style = PaintingStyle.stroke
      ..strokeWidth = strokeWidth * 0.7
      ..strokeCap = StrokeCap.round;
    final spokeInner = radius * 0.22;
    final spokeOuter = radius - strokeWidth;
    for (final angle in [0.0, math.pi / 2, math.pi, math.pi * 1.5])
      canvas.drawLine(
        center + Offset(math.cos(angle), math.sin(angle)) * spokeInner,
        center + Offset(math.cos(angle), math.sin(angle)) * spokeOuter,
        spokePaint,
      );

    // Center hub cap.
    canvas.drawCircle(center, spokeInner * 0.9, Paint()..color = color);
  }

  @override
  bool shouldRepaint(covariant _ValveWheelPainter oldDelegate) {
    return oldDelegate.color != color;
  }
}

/// The generic node shell — glyph, label, and a state ring — that
/// each mode specializes later with its own icon set (Classic:
/// tank/silo, Capacity: gauge/dial, Signal: beacon/tower) and
/// gameplay behavior.
///
/// Phase 0 only builds this shell. The [icon] passed in today (by the
/// hub screen and style guide) is a placeholder standing in for real
/// glyphs designed in a later phase — swapping it is a one-line
/// change per call site, not a structural one.
class ConvoyNode extends StatelessWidget {
  const ConvoyNode({
    super.key,
    required this.icon,
    required this.label,
    this.state = NodeVisualState.inactive,
    this.diameter = 64,
    this.onTap,
  });

  final IconData icon;
  final String label;
  final NodeVisualState state;
  final double diameter;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      behavior: HitTestBehavior.opaque,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          ConvoyNodeGlyph(icon: icon, state: state, diameter: diameter),
          const SizedBox(height: 6),
          Text(
            label,
            style: ConvoyTypography.monoLabel,
            textAlign: TextAlign.center,
          ),
        ],
      ),
    );
  }
}