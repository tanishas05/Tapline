import 'package:flutter/material.dart';

import '../convoy_colors.dart';

/// An original hand-laid-out illustration of thick, right-angled
/// pipes with rounded joint collars — in the spirit of "plumbing
/// maze with a tiny figure standing on it" reference art, but drawn
/// from scratch for this app rather than reproducing any existing
/// image (which would be someone else's copyrighted work).
///
/// Two intended uses, both driven by the same painter so the motif
/// stays consistent everywhere it appears:
/// - `PipeMazeArt(rich: true)` — full color, includes the figure.
///   Used as hero/banner artwork (see the hub screen).
/// - `PipeMazeArt(rich: false)` — faint single-tone outline, no
///   figure, low opacity. Used as a full-screen background texture
///   (see [BlueprintGrid], which every chrome screen already uses —
///   swapping what that widget paints is what gets this onto every
///   screen at once, no per-screen changes needed).
class PipeMazeArt extends StatelessWidget {
  const PipeMazeArt({super.key, this.rich = true, this.opacity = 1.0});

  /// Full color with the figure (banner use) vs. a faint monochrome
  /// outline with no figure (background-texture use).
  final bool rich;

  /// Extra opacity multiplier on top of whatever [rich] already
  /// implies — lets a background use case dial the texture down
  /// further without needing a second painter variant.
  final double opacity;

  @override
  Widget build(BuildContext context) {
    final brightness = Theme.of(context).brightness;
    return Opacity(
      opacity: opacity,
      child: CustomPaint(
        painter: _PipeMazePainter(
          rich: rich,
          pipeColor: rich
              ? ConvoyColors.amberFor(brightness)
              : ConvoyColors.outlineFor(brightness),
          jointColor: rich
              ? ConvoyColors.amberDimFor(brightness)
              : ConvoyColors.outlineFor(brightness),
          figureColor: ConvoyColors.cyanFor(brightness),
          background: ConvoyColors.surfaceElevatedFor(brightness),
        ),
        size: Size.infinite,
      ),
    );
  }
}

class _PipeMazePainter extends CustomPainter {
  _PipeMazePainter({
    required this.rich,
    required this.pipeColor,
    required this.jointColor,
    required this.figureColor,
    required this.background,
  });

  final bool rich;
  final Color pipeColor;
  final Color jointColor;
  final Color figureColor;
  final Color background;

  /// The maze layout, as fractions of the canvas (0..1), so it
  /// rescales cleanly to whatever size it's given — a small banner
  /// or a full-screen background alike. Every segment is purely
  /// horizontal or vertical, matching the reference's right-angle
  /// plumbing look; consecutive segments share an endpoint, which is
  /// where a joint collar gets drawn.
  static const List<List<Offset>> _segments = [
    [Offset(0.06, 0.15), Offset(0.06, 0.38)],
    [Offset(0.06, 0.38), Offset(0.27, 0.38)],
    [Offset(0.27, 0.08), Offset(0.27, 0.38)],
    [Offset(0.27, 0.08), Offset(0.56, 0.08)],
    [Offset(0.56, 0.08), Offset(0.56, 0.48)],
    [Offset(0.34, 0.48), Offset(0.78, 0.48)],
    [Offset(0.78, 0.18), Offset(0.78, 0.48)],
    [Offset(0.78, 0.18), Offset(0.96, 0.18)],
  ];

  static const List<Offset> _joints = [
    Offset(0.27, 0.38),
    Offset(0.27, 0.08),
    Offset(0.56, 0.08),
    Offset(0.56, 0.48),
    Offset(0.78, 0.48),
    Offset(0.78, 0.18),
  ];

