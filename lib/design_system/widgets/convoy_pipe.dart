import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../convoy_colors.dart';

/// The visual/logical state of a pipe segment.
///
/// Mirrors the network state a gameplay mode will drive later: a pipe
/// is [inactive] until supply reaches it, [active] while it's
/// carrying full-intensity supply, [spillover] while it's carrying
/// Capacity mode's reduced 0.5x spillover contribution specifically
/// (Phase 4 — deliberately distinct from [active] so the spillover
/// mechanic reads as "weaker, but real" at a glance, not the same
/// visual as a direct tap), or [decaying] once the node it feeds
/// starts losing supply.
enum PipeState { inactive, active, spillover, decaying }

/// A curved bezier connector between two points, styled per the
/// Industrial Cartography identity — routed like an engineer drew it,
/// not ruled with a straight line — and colored/weighted by
/// [PipeState], animating between states as a one-time fill that
/// sweeps from [start] toward [end] rather than snapping instantly or
/// looping indefinitely.
///
/// [ConvoyPipe] always fills whatever box it's given, so give it
/// explicit bounds from a parent: a sized [SizedBox]/[AspectRatio], an
/// [Expanded] inside a Row/Column, or [Positioned.fill] inside a
/// [Stack]. [start] and [end] are offsets local to that box.
class ConvoyPipe extends StatefulWidget {
  const ConvoyPipe({
    super.key,
    required this.start,
    required this.end,
    this.state = PipeState.inactive,
    this.curvature = 0.22,
    this.baseStrokeWidth = 4,
    this.directed = false,
  });

  final Offset start;
  final Offset end;
  final PipeState state;

  /// How far the connector bows away from a straight line, as a
  /// fraction of the segment's length. 0 = straight line.
  final double curvature;

  final double baseStrokeWidth;

  /// Draws a filled arrowhead near [end], pointing along the curve's
  /// own tangent there rather than a straight line from [start] to
  /// [end] — Signal mode (Phase 5), where an edge's direction is part
  /// of the puzzle itself, not decoration. Independent of [state]: a
  /// directed edge still points the same way whether it's currently
  /// carrying reachability or not, so a [PipeState.decaying] pipe
  /// still gets an arrowhead, just dashed like everything else about
  /// it.
  final bool directed;

  @override
  State<ConvoyPipe> createState() => _ConvoyPipeState();
}

class _ConvoyPipeState extends State<ConvoyPipe>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller;
  late Color _fromColor;
  late Color _toColor;
  late double _fromWidth;
  late double _toWidth;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      // One-shot 0->1 play per state change, not a repeat() loop — the
      // pipe settles once it's done coloring in, doesn't keep
      // animating forever. Synced to 0.75s to match ConvoyNodeGlyph's
      // valve-spin duration, so both finish together.
      duration: const Duration(milliseconds: 750),
    )..value = 1;
    _fromColor = _toColor = _colorFor(widget.state);
    _fromWidth = _toWidth = _widthFor(widget.state);
  }

  @override
  void didUpdateWidget(covariant ConvoyPipe oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.state != widget.state) {
      // Whatever's currently on screen becomes the new fill's
      // starting point, so re-triggering mid-sweep doesn't jump.
      _fromColor = _currentDisplayColor();
      _fromWidth = _lerpDouble(_fromWidth, _toWidth, _controller.value);
      _toColor = _colorFor(widget.state);
      _toWidth = _widthFor(widget.state);
      _controller
        ..stop()
        ..value = 0
        ..forward();
    }
  }

  /// Where the fill sweep visually is right now, so a second state
  /// change mid-animation continues smoothly from there rather than
  /// restarting from whatever the fully-old color was.
  Color _currentDisplayColor() =>
      Color.lerp(_fromColor, _toColor, _controller.value)!;

  Color _colorFor(PipeState state) {
    switch (state) {
      case PipeState.inactive:
        return ConvoyColors.outline;
      case PipeState.active:
        return ConvoyColors.amber;
      case PipeState.spillover:
        return ConvoyColors.amberDim;
      case PipeState.decaying:
        return ConvoyColors.redDecay;
    }
  }

  double _widthFor(PipeState state) {
    switch (state) {
      case PipeState.inactive:
        return widget.baseStrokeWidth;
      case PipeState.active:
        return widget.baseStrokeWidth * 1.4;
      case PipeState.spillover:
        return widget.baseStrokeWidth * 1.1;
      case PipeState.decaying:
        return widget.baseStrokeWidth * 1.1;
    }
  }

  static double _lerpDouble(double a, double b, double t) => a + (b - a) * t;

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _controller,
      builder: (context, _) {
        return SizedBox.expand(
          child: CustomPaint(
            painter: _PipePainter(
              start: widget.start,
              end: widget.end,
              curvature: widget.curvature,
              fromColor: _fromColor,
              toColor: _toColor,
              currentWidth: _lerpDouble(_fromWidth, _toWidth, _controller.value),
              fillProgress: _controller.value,
              state: widget.state,
              directed: widget.directed,
            ),
          ),
        );
      },
    );
  }
}

