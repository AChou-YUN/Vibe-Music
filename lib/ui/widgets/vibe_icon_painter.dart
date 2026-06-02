import 'dart:math' as math;
import 'package:flutter/material.dart';

/// Paints the Vibe Music icon: dark rounded square, orange "V" with glow, music bars.
class VibeIconPainter extends CustomPainter {
  final double progress; // 0-1 for entrance animation

  VibeIconPainter({this.progress = 1.0});

  @override
  void paint(Canvas canvas, Size size) {
    final s = math.min(size.width, size.height);
    final pad = s * 0.04;
    final inner = s - pad * 2;

    // Background rounded rect — matches AppColors.background #0D0D0D
    final bgRect = RRect.fromRectAndRadius(
      Offset(pad, pad) & Size(inner, inner),
      Radius.circular(inner * 0.22),
    );
    canvas.drawRRect(bgRect, Paint()..color = const Color(0xFF0D0D0D));

    // --- "V" letter ---
    final vCenterX = pad + inner * 0.50;
    final vBaselineY = pad + inner * 0.50;
    final vFontSize = inner * 0.50;

    // Glow layer
    final glowPainter = TextPainter(
      text: TextSpan(
        text: 'V',
        style: TextStyle(
          fontSize: vFontSize,
          fontWeight: FontWeight.w900,
          color: const Color(0xFFFF7A40),
          shadows: [
            Shadow(blurRadius: vFontSize * 0.14, color: const Color(0xFFFF6B00).withOpacity(0.60)),
            Shadow(blurRadius: vFontSize * 0.28, color: const Color(0xFFFF6B00).withOpacity(0.35)),
            Shadow(blurRadius: vFontSize * 0.50, color: const Color(0xFFFF6B00).withOpacity(0.18)),
          ],
        ),
      ),
      textDirection: TextDirection.ltr,
    )..layout();
    glowPainter.paint(
      canvas,
      Offset(vCenterX - glowPainter.width / 2, vBaselineY - glowPainter.height * 0.78),
    );

    // Crisp V
    final vPainter = TextPainter(
      text: TextSpan(
        text: 'V',
        style: TextStyle(
          fontSize: vFontSize,
          fontWeight: FontWeight.w900,
          color: const Color(0xFFFF7A40),
        ),
      ),
      textDirection: TextDirection.ltr,
    )..layout();
    vPainter.paint(
      canvas,
      Offset(vCenterX - vPainter.width / 2, vBaselineY - vPainter.height * 0.78),
    );

    // --- Music bars ---
    final barWidth = inner * 0.045;
    final barGap = inner * 0.088;
    final barRadius = Radius.circular(barWidth * 0.5);
    final barsY = pad + inner * 0.78;

    final barHeights = <double>[
      inner * 0.045,
      inner * 0.070,
      inner * 0.100,
      inner * 0.130,
      inner * 0.100,
      inner * 0.070,
      inner * 0.045,
    ];
    final barOpacities = [0.40, 0.55, 0.75, 1.0, 0.75, 0.55, 0.40];
    final totalBarsWidth = 7 * barWidth + 6 * (barGap - barWidth);
    final barsStartX = vCenterX - totalBarsWidth / 2;

    for (int i = 0; i < 7; i++) {
      final bx = barsStartX + i * barGap;
      final bh = barHeights[i] * progress;
      final barRect = RRect.fromRectAndRadius(
        Rect.fromLTWH(bx, barsY - bh, barWidth, bh),
        barRadius,
      );
      final barPaint = Paint()
        ..shader = LinearGradient(
          begin: Alignment.bottomCenter,
          end: Alignment.topCenter,
          colors: const [Color(0xFFFF6B35), Color(0xFFFFB07A)],
        ).createShader(Rect.fromLTWH(bx, barsY - bh, barWidth, bh))
        ..color = Colors.orange.withOpacity(barOpacities[i]);
      canvas.drawRRect(barRect, barPaint);
    }
  }

  @override
  bool shouldRepaint(covariant VibeIconPainter oldDelegate) =>
      oldDelegate.progress != progress;
}

/// Widget wrapper for the icon.
class VibeIcon extends StatelessWidget {
  final double size;
  final double progress;

  const VibeIcon({super.key, this.size = 80, this.progress = 1.0});

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: size,
      height: size,
      child: CustomPaint(
        painter: VibeIconPainter(progress: progress),
      ),
    );
  }
}
