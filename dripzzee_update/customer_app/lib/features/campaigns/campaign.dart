import 'package:flutter/material.dart';

import '../../core/theme/app_theme.dart';
import '../../core/widgets/pressable.dart';

/// A slide renders its own scene and knows where tapping it leads.
/// [active] is true only for the page currently in view, so off-screen
/// scenes don't animate.
typedef CampaignSlideBuilder = Widget Function(BuildContext context, bool active);

/// A time-boxed promotional campaign shown between Search and Categories on
/// Home. To replace Navratri, create another Campaign and add it to
/// [kCampaigns] — nothing else in the app references a specific festival.
class Campaign {
  const Campaign({
    required this.id,
    required this.startsAt,
    required this.endsAt,
    required this.slides,
  });

  final String id;
  final DateTime startsAt;
  final DateTime endsAt;
  final List<CampaignSlideBuilder> slides;

  bool isLive(DateTime now) => !now.isBefore(startsAt) && now.isBefore(endsAt);
}

/// Shared card chrome: copy on the left, animated scene on the right.
class CampaignCard extends StatelessWidget {
  const CampaignCard({
    super.key,
    required this.eyebrow,
    required this.title,
    required this.subtitle,
    required this.ctaLabel,
    required this.accent,
    required this.scene,
    required this.onTap,
  });

  final String eyebrow;
  final String title;
  final String subtitle;
  final String ctaLabel;
  final Color accent;
  final Widget scene;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Pressable(
      scale: 0.985,
      semanticLabel: '$title. $subtitle',
      onTap: onTap,
      child: Container(
        margin: const EdgeInsets.symmetric(horizontal: 5),
        decoration: BoxDecoration(
          color: AppColors.panel,
          borderRadius: BorderRadius.circular(AppRadius.lg),
          border: Border.all(color: AppColors.line),
        ),
        clipBehavior: Clip.antiAlias,
        child: Row(
          children: [
            Expanded(
              flex: 11,
              child: Padding(
                padding: const EdgeInsets.fromLTRB(16, 16, 4, 16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      eyebrow,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: AppTextStyles.mono(
                        size: 10,
                        color: accent,
                        weight: FontWeight.w700,
                      ),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      title,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: AppTextStyles.heading(size: 23, height: 1.05),
                    ),
                    const SizedBox(height: 6),
                    Text(
                      subtitle,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: AppTextStyles.body(
                        size: 12,
                        color: AppColors.mute,
                        height: 1.3,
                      ),
                    ),
                    const Spacer(),
                    Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 12, vertical: 7),
                      decoration: BoxDecoration(
                        borderRadius: BorderRadius.circular(999),
                        border: Border.all(color: accent.withValues(alpha: 0.6)),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Flexible(
                            child: Text(
                              ctaLabel,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: AppTextStyles.body(
                                size: 12,
                                weight: FontWeight.w700,
                                color: accent,
                              ),
                            ),
                          ),
                          const SizedBox(width: 4),
                          Icon(Icons.arrow_forward_rounded,
                              size: 14, color: accent),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ),
            Expanded(flex: 9, child: scene),
          ],
        ),
      ),
    );
  }
}

/// Runs a looping animation only while [active] and animations are allowed
/// (respects the system "remove animations" setting). The controller lives
/// and dies with this widget; TickerMode pauses it in hidden tabs.
class LoopingScene extends StatefulWidget {
  const LoopingScene({
    super.key,
    required this.active,
    required this.duration,
    required this.builder,
    this.staticValue = 0.35,
  });

  final bool active;
  final Duration duration;
  final double staticValue;
  final Widget Function(BuildContext context, double t) builder;

  @override
  State<LoopingScene> createState() => _LoopingSceneState();
}

class _LoopingSceneState extends State<LoopingScene>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller =
      AnimationController(vsync: this, duration: widget.duration)
        ..value = widget.staticValue;
  bool _reduceMotion = false;

  void _sync() {
    final shouldRun = widget.active && !_reduceMotion;
    if (shouldRun && !_controller.isAnimating) {
      _controller.repeat();
    } else if (!shouldRun && _controller.isAnimating) {
      _controller.stop();
      if (_reduceMotion) _controller.value = widget.staticValue;
    }
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _reduceMotion = MediaQuery.disableAnimationsOf(context);
    _sync();
  }

  @override
  void didUpdateWidget(covariant LoopingScene oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.duration != widget.duration) {
      _controller.duration = widget.duration;
    }
    _sync();
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return RepaintBoundary(
      child: AnimatedBuilder(
        animation: _controller,
        builder: (context, _) => widget.builder(context, _controller.value),
      ),
    );
  }
}