class _PipePainter extends CustomPainter {
  _PipePainter({
    required this.start,
    required this.end,
    required this.curvature,
    required this.fromColor,
    required this.toColor,
    required this.currentWidth,
    required this.fillProgress,
    required this.state,
    required this.directed,
  });

  final Offset start;
  final Offset end;
  final double curvature;

  /// The color the pipe is sweeping FROM (wherever it visually was
  /// before this state change) and TO (the new state's target color).
  final Color fromColor;
  final Color toColor;

  final double currentWidth;

  /// 0..1 — how far the [toColor] fill has swept from [start] toward
  /// [end] this transition. 0 = fully [fromColor], 1 = fully
  /// [toColor]. Plays once per state change and stops; does not loop.
  final double fillProgress;

  final PipeState state;
  final bool directed;

  @override
  void paint(Canvas canvas, Size size) {
    final path = _buildPath();
    final tubeRadius = currentWidth * 0.9;

    // The un-filled remainder, in the OLD color, across the whole
    // pipe first — the fill overlay drawn on top only needs to cover
    // the swept portion, not redraw everything.
    _drawTube(canvas, path, fromColor, tubeRadius, dashed: state == PipeState.decaying);

    // The fill itself: the NEW color, only on the swept sub-path —
    // this is the actual "coloring in gradually" effect. Once
    // fillProgress reaches 1 this covers the entire pipe and the base
    // layer underneath is fully hidden.
    if (fillProgress > 0) {
      final metrics = path.computeMetrics().toList();
      if (metrics.isNotEmpty) {
        final metric = metrics.first;
        final filledPath = metric.extractPath(0, fillProgress * metric.length);

        if (state == PipeState.active || state == PipeState.spillover) {
          final glowPaint = Paint()
            ..color = toColor.withValues(
              alpha: state == PipeState.active ? 0.35 : 0.22,
            )
            ..strokeWidth = tubeRadius * 2.6
            ..style = PaintingStyle.stroke
            ..strokeCap = StrokeCap.round
            ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 6);
          canvas.drawPath(filledPath, glowPaint);
        }

        _drawTube(
          canvas,
          filledPath,
          toColor,
          tubeRadius,
          dashed: state == PipeState.decaying,
        );
      }
    }

