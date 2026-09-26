import 'package:flutter/material.dart';

import '../../../core/theme/app_theme.dart';

class NightLook {
  const NightLook(this.night, this.colour, this.swatch, this.icon, this.look);

  final int night;

  /// Must match the colour names retailers use on products (`colors` field).
  final String colour;
  final Color swatch;
  final IconData icon;
  final String look;
}

/// A festive palette for the nine nights. Colour-of-the-day traditions vary
/// by year and region, so this is styling inspiration, not a calendar.
const kNineLooks = <NightLook>[
  NightLook(1, 'Marigold', Color(0xFFF5B942), Icons.checkroom_outlined, 'Mirror-work chaniya'),
  NightLook(2, 'Ivory', Color(0xFFEDE6D8), Icons.dry_cleaning_outlined, 'Chikankari kurta'),
  NightLook(3, 'Red', Color(0xFFE5484D), Icons.auto_awesome_outlined, 'Bandhani lehenga'),
  NightLook(4, 'Royal Blue', Color(0xFF3E63DD), Icons.checkroom_outlined, 'Silk kediyu'),
  NightLook(5, 'Yellow', Color(0xFFF7D154), Icons.diamond_outlined, 'Oxidised jhumkas'),
  NightLook(6, 'Green', Color(0xFF46A758), Icons.checkroom_outlined, 'Leheriya dupatta'),
  NightLook(7, 'Grey', Color(0xFF9B9A9E), Icons.dry_cleaning_outlined, 'Indo-western set'),
  NightLook(8, 'Purple', Color(0xFF8E4EC6), Icons.checkroom_outlined, 'Gota-patti choli'),
  NightLook(9, 'Peacock Green', Color(0xFF12A594), Icons.auto_awesome_outlined, 'Kutch-work lehenga'),
];

Color _onSwatch(Color c) => c.computeLuminance() > 0.45
    ? const Color(0xFF141217)
    : const Color(0xFFF7F5FA);

/// Stacked look cards; the front card swaps each night with a slide/tilt.
class NineLooksScene extends StatelessWidget {
  const NineLooksScene({super.key, required this.index});

  final int index;

  @override
  Widget build(BuildContext context) {
    final look = kNineLooks[index];
    final next = kNineLooks[(index + 1) % kNineLooks.length];
    final after = kNineLooks[(index + 2) % kNineLooks.length];

    return LayoutBuilder(builder: (context, c) {
      final cardW = c.maxWidth * 0.62;
      final cardH = c.maxHeight * 0.64;
      return Stack(
        alignment: Alignment.center,
        children: [
          Positioned(
            top: c.maxHeight * 0.1,
            child: Transform.rotate(
              angle: 0.16,
              child: _GhostCard(width: cardW, height: cardH, color: after.swatch),
            ),
          ),
          Positioned(
            top: c.maxHeight * 0.09,
            child: Transform.rotate(
              angle: -0.09,
              child: _GhostCard(width: cardW, height: cardH, color: next.swatch),
            ),
          ),
          Positioned(
            top: c.maxHeight * 0.08,
            child: AnimatedSwitcher(
              duration: const Duration(milliseconds: 520),
              switchInCurve: Curves.easeOutCubic,
              switchOutCurve: Curves.easeInCubic,
              transitionBuilder: (child, animation) => FadeTransition(
                opacity: animation,
                child: SlideTransition(
                  position: Tween(
                    begin: const Offset(0.35, 0.05),
                    end: Offset.zero,
                  ).animate(animation),
                  child: child,
                ),
              ),
              child: _LookCard(
                key: ValueKey(index),
                look: look,
                width: cardW,
                height: cardH,
              ),
            ),
          ),
          Positioned(
            bottom: c.maxHeight * 0.08,
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                for (var i = 0; i < kNineLooks.length; i++)
                  AnimatedContainer(
                    duration: const Duration(milliseconds: 300),
                    margin: const EdgeInsets.symmetric(horizontal: 2),
                    width: i == index ? 10 : 5,
                    height: 5,
                    decoration: BoxDecoration(
                      color: i == index
                          ? kNineLooks[i].swatch
                          : kNineLooks[i].swatch.withValues(alpha: 0.35),
                      borderRadius: BorderRadius.circular(3),
                    ),
                  ),
              ],
            ),
          ),
        ],
      );
    });
  }
}

class _GhostCard extends StatelessWidget {
  const _GhostCard({
    required this.width,
    required this.height,
    required this.color,
  });

  final double width;
  final double height;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: width,
      height: height,
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.28),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: color.withValues(alpha: 0.4)),
      ),
    );
  }
}

class _LookCard extends StatelessWidget {
  const _LookCard({
    super.key,
    required this.look,
    required this.width,
    required this.height,
  });

  final NightLook look;
  final double width;
  final double height;

  @override
  Widget build(BuildContext context) {
    final fg = _onSwatch(look.swatch);
    return Container(
      width: width,
      height: height,
      padding: const EdgeInsets.all(10),
      decoration: BoxDecoration(
        color: look.swatch,
        borderRadius: BorderRadius.circular(14),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'NIGHT 0${look.night}',
            style: AppTextStyles.mono(size: 9, color: fg, weight: FontWeight.w700),
          ),
          Expanded(
            child: Center(
              child: Icon(look.icon, size: 34, color: fg.withValues(alpha: 0.8)),
            ),
          ),
          Text(
            look.colour,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: AppTextStyles.body(size: 12, weight: FontWeight.w800, color: fg),
          ),
        ],
      ),
    );
  }
}
