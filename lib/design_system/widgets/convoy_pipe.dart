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
    final paint = Paint()
      ..color = color
      ..strokeWidth = strokeWidth
      ..style = PaintingStyle.stroke
      ..strokeCap = StrokeCap.round;

    if (state == PipeState.decaying) {
      _paintDashed(canvas, path, paint);
    } else {
      canvas.drawPath(path, paint);
    }

    if (directed) {
      _paintArrowhead(canvas);
    }
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

  /// A cubic bezier is tangent to its final control-point segment at
  /// t=1 — i.e. the curve's true direction at [end] is exactly
  /// `end - control2`, not `end - start`. Placed [_arrowInset] pixels
  /// back from [end] along that direction, not right at [end] itself,
  /// since [end] is a node's CENTER (see LevelGraphView) and the node
  /// glyph painted on top would otherwise bury the arrowhead entirely.
  static const double _arrowInset = 34;
  static const double _arrowLength = 13;
  static const double _arrowHalfWidth = 7;

  void _paintArrowhead(Canvas canvas) {
    final tangent = end - _controlPoints().control2;
    final tangentLength = tangent.distance;
    if (tangentLength == 0) return; // degenerate segment, nothing to aim
    final direction = tangent / tangentLength;
    final perp = Offset(-direction.dy, direction.dx) * _arrowHalfWidth;

    final tip = end - direction * _arrowInset;
    final back = tip - direction * _arrowLength;

    final path = Path()
      ..moveTo(tip.dx, tip.dy)
      ..lineTo((back + perp).dx, (back + perp).dy)
      ..lineTo((back - perp).dx, (back - perp).dy)
      ..close();
    canvas.drawPath(path, Paint()
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