    if (directed) {
      _paintArrowhead(canvas, path, toColor);
    }
  }

  /// A genuinely dimensional tube segment: dark outline for edge
  /// definition, a shadow band along one side, the base color as the
  /// tube's main body, and a bright highlight offset toward the OTHER
  /// side (not centered) — mimicking a light source hitting the top
  /// of a round pipe. Centering the highlight reads as flat;
  /// offsetting it is what actually sells roundness. Factored out so
  /// both the base (old-color) and fill (new-color, partial-length)
  /// layers get identical treatment.
  void _drawTube(
    Canvas canvas,
    Path segment,
    Color color,
    double tubeRadius, {
    required bool dashed,
  }) {
    final outlinePaint = Paint()
      ..color = Color.lerp(color, Colors.black, 0.6)!
      ..strokeWidth = tubeRadius * 2.3
      ..style = PaintingStyle.stroke
      ..strokeCap = StrokeCap.round;
    final bodyPaint = Paint()
      ..color = color
      ..strokeWidth = tubeRadius * 1.9
      ..style = PaintingStyle.stroke
      ..strokeCap = StrokeCap.round;
    final shadowPaint = Paint()
      ..color = Color.lerp(color, Colors.black, 0.32)!
      ..strokeWidth = tubeRadius * 0.7
      ..style = PaintingStyle.stroke
      ..strokeCap = StrokeCap.round;
    final shadowPath = _offsetPath(segment, tubeRadius * 0.55);
    final highlightPaint = Paint()
      ..color = Colors.white.withValues(alpha: 0.85)
      ..strokeWidth = tubeRadius * 0.55
      ..style = PaintingStyle.stroke
      ..strokeCap = StrokeCap.round;
    final highlightPath = _offsetPath(segment, -tubeRadius * 0.45);

    if (dashed) {
      _paintDashed(canvas, segment, outlinePaint);
      _paintDashed(canvas, segment, bodyPaint);
      _paintDashed(canvas, shadowPath, shadowPaint);
      _paintDashed(canvas, highlightPath, highlightPaint);
    } else {
      canvas.drawPath(segment, outlinePaint);
      canvas.drawPath(segment, bodyPaint);
      canvas.drawPath(shadowPath, shadowPaint);
      canvas.drawPath(highlightPath, highlightPaint);
    }
  }

  /// Builds a copy of [source] shifted [distance] px perpendicular to
  /// its own local tangent at each sampled point — used to derive the
  /// shadow/highlight bands from the single center curve, so they bow
  /// together instead of one being a naive straight-line offset that
  /// drifts off the real curve.
  Path _offsetPath(Path source, double distance) {
    final result = Path();
    for (final metric in source.computeMetrics()) {
      const step = 6.0;
      var traveled = 0.0;
      var first = true;
      while (traveled <= metric.length) {
        final tangent = metric.getTangentForOffset(traveled);
        if (tangent == null) {
          traveled += step;
          continue;
        }
        final normal = Offset(-tangent.vector.dy, tangent.vector.dx);
        final n = normal.distance == 0 ? Offset.zero : normal / normal.distance;
        final point = tangent.position + n * distance;
        if (first) {
          result.moveTo(point.dx, point.dy);
          first = false;
        } else {
          result.lineTo(point.dx, point.dy);
        }
        traveled += step;
      }
    }
    return result;
  }

  /// The two cubic-bezier control points for this segment — bowed out
  /// perpendicular to the straight line by [curvature], which is what
  /// keeps every pipe a genuinely routed curve instead of a straight
  /// ruled line.
  ({Offset control1, Offset control2}) _controlPoints() {
    final dx = end.dx - start.dx;
    final dy = end.dy - start.dy;
    final length = math.sqrt(dx * dx + dy * dy);
    final normal =
        length == 0 ? const Offset(0, 0) : Offset(-dy, dx) / length;
    final bow = normal * (length * curvature);
    return (
      control1: Offset(start.dx + dx * 0.25, start.dy + dy * 0.25) + bow,
      control2: Offset(start.dx + dx * 0.75, start.dy + dy * 0.75) + bow,
    );
  }

  Path _buildPath() {
    final points = _controlPoints();
    return Path()
      ..moveTo(start.dx, start.dy)
      ..cubicTo(
        points.control1.dx,
        points.control1.dy,
        points.control2.dx,
        points.control2.dy,
        end.dx,
        end.dy,
      );
  }

  /// Placed at the curve's own midpoint rather than near [end] — an
  /// end-anchored placement puts every arrow right where all of a
  /// node's edges converge, the most cluttered part of the drawing.
  /// The middle of a curve's open span is uncluttered on every edge
  /// by construction — nothing else is ever drawn there.
  static const double _arrowLength = 22;
  static const double _arrowHalfWidth = 12;

  void _paintArrowhead(Canvas canvas, Path path, Color arrowColor) {
    final metrics = path.computeMetrics().toList();
    if (metrics.isEmpty) return;
    final metric = metrics.first;
    final tangent = metric.getTangentForOffset(metric.length / 2);
    if (tangent == null) return; // degenerate segment, nothing to aim

    final rawVector = tangent.vector;
    final vectorLength = rawVector.distance;
    if (vectorLength == 0) return; // degenerate segment, nothing to aim
    final direction = rawVector / vectorLength;
    final perp = Offset(-direction.dy, direction.dx) * _arrowHalfWidth;

    final tip = tangent.position + direction * (_arrowLength / 2);
    final back = tangent.position - direction * (_arrowLength / 2);

    final arrow = Path()
      ..moveTo(tip.dx, tip.dy)
      ..lineTo((back + perp).dx, (back + perp).dy)
      ..lineTo((back - perp).dx, (back - perp).dy)
      ..close();

    // A slightly larger background-colored outline drawn first, then
    // the real arrow on top — otherwise a gray inactive-state arrow
    // disappears into a busy tangle of overlapping pipes. The outline
    // gives it an edge to read against regardless of what's crossing
    // behind it.
    canvas.drawPath(
      arrow,
      Paint()
        ..color = ConvoyColors.background
        ..style = PaintingStyle.stroke
        ..strokeWidth = 3
        ..strokeJoin = StrokeJoin.round,
    );
    canvas.drawPath(arrow, Paint()
      ..color = arrowColor
      ..style = PaintingStyle.fill);
  }

  void _paintDashed(Canvas canvas, Path path, Paint paint) {
    const dashWidth = 8.0;
    const dashGap = 6.0;
    for (final metric in path.computeMetrics()) {
      var distance = 0.0;
      while (distance < metric.length) {
        final next = math.min(distance + dashWidth, metric.length);
        canvas.drawPath(metric.extractPath(distance, next), paint);
        distance = next + dashGap;
      }
    }
  }

  @override
  bool shouldRepaint(covariant _PipePainter oldDelegate) {
    return oldDelegate.start != start ||
        oldDelegate.end != end ||
        oldDelegate.curvature != curvature ||
        oldDelegate.fromColor != fromColor ||
        oldDelegate.toColor != toColor ||
        oldDelegate.currentWidth != currentWidth ||
        oldDelegate.fillProgress != fillProgress ||
        oldDelegate.state != state ||
        oldDelegate.directed != directed;
  }
}