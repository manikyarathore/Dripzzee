import 'dart:math' as math;

import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';

class _Tile {
  const _Tile(this.prompt, this.icon, this.colors);
  final String prompt;
  final IconData icon;
  final List<Color> colors;
}

/// Fashion imagery for the login background. These are AI-generated test
/// images (pollinations.ai). Swap [_imageUrl] for your own brand photos
/// (e.g. Firebase Storage links) before launch.
const _tiles = <_Tile>[
  _Tile('woman twirling in marigold mirror-work chaniya choli at garba night, festive lights',
      Icons.celebration_outlined, [Color(0xFFFFC857), Color(0xFFE5484D)]),
  _Tile('stylish young man in oversized streetwear hoodie and cargo pants, city street',
      Icons.checkroom_outlined, [Color(0xFF7CB7FF), Color(0xFF3949AB)]),
  _Tile('clean white sneakers on pastel background, product photo',
      Icons.directions_run_rounded, [Color(0xFF5EEAD4), Color(0xFF0F766E)]),
  _Tile('oxidised silver jhumka earrings close-up, soft light',
      Icons.diamond_outlined, [Color(0xFFE9C46A), Color(0xFF9C6B1F)]),
  _Tile('woman in elegant chikankari white kurta, sunlit courtyard',
      Icons.dry_cleaning_outlined, [Color(0xFFF1E7D0), Color(0xFFB9A3E3)]),
  _Tile('man in royal blue silk kurta and nehru jacket, festive portrait',
      Icons.man_2_outlined, [Color(0xFF7C9CFF), Color(0xFF1F2A55)]),
  _Tile('flat lay of denim jacket, jeans and accessories, editorial',
      Icons.style_outlined, [Color(0xFF4A6FA5), Color(0xFF1F2A55)]),
  _Tile('woman in red bandhani lehenga with dandiya sticks, joyful dance',
      Icons.auto_awesome_outlined, [Color(0xFFFF8FB8), Color(0xFFC2185B)]),
  _Tile('boutique clothing rack with colourful Indian ethnic wear, warm light',
      Icons.storefront_outlined, [Color(0xFFD9A7FF), Color(0xFF6D28D9)]),
  _Tile('woman in linen co-ord set, minimal fashion editorial, beige tones',
      Icons.woman_2_outlined, [Color(0xFFD9C7A8), Color(0xFF7B5236)]),
  _Tile('embroidered golden juttis footwear product photo',
      Icons.hiking_rounded, [Color(0xFFFFD27A), Color(0xFFB8327A)]),
  _Tile('young woman in purple satin slip dress, night party fashion',
      Icons.nightlife_rounded, [Color(0xFFB57BFF), Color(0xFF4A148C)]),
];

String _imageUrl(int i) =>
    'https://image.pollinations.ai/prompt/${Uri.encodeComponent('fashion photo, ${_tiles[i].prompt}, high quality, no text')}'
    '?width=360&height=500&seed=${700 + i}&model=flux&nologo=true';

/// Three columns of fashion tiles drifting up/down at different speeds.
/// Pauses with reduced motion and when the screen isn't visible.
class FashionMosaic extends StatefulWidget {
  const FashionMosaic({super.key});

  @override
  State<FashionMosaic> createState() => _FashionMosaicState();
}

class _FashionMosaicState extends State<FashionMosaic>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller = AnimationController(
    vsync: this,
    duration: const Duration(seconds: 60),
  );

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (MediaQuery.disableAnimationsOf(context)) {
      _controller.stop();
    } else if (!_controller.isAnimating) {
      _controller.repeat();
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return RepaintBoundary(
      child: LayoutBuilder(
        builder: (context, box) {
          const gap = 10.0;
          final colWidth = (box.maxWidth - gap * 4) / 3;
          final tileHeight = colWidth * 1.38;
          return ClipRect(
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                for (var c = 0; c < 3; c++) ...[
                  const SizedBox(width: gap),
                  SizedBox(
                    width: colWidth,
                    height: box.maxHeight,
                    child: _Column(
                      animation: _controller,
                      tiles: [for (var i = c; i < _tiles.length; i += 3) i],
                      tileHeight: tileHeight,
                      gap: gap,
                      viewport: box.maxHeight,
                      speed: const [1.0, 0.7, 1.25][c],
                      downward: c == 1,
                      phase: c * 0.33,
                    ),
                  ),
                ],
              ],
            ),
          );
        },
      ),
    );
  }
}

class _Column extends StatelessWidget {
  const _Column({
    required this.animation,
    required this.tiles,
    required this.tileHeight,
    required this.gap,
    required this.viewport,
    required this.speed,
    required this.downward,
    required this.phase,
  });

  final Animation<double> animation;
  final List<int> tiles;
  final double tileHeight;
  final double gap;
  final double viewport;
  final double speed;
  final bool downward;
  final double phase;

  @override
  Widget build(BuildContext context) {
    final cycle = tiles.length * (tileHeight + gap);
    final repeats = (viewport / cycle).ceil() + 2;
    final column = Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        for (var r = 0; r < repeats; r++)
          for (final i in tiles)
            Padding(
              padding: EdgeInsets.only(bottom: gap),
              child: SizedBox(height: tileHeight, child: _TileView(index: i)),
            ),
      ],
    );
    return OverflowBox(
      alignment: Alignment.topCenter,
      maxHeight: double.infinity,
      child: AnimatedBuilder(
        animation: animation,
        child: column,
        builder: (context, child) {
          final travel = ((animation.value * speed * 3 + phase) % 1.0) * cycle;
          final dy = downward ? travel - cycle : -travel;
          return Transform.translate(offset: Offset(0, dy), child: child);
        },
      ),
    );
  }
}

class _TileView extends StatelessWidget {
  const _TileView({required this.index});

  final int index;

  @override
  Widget build(BuildContext context) {
    final tile = _tiles[index];
    final fallback = DecoratedBox(
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: tile.colors,
        ),
      ),
      child: Center(
        child: Transform.rotate(
          angle: -math.pi / 18,
          child: Icon(tile.icon, size: 40, color: Colors.white.withValues(alpha: 0.85)),
        ),
      ),
    );
    return ClipRRect(
      borderRadius: BorderRadius.circular(18),
      child: CachedNetworkImage(
        imageUrl: _imageUrl(index),
        fit: BoxFit.cover,
        memCacheWidth: 400,
        fadeInDuration: const Duration(milliseconds: 500),
        placeholder: (_, __) => fallback,
        errorWidget: (_, __, ___) => fallback,
      ),
    );
  }
}
