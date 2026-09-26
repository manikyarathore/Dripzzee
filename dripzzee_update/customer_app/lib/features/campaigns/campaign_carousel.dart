import 'dart:async';

import 'package:flutter/material.dart';

import '../../core/theme/app_theme.dart';
import 'campaign.dart';
import 'navratri_campaign.dart';

/// Every campaign the app knows about. Only the one live right now shows.
final List<Campaign> kCampaigns = [navratriCampaign];

Campaign? liveCampaign(DateTime now) {
  for (final c in kCampaigns) {
    if (c.isLive(now) && c.slides.isNotEmpty) return c;
  }
  return null;
}

/// Auto-advancing promo carousel (Home, between Search and Categories).
/// Auto-advance pauses while the user drags, when the tab is hidden, and when
/// the system asks for reduced motion.
class CampaignCarousel extends StatefulWidget {
  const CampaignCarousel({super.key});

  @override
  State<CampaignCarousel> createState() => _CampaignCarouselState();
}

class _CampaignCarouselState extends State<CampaignCarousel> {
  // Starts far from 0 so the carousel can loop forever in both directions.
  static const _loopBase = 1000;
  late final _controller = PageController(
    viewportFraction: 0.92,
    initialPage: _count * _loopBase,
  );
  final Campaign? _campaign = liveCampaign(DateTime.now());
  Timer? _timer;
  int _page = 0;
  bool _dragging = false;
  bool _tickersOn = true;
  bool _reduceMotion = false;

  int get _count => _campaign?.slides.length ?? 0;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _tickersOn = TickerMode.valuesOf(context).enabled;
    _reduceMotion = MediaQuery.disableAnimationsOf(context);
    _restartTimer();
  }

  void _restartTimer() {
    _timer?.cancel();
    _timer = null;
    if (_count < 2 || !_tickersOn || _reduceMotion) return;
    _timer = Timer.periodic(const Duration(milliseconds: 4500), (_) {
      if (!mounted || _dragging || !_controller.hasClients) return;
      _controller.nextPage(
        duration: const Duration(milliseconds: 650),
        curve: Curves.easeInOutCubic,
      );
    });
  }

  @override
  void dispose() {
    _timer?.cancel();
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final campaign = _campaign;
    if (campaign == null) return const SizedBox.shrink();

    return MediaQuery.withClampedTextScaling(
      maxScaleFactor: 1.15,
      child: Padding(
        padding: const EdgeInsets.only(top: 16),
        child: Column(
          children: [
            SizedBox(
              height: 196,
              child: NotificationListener<ScrollNotification>(
                onNotification: (n) {
                  if (n is ScrollStartNotification && n.dragDetails != null) {
                    _dragging = true;
                  } else if (n is ScrollEndNotification && _dragging) {
                    _dragging = false;
                    _restartTimer();
                  }
                  return false;
                },
                child: PageView.builder(
                  controller: _controller,
                  onPageChanged: (i) => setState(() => _page = i % _count),
                  itemBuilder: (context, i) => campaign.slides[i % _count](
                    context,
                    i % _count == _page && _tickersOn,
                  ),
                ),
              ),
            ),
            if (_count > 1) ...[
              const SizedBox(height: 10),
              Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  for (var i = 0; i < _count; i++)
                    AnimatedContainer(
                      duration: const Duration(milliseconds: 250),
                      margin: const EdgeInsets.symmetric(horizontal: 3),
                      width: i == _page ? 18 : 6,
                      height: 6,
                      decoration: BoxDecoration(
                        color: i == _page ? AppColors.shopper : AppColors.faint,
                        borderRadius: BorderRadius.circular(3),
                      ),
                    ),
                ],
              ),
            ],
          ],
        ),
      ),
    );
  }
}
