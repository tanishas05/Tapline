// Shared coin visuals — one definition used by the hub screen's app
// bar AND all three gameplay HUDs, so "what a coin looks like" only
// has one answer in this codebase. Previously each caller either drew
// its own thing or (hub screen) used a plain Icons.circle dot, which
// reads as a bullet point, not a currency. [CoinIcon] paints an
// actual coin — beveled rim, radial shine, embossed mark — and
// [CoinBadge] is the balance pill (icon + number) that wraps it.

import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../../design_system/design_system.dart';

/// A small stylized coin, painted rather than a stock Material icon.
/// [Icons.circle] is a flat single-tone disc — it reads as a dot/
/// bullet at HUD sizes, not a coin. This paints three things a real
/// coin actually has: a darker rim (the coin's edge, seen face-on), a
/// radial gradient face (so it catches "light" instead of sitting
/// flat), and an embossed center mark, all in the app's existing
/// amber token so it stays on-palette.
class CoinIcon extends StatelessWidget {
  const CoinIcon({super.key, this.size = 18});

  final double size;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: size,
      height: size,
      child: CustomPaint(painter: _CoinPainter()),
    );
  }
}

class _CoinPainter extends CustomPainter {
  // ConvoyColors only exposes a single `amber` token per brightness
  // (by design — "exactly two functional accent hues"), not a
  // pre-made shade ramp. A coin needs a darker rim/mark and a lighter
  // face-highlight to read as embossed rather than flat, so those
  // shades are derived here from the one token via HSL lightness
  // offsets, instead of adding new tokens to the shared palette for a
  // single widget's use.
  static Color _shade(Color base, double lightnessDelta) {
    final hsl = HSLColor.fromColor(base);
    final lightness = (hsl.lightness + lightnessDelta).clamp(0.0, 1.0);
    return hsl.withLightness(lightness).toColor();
  }

  @override
  void paint(Canvas canvas, Size size) {
    final center = size.center(Offset.zero);
    final radius = size.width / 2;
    final amber = ConvoyColors.amber;
    final amberDark = _shade(amber, -0.16);
    final amberLight = _shade(amber, 0.16);

    // Rim: a full-size darker disc peeking out from behind a smaller
    // face on top of it — this ring is what makes it read as a coin
    // with depth instead of a flat circle.
    final rimPaint = Paint()..color = amberDark;
    canvas.drawCircle(center, radius, rimPaint);

    // Face: radial gradient so it looks lit rather than a solid fill.
    final faceRadius = radius * 0.86;
    final facePaint = Paint()
      ..shader = RadialGradient(
        center: const Alignment(-0.35, -0.35),
        radius: 0.9,
        colors: [amberLight, amber],
      ).createShader(Rect.fromCircle(center: center, radius: faceRadius));
    canvas.drawCircle(center, faceRadius, facePaint);

    // Inner rim line — a coin's face is usually stamped with a thin
    // ring near its edge, not just a flat disc.
    final innerRingPaint = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = math.max(0.6, size.width * 0.055)
      ..color = amberDark.withValues(alpha: 0.55);
    canvas.drawCircle(center, faceRadius * 0.72, innerRingPaint);

    // Embossed center mark: a "TL" monogram (Tapline) rather than an
    // abstract line-and-arc mark — the earlier abstract mark was
    // reported as reading like a stray question mark at small sizes,
    // where a recognizable two-letter monogram doesn't have that
    // ambiguity.
    final markSpan = TextSpan(
      text: 'TL',
      style: TextStyle(
        fontSize: faceRadius * 0.95,
        fontWeight: FontWeight.w900,
        height: 1.0,
        letterSpacing: -0.5,
        color: amberDark.withValues(alpha: 0.8),
      ),
    );
    final markPainter = TextPainter(
      text: markSpan,
      textDirection: TextDirection.ltr,
    )..layout();
    markPainter.paint(
      canvas,
      center - Offset(markPainter.width / 2, markPainter.height / 2),
    );

    // Highlight: a small bright arc top-left, the "shine" that sells
    // a metallic/embossed surface rather than a painted-on flat icon.
    final highlightPaint = Paint()
      ..style = PaintingStyle.stroke
      ..strokeCap = StrokeCap.round
      ..strokeWidth = math.max(0.8, size.width * 0.07)
      ..color = Colors.white.withValues(alpha: 0.55);
    canvas.drawArc(
      Rect.fromCircle(center: center, radius: faceRadius * 0.82),
      math.pi * 1.05,
      math.pi * 0.35,
      false,
      highlightPaint,
    );
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}

/// The balance pill: [CoinIcon] + count, in the amber-bordered chip
/// used on the hub screen's app bar and now also each gameplay
/// screen's HUD row. Purely a display — nothing here spends or earns
/// coins.
class CoinBadge extends StatelessWidget {
  const CoinBadge({super.key, required this.balance, this.iconSize = 18});

  final int balance;
  final double iconSize;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: ConvoyColors.surfaceElevated,
        borderRadius: BorderRadius.circular(4),
        border: Border.all(color: ConvoyColors.amber),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          CoinIcon(size: iconSize),
          const SizedBox(width: 6),
          Text('$balance', style: ConvoyTypography.hudMedium),
        ],
      ),
    );
  }
}
