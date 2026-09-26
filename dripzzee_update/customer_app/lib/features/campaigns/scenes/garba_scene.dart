import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../../../core/theme/app_theme.dart';
import '../campaign.dart';

/// A twirling chaniya choli with swaying dupatta and dandiya sticks that
/// meet on the beat. Pure CustomPainter — no image assets, one controller.
class GarbaScene extends StatelessWidget {
  const GarbaScene({super.key, required this.active});

  final bool active;

  @override
  Widget build(BuildContext context) {
    return LoopingScene(
      active: active,
      duration: const Duration(milliseconds: 2600),
      builder: (context, t) => CustomPaint(
        painter: _GarbaPainter(t),
        size: Size.infinite,
      ),
    );
  }
}

class _GarbaPainter extends CustomPainter {
  _GarbaPainter(this.t);

  final double t;

  static const _skin = Color(0xFFB9825F);
  static const _hair = Color(0xFF231C25);
  static const _choli = Color(0xFFE5484D);
  static const _pleat = Color(0xFFB9791F);

  @override
  void paint(Canvas canvas, Size size) {
    final w = size.width;
    final h = size.height;
    final s = math.min(w, h);
    final cx = w * 0.5;
    final phase = t * 2 * math.pi;
    final twirl = math.sin(phase);
    final swing = math.sin(phase * 2);
    final floorY = h * 0.86;

    // Floor glow
    canvas.drawOval(
      Rect.fromCenter(
        center: Offset(cx, floorY + 4),
        width: s * (0.72 + 0.08 * twirl),
        height: s * 0.07,
      ),
      Paint()..color = AppColors.shopper.withValues(alpha: 0.10),
    );

    // Skirt (flare breathes with the twirl)
    final waistY = h * 0.47;
    final waistHalf = s * 0.075;
    final hemHalf = s * (0.30 + 0.05 * twirl);
    final hemY = floorY - s * 0.02;
    const scallops = 6;
    final step = hemHalf * 2 / scallops;

    final hem = Path()..moveTo(cx - hemHalf, hemY);
    for (var i = 0; i < scallops; i++) {
      final x0 = cx - hemHalf + step * i;
      hem.quadraticBezierTo(
        x0 + step / 2,
        hemY + s * 0.035 * (1 + 0.3 * math.sin(phase * 2 + i)),
        x0 + step,
        hemY,
      );
    }
    final skirt = Path()
      ..moveTo(cx - waistHalf, waistY)
      ..lineTo(cx - hemHalf, hemY)
      ..extendWithPath(hem, Offset.zero)
      ..lineTo(cx + waistHalf, waistY)
      ..close();
    canvas.drawPath(skirt, Paint()..color = AppColors.marigold);

    // Pleats drift sideways → the skirt reads as spinning.
    final pleat = Paint()..strokeWidth = 1.2;
    for (var k = 0; k < 7; k++) {
      final f = ((k / 7) + t) % 1.0;
      final x = -1 + 2 * f;
      pleat.color = _pleat.withValues(alpha: 0.25 + 0.5 * (1 - x.abs()));
      canvas.drawLine(
        Offset(cx + x * waistHalf * 0.9, waistY + 2),
        Offset(cx + x * hemHalf * 0.95, hemY),
        pleat,
      );
    }

    // Hem border + twinkling mirror work
    canvas.drawPath(
      hem,
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = s * 0.022
        ..color = _choli,
    );
    for (var i = 0; i < 6; i++) {
      final x = cx - hemHalf * 0.8 + i * (hemHalf * 1.6 / 5);
      final alpha = 0.35 + 0.65 * ((math.sin(phase * 3 + i * 1.3) + 1) / 2);
      canvas.drawCircle(
        Offset(x, hemY - s * 0.06),
        s * 0.011,
        Paint()..color = AppColors.paper.withValues(alpha: alpha),
      );
    }

    // Choli + head
    canvas.drawRRect(
      RRect.fromRectAndRadius(
        Rect.fromLTRB(cx - s * 0.075, h * 0.28, cx + s * 0.075, waistY + 1),
        const Radius.circular(6),
      ),
      Paint()..color = _choli,
    );
    canvas.drawCircle(Offset(cx, h * 0.19), s * 0.062, Paint()..color = _skin);
    canvas.drawArc(
      Rect.fromCircle(center: Offset(cx, h * 0.185), radius: s * 0.066),
      math.pi * 1.05,
      math.pi * 0.9,
      true,
      Paint()..color = _hair,
    );
    canvas.drawCircle(
      Offset(cx + s * 0.05, h * 0.13),
      s * 0.03,
      Paint()..color = _hair,
    );

    // Arms + dandiya sticks
    final shoulderL = Offset(cx - s * 0.07, h * 0.30);
    final shoulderR = Offset(cx + s * 0.07, h * 0.30);
    final handL = Offset(cx - s * 0.20, h * (0.23 - 0.02 * swing));
    final handR = Offset(cx + s * 0.20, h * (0.23 + 0.02 * swing));
    final arm = Paint()
      ..color = _skin
      ..strokeWidth = s * 0.028
      ..strokeCap = StrokeCap.round;
    canvas.drawLine(shoulderL, handL, arm);
    canvas.drawLine(shoulderR, handR, arm);

    final stickLen = s * 0.2;
    final aL = -math.pi / 3 + 0.35 * swing;
    final aR = -2 * math.pi / 3 - 0.35 * swing;
    final tipL = handL + Offset(math.cos(aL), math.sin(aL)) * stickLen;
    final tipR = handR + Offset(math.cos(aR), math.sin(aR)) * stickLen;
    final stick = Paint()
      ..color = AppColors.paper
      ..strokeWidth = s * 0.02
      ..strokeCap = StrokeCap.round;
    canvas.drawLine(handL, tipL, stick);
    canvas.drawLine(handR, tipR, stick);
    final band = Paint()
      ..color = AppColors.shopper
      ..strokeWidth = s * 0.024
      ..strokeCap = StrokeCap.butt;
    canvas.drawLine(
      Offset.lerp(handL, tipL, 0.45)!,
      Offset.lerp(handL, tipL, 0.6)!,
      band,
    );
    canvas.drawLine(
      Offset.lerp(handR, tipR, 0.45)!,
      Offset.lerp(handR, tipR, 0.6)!,
      band,
    );

    // Clack sparkle when the sticks meet.
    if (swing > 0.8) {
      final k = (swing - 0.8) / 0.2;
      final mid = Offset.lerp(tipL, tipR, 0.5)!;
      final spark = Paint()
        ..color = AppColors.marigold.withValues(alpha: k)
        ..strokeWidth = 1.6
        ..strokeCap = StrokeCap.round;
      for (var i = 0; i < 6; i++) {
        final a = i * math.pi / 3;
        final dir = Offset(math.cos(a), math.sin(a));
        canvas.drawLine(mid + dir * (s * 0.03), mid + dir * (s * (0.03 + 0.04 * k)), spark);
      }
    }

    // Dupatta over the shoulder, trailing with the spin.
    final sway = math.sin(phase + 0.8);
    final dupatta = Path()
      ..moveTo(shoulderL.dx, shoulderL.dy)
      ..cubicTo(
        cx + s * 0.10,
        h * (0.24 + 0.04 * sway),
        cx + s * 0.30,
        h * (0.46 - 0.06 * sway),
        cx + s * (0.40 + 0.03 * sway),
        h * (0.62 + 0.05 * sway),
      );
    canvas.drawPath(
      dupatta,
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = s * 0.045
        ..strokeCap = StrokeCap.round
        ..color = AppColors.shopper.withValues(alpha: 0.8),
    );
    canvas.drawPath(
      dupatta,
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = s * 0.01
        ..color = AppColors.paper.withValues(alpha: 0.35),
    );
  }

  @override
  bool shouldRepaint(covariant _GarbaPainter oldDelegate) => oldDelegate.t != t;
}
