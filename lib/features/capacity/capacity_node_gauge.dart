// Capacity's node gauge — Phase 4 item 1. Wraps the shared
// [ConvoyNodeGlyph] (same tapped/supplied/decaying ring language as
// Classic) in an outer fill ring showing total_supply(v) as a
// fraction of dem(v), animating smoothly as taps change.
//
// LEGIBILITY, not an afterthought: this mode shows two numbers per
// node (current supply, demand) plus the spillover animation on the
// pipes, which the brief calls out as the densest of the three modes.
// The design here is deliberately layered rather than crammed into
// one glyph: the RING is the "read this from across the room" signal
// (how full, what color), the TEXT underneath is the "read this up
// close" signal (the exact numbers) — nobody has to parse a number to
// tell a node is in trouble, and nobody has to guess a percentage to
// know exactly how much more supply it needs.

import 'package:flutter/material.dart';

import '../../design_system/design_system.dart';

class CapacityNodeGauge extends StatelessWidget {
  const CapacityNodeGauge({
    super.key,
    required this.supply,
    required this.demand,
    required this.state,
    this.diameter = 64,
    this.onTap,
  });

  final double supply;
  final double demand;
  final NodeVisualState state;
  final double diameter;
  final VoidCallback? onTap;

  static const double _ringExtra = 14;
  static const double _epsilon = 1e-9;

  double get _fillRatio =>
      demand <= 0 ? 1.0 : (supply / demand).clamp(0.0, 1.0);

  bool get _isSatisfied => supply >= demand - _epsilon;

  /// A visibly-past-100% node gets its own subtle glow, so "just
  /// barely made it" and "comfortably supplied" don't look identical
  /// once the ring is already full either way.
  bool get _isComfortablyOver => demand > 0 && supply >= demand * 1.15;

  Color get _gaugeColor =>
      _isSatisfied ? ConvoyColors.amber : ConvoyColors.redDecay;

  @override
  Widget build(BuildContext context) {
    final ringDiameter = diameter + _ringExtra;

    return GestureDetector(
      onTap: onTap,
      behavior: HitTestBehavior.opaque,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          SizedBox(
            width: ringDiameter,
            height: ringDiameter,
            child: Stack(
              alignment: Alignment.center,
              children: [
                if (_isComfortablyOver)
                  Container(
                    width: ringDiameter,
                    height: ringDiameter,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      boxShadow: [
                        BoxShadow(
                          color: ConvoyColors.amber.withValues(alpha: 0.35),
                          blurRadius: 12,
                          spreadRadius: 1,
                        ),
                      ],
                    ),
                  ),
                TweenAnimationBuilder<double>(
                  tween: Tween(begin: 0, end: _fillRatio),
                  duration: const Duration(milliseconds: 320),
                  curve: Curves.easeOut,
                  builder: (context, value, child) {
                    return SizedBox(
                      width: ringDiameter,
                      height: ringDiameter,
                      child: CircularProgressIndicator(
                        value: value,
                        strokeWidth: 5,
                        color: _gaugeColor,
                        backgroundColor: ConvoyColors.outline,
                      ),
                    );
                  },
                ),
                ConvoyNodeGlyph(
                  icon: Icons.speed,
                  state: state,
                  diameter: diameter,
                ),
              ],
            ),
          ),
          const SizedBox(height: 4),
          Text(
            '${supply.round()}/${demand.round()}',
            style: ConvoyTypography.monoLabel,
            textAlign: TextAlign.center,
          ),
        ],
      ),
    );
  }
}
