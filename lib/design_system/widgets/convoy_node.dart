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
        boxShadow: state == NodeVisualState.supplied ||
                state == NodeVisualState.tapped
            ? [
                BoxShadow(
                  color: ConvoyColors.amber.withValues(alpha: 0.35),
                  blurRadius: 14,
                  spreadRadius: 1,
                ),
              ]
            : const [],
      ),
      child: Icon(icon, color: _glyphColor, size: diameter * 0.42),
    );
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
