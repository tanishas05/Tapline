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
/// [PipeState], animating smoothly between states.
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
      duration: const Duration(milliseconds: 320),
    )..value = 1;
    _fromColor = _toColor = _colorFor(widget.state);
    _fromWidth = _toWidth = _widthFor(widget.state);
  }

  @override
  void didUpdateWidget(covariant ConvoyPipe oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.state != widget.state) {
      // Capture wherever the animation currently is as the new start
      // point, so re-triggering mid-transition doesn't jump.
      _fromColor = Color.lerp(_fromColor, _toColor, _controller.value)!;
      _fromWidth = _lerpDouble(_fromWidth, _toWidth, _controller.value);
      _toColor = _colorFor(widget.state);
      _toWidth = _widthFor(widget.state);
      _controller
        ..stop()
        ..value = 0
        ..forward();
    }
  }

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
        final t = _controller.value;
        return SizedBox.expand(
          child: CustomPaint(
            painter: _PipePainter(
              start: widget.start,
              end: widget.end,
              curvature: widget.curvature,
              color: Color.lerp(_fromColor, _toColor, t)!,
              strokeWidth: _lerpDouble(_fromWidth, _toWidth, t),
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
    required this.color,
    required this.strokeWidth,
    required this.state,
    required this.directed,
  });

  final Offset start;
  final Offset end;
  final double curvature;
  final Color color;
  final double strokeWidth;
  final PipeState state;
  final bool directed;

  @override
  void paint(Canvas canvas, Size size) {
    final path = _buildPath();

    // Soft outer glow when the pipe is actually carrying something —
    // a wide, blurred pass underneath everything else, so a live pipe
    // reads as visibly "powered" rather than just a thicker line.
    if (state == PipeState.active || state == PipeState.spillover) {
      final glowPaint = Paint()
        ..color = color.withValues(alpha: state == PipeState.active ? 0.35 : 0.22)
        ..strokeWidth = strokeWidth * 2.6
        ..style = PaintingStyle.stroke
        ..strokeCap = StrokeCap.round
        ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 6);
      canvas.drawPath(path, glowPaint);
    }

    // A genuinely dimensional tube: dark outline for edge definition,
    // a shadow band along one side, the base color as the tube's main
    // body, and a bright highlight offset toward the OTHER side (not
    // centered) — mimicking a light source hitting the top of a round
    // pipe. Centering the highlight (the previous version) reads as
    // flat; offsetting it is what actually sells roundness.
    final tubeRadius = strokeWidth * 0.9;

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
    final shadowPath = _offsetPath(path, tubeRadius * 0.55);
    final highlightPaint = Paint()
      ..color = Colors.white.withValues(alpha: 0.85)
      ..strokeWidth = tubeRadius * 0.55
      ..style = PaintingStyle.stroke
      ..strokeCap = StrokeCap.round;
    final highlightPath = _offsetPath(path, -tubeRadius * 0.45);

    if (state == PipeState.decaying) {
      _paintDashed(canvas, path, outlinePaint);
      _paintDashed(canvas, path, bodyPaint);
      _paintDashed(canvas, shadowPath, shadowPaint);
      _paintDashed(canvas, highlightPath, highlightPaint);
    } else {
      canvas.drawPath(path, outlinePaint);
      canvas.drawPath(path, bodyPaint);
      canvas.drawPath(shadowPath, shadowPaint);
      canvas.drawPath(highlightPath, highlightPaint);
    }

    if (directed) {
      _paintArrowhead(canvas, path);
    }
  }

  /// Builds a copy of [source] shifted [distance] px perpendicular to
  /// its own local tangent at each sampled point — used to derive the
  /// two parallel "leads" of the twin-wire look from the single
  /// center curve, so both leads bow together instead of one being a
  /// naive straight-line offset that drifts off the real curve.
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
  /// ruled line. Factored out of [_buildPath] so the arrowhead can
  /// reuse [control2] to find the curve's own tangent direction at
  /// [end], rather than pointing along the straight start->end line
  /// (which would visibly disagree with the curve itself whenever
  /// [curvature] bows it any real distance away from that line).
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

  /// Placed at the curve's own midpoint rather than near [end] — the
  /// previous end-anchored placement put every arrow right where all
  /// of a node's edges converge, exactly the most cluttered, most
  /// overlapping part of the drawing, which is what made direction
  /// genuinely hard to read on a busy graph. The middle of a curve's
  /// open span, away from any node, is uncluttered on every edge by
  /// construction — nothing else is ever drawn there.
  static const double _arrowLength = 22;
  static const double _arrowHalfWidth = 12;

  void _paintArrowhead(Canvas canvas, Path path) {
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
    // the real arrow on top — otherwise an inactive-state arrow (gray,
    // same as the wire) disappears into a busy tangle of overlapping
    // twin-lead wires. The outline gives it an edge to read against
    // regardless of what's crossing behind it.
    canvas.drawPath(
      arrow,
      Paint()
        ..color = ConvoyColors.background
        ..style = PaintingStyle.stroke
        ..strokeWidth = 3
        ..strokeJoin = StrokeJoin.round,
    );
    canvas.drawPath(arrow, Paint()
      ..color = color
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
        oldDelegate.color != color ||
        oldDelegate.strokeWidth != strokeWidth ||
        oldDelegate.state != state ||
        oldDelegate.directed != directed;
  }
}