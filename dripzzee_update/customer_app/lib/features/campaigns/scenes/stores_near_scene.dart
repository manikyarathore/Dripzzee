import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../../../core/theme/app_theme.dart';
import '../campaign.dart';

double _iv(double t, double a, double b) => ((t - a) / (b - a)).clamp(0.0, 1.0);

/// Pin → boutique → festive outfits → shopper: the Dripzzee loop in 4 s.
class StoresNearScene extends StatelessWidget {
  const StoresNearScene({super.key, required this.active});

  final bool active;

  @override
  Widget build(BuildContext context) {
    return LoopingScene(
      active: active,
      duration: const Duration(milliseconds: 4200),
      staticValue: 0.88,
      builder: (context, t) => LayoutBuilder(
        builder: (context, c) => _Frame(t: t, size: c.biggest),
      ),
    );
  }
}

class _Frame extends StatelessWidget {
  const _Frame({required this.t, required this.size});

  final double t;
  final Size size;

  @override
  Widget build(BuildContext context) {
    final w = size.width;
    final h = size.height;
    final pin = Offset(w * 0.18, h * 0.70);
    final store = Offset(w * 0.52, h * 0.30);
    final shopper = Offset(w * 0.82, h * 0.70);

    final fade = t > 0.93 ? 1 - _iv(t, 0.93, 1.0) : 1.0;
    final storePop = Curves.easeOutBack.transform(_iv(t, 0.25, 0.42));
    final cardsOut = Curves.easeOutCubic.transform(_iv(t, 0.40, 0.60));
    final shopperPop = Curves.easeOutBack.transform(_iv(t, 0.78, 0.9));
    final bob = math.sin(t * 4 * math.pi) * 3;

    Widget at(Offset p, double box, Widget child) => Positioned(
          left: p.dx - box / 2,
          top: p.dy - box / 2,
          width: box,
          height: box,
          child: child,
        );

    const outfitColors = [
      AppColors.marigold,
      Color(0xFFE5484D),
      Color(0xFF12A594),
    ];

    return Opacity(
      opacity: fade,
      child: Stack(
        clipBehavior: Clip.none,
        children: [
          Positioned.fill(
            child: CustomPaint(
              painter: _RoutePainter(
                pin: pin,
                store: store,
                shopper: shopper,
                first: _iv(t, 0.0, 0.32),
                second: _iv(t, 0.55, 0.82),
              ),
            ),
          ),
          // Pulsing ring + pin
          at(
            pin,
            46,
            Center(
              child: Container(
                width: 20 + 20 * _iv((t * 2) % 1, 0, 1),
                height: 20 + 20 * _iv((t * 2) % 1, 0, 1),
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  border: Border.all(
                    color: AppColors.marigold
                        .withValues(alpha: 0.5 * (1 - (t * 2) % 1)),
                  ),
                ),
              ),
            ),
          ),
          at(
            pin.translate(0, -12 + bob),
            30,
            const Icon(Icons.location_on_rounded,
                color: AppColors.marigold, size: 30),
          ),
          // Boutique
          at(
            store,
            48,
            Transform.scale(
              scale: storePop,
              child: Container(
                decoration: BoxDecoration(
                  color: AppColors.panelHover,
                  shape: BoxShape.circle,
                  border: Border.all(color: AppColors.shopper),
                ),
                child: Icon(Icons.storefront_rounded,
                    color: AppColors.shopper, size: 24),
              ),
            ),
          ),
          // Festive outfit cards fanning out of the store
          for (var i = 0; i < 3; i++)
            at(
              store.translate(
                (i - 1) * 30 * cardsOut,
                -8 + 40 * cardsOut + (i == 1 ? 8 * cardsOut : 0),
              ),
              28,
              Opacity(
                opacity: cardsOut,
                child: Transform.rotate(
                  angle: (i - 1) * 0.22 * cardsOut,
                  child: Container(
                    margin: const EdgeInsets.symmetric(horizontal: 3),
                    decoration: BoxDecoration(
                      color: outfitColors[i],
                      borderRadius: BorderRadius.circular(6),
                    ),
                    child: Icon(Icons.checkroom_rounded,
                        size: 14, color: AppColors.ink),
                  ),
                ),
              ),
            ),
          // Shopper
          at(
            shopper,
            42,
            Transform.scale(
              scale: shopperPop,
              child: Container(
                decoration: BoxDecoration(
                  color: AppColors.shopperSoft,
                  shape: BoxShape.circle,
                  border: Border.all(color: AppColors.shopper.withValues(alpha: 0.6)),
                ),
                child: Icon(Icons.shopping_bag_rounded,
                    color: AppColors.paper, size: 20),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _RoutePainter extends CustomPainter {
  _RoutePainter({
    required this.pin,
    required this.store,
    required this.shopper,
    required this.first,
    required this.second,
  });

  final Offset pin;
  final Offset store;
  final Offset shopper;
  final double first;
  final double second;

  void _dashed(Canvas canvas, Path path, double progress, Paint paint) {
    if (progress <= 0) return;
    for (final m in path.computeMetrics()) {
      final end = m.length * progress;
      var d = 0.0;
      while (d < end) {
        final seg = math.min(6.0, end - d);
        canvas.drawPath(m.extractPath(d, d + seg), paint);
        d += 10;
      }
    }
  }

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 2
      ..strokeCap = StrokeCap.round
      ..color = AppColors.shopper.withValues(alpha: 0.7);
    final a = Path()
      ..moveTo(pin.dx, pin.dy - 14)
      ..quadraticBezierTo(pin.dx, store.dy, store.dx - 26, store.dy);
    final b = Path()
      ..moveTo(store.dx + 26, store.dy)
      ..quadraticBezierTo(shopper.dx, store.dy, shopper.dx, shopper.dy - 22);
    _dashed(canvas, a, first, paint);
    _dashed(canvas, b, second, paint);
  }

  @override
  bool shouldRepaint(covariant _RoutePainter old) =>
      old.first != first ||
      old.second != second ||
      old.pin != pin ||
      old.store != store ||
      old.shopper != shopper;
}