  @override
  void paint(Canvas canvas, Size size) {
    final pipeWidth = size.shortestSide * (rich ? 0.052 : 0.034);

    final pipePaint = Paint()
      ..color = pipeColor
      ..strokeWidth = pipeWidth
      ..strokeCap = StrokeCap.round
      ..style = PaintingStyle.stroke;

    for (final segment in _segments) {
      canvas.drawLine(
        Offset(segment[0].dx * size.width, segment[0].dy * size.height),
        Offset(segment[1].dx * size.width, segment[1].dy * size.height),
        pipePaint,
      );
    }

    // A thin highlight line down the middle of each pipe — the "shine"
    // that sells a rounded 3D pipe rather than a flat schematic line.
    // Only in the rich variant; the background texture stays flat and
    // quiet on purpose.
    if (rich) {
      final highlightPaint = Paint()
        ..color = Colors.white.withValues(alpha: 0.35)
        ..strokeWidth = pipeWidth * 0.22
        ..strokeCap = StrokeCap.round
        ..style = PaintingStyle.stroke;
      for (final segment in _segments) {
        canvas.drawLine(
          Offset(segment[0].dx * size.width, segment[0].dy * size.height),
          Offset(segment[1].dx * size.width, segment[1].dy * size.height),
          highlightPaint,
        );
      }
    }

    // Joint collars: a filled disc slightly larger than the pipe
    // itself, plus a ridge ring outset from it — the banded-collar
    // look of a real pipe fitting, at every elbow/T in the maze.
    final jointFillPaint = Paint()..color = jointColor;
    final jointRingPaint = Paint()
      ..color = pipeColor
      ..strokeWidth = pipeWidth * 0.14
      ..style = PaintingStyle.stroke;
    for (final joint in _joints) {
      final center = Offset(joint.dx * size.width, joint.dy * size.height);
      final radius = pipeWidth * 0.62;
      canvas.drawCircle(center, radius, jointFillPaint);
      canvas.drawCircle(center, radius * 1.22, jointRingPaint);
    }

    if (rich) {
      _paintFigure(canvas, size, pipeWidth);
    }
  }

  /// A small, deliberately simplified figure — circle head, rounded
  /// torso, two short legs — standing on the horizontal run between
  /// the two mid-maze joints. Kept geometric rather than attempting
  /// detailed illustration, which doesn't hold up hand-coded; the
  /// cyan tone ties it to the same accent Signal mode already uses
  /// elsewhere in the app, so it reads as "belongs to this app"
  /// rather than a generic clip-art person.
  void _paintFigure(Canvas canvas, Size size, double pipeWidth) {
    final standAt = Offset(0.5 * size.width, 0.48 * size.height);
    final figureHeight = size.shortestSide * 0.16;
    final headRadius = figureHeight * 0.16;
    final feetY = standAt.dy - pipeWidth * 0.5;
    final headCenter = Offset(
      standAt.dx,
      feetY - figureHeight + headRadius,
    );

    final fillPaint = Paint()..color = figureColor;
    final outlinePaint = Paint()
      ..color = background
      ..strokeWidth = figureHeight * 0.05
      ..style = PaintingStyle.stroke
      ..strokeJoin = StrokeJoin.round;

    // Legs — two short rounded strokes down to the pipe.
    final legPaint = Paint()
      ..color = figureColor
      ..strokeWidth = headRadius * 0.6
      ..strokeCap = StrokeCap.round;
    final hipY = feetY - figureHeight * 0.32;
    canvas.drawLine(
      Offset(standAt.dx - headRadius * 0.5, hipY),
      Offset(standAt.dx - headRadius * 0.9, feetY),
      legPaint,
    );
    canvas.drawLine(
      Offset(standAt.dx + headRadius * 0.5, hipY),
      Offset(standAt.dx + headRadius * 0.9, feetY),
      legPaint,
    );

    // Torso — a rounded rectangle between hips and shoulders.
    final torsoRect = RRect.fromRectAndRadius(
      Rect.fromCenter(
        center: Offset(standAt.dx, (hipY + headCenter.dy + headRadius) / 2),
        width: headRadius * 2.1,
        height: hipY - (headCenter.dy + headRadius) + headRadius * 0.4,
      ),
      Radius.circular(headRadius * 0.6),
    );
    canvas.drawRRect(torsoRect, fillPaint);
    canvas.drawRRect(torsoRect, outlinePaint);

    // Head.
    canvas.drawCircle(headCenter, headRadius, fillPaint);
    canvas.drawCircle(headCenter, headRadius, outlinePaint);
  }

  @override
  bool shouldRepaint(covariant _PipeMazePainter oldDelegate) {
    return rich != oldDelegate.rich ||
        pipeColor != oldDelegate.pipeColor ||
        jointColor != oldDelegate.jointColor ||
        figureColor != oldDelegate.figureColor ||
        background != oldDelegate.background;
  }
}
