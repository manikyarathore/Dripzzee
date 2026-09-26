import 'package:flutter/material.dart';
import 'package:flutter/semantics.dart';
import 'package:flutter/services.dart';

import '../theme/app_theme.dart';

/// A track with a centre handle: drag right to [onSwipeRight] (e.g. Buy now),
/// drag left to [onSwipeLeft] (e.g. Add to cart). Tapping either label does
/// the same, so it's also accessible without swiping.
class SwipeActionBar extends StatefulWidget {
  const SwipeActionBar({
    super.key,
    required this.leftLabel,
    required this.rightLabel,
    required this.onSwipeLeft,
    required this.onSwipeRight,
    this.leftIcon = Icons.add_shopping_cart_rounded,
    this.rightIcon = Icons.bolt_rounded,
    this.enabled = true,
    this.disabledLabel = 'Unavailable',
  });

  final String leftLabel;
  final String rightLabel;
  final IconData leftIcon;
  final IconData rightIcon;
  final Future<void> Function() onSwipeLeft;
  final Future<void> Function() onSwipeRight;
  final bool enabled;
  final String disabledLabel;

  @override
  State<SwipeActionBar> createState() => _SwipeActionBarState();
}

class _SwipeActionBarState extends State<SwipeActionBar>
    with SingleTickerProviderStateMixin {
  static const _height = 62.0;
  static const _handle = 52.0;
  static const _trigger = 0.62; // fraction of half-width

  late final AnimationController _settle = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 320),
  );
  double _dx = 0; // handle offset from centre
  double _from = 0; // offset when the settle-back animation started
  double _halfTravel = 1;
  bool _busy = false;
  bool _armed = false;

  @override
  void initState() {
    super.initState();
    _settle.addListener(() {
      if (!mounted) return;
      setState(() {
        _dx = _from * (1 - Curves.easeOutBack.transform(_settle.value));
      });
    });
  }

  @override
  void dispose() {
    _settle.dispose();
    super.dispose();
  }

  void _animateBack() {
    _from = _dx;
    _settle.forward(from: 0);
  }

  Future<void> _fire(bool right) async {
    if (_busy || !widget.enabled) return;
    setState(() => _busy = true);
    HapticFeedback.mediumImpact();
    try {
      await (right ? widget.onSwipeRight() : widget.onSwipeLeft());
    } finally {
      if (mounted) {
        setState(() => _busy = false);
        _animateBack();
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    if (!widget.enabled) {
      return Container(
        height: _height,
        alignment: Alignment.center,
        decoration: BoxDecoration(
          color: AppColors.panelHover,
          borderRadius: BorderRadius.circular(_height / 2),
        ),
        child: Text(widget.disabledLabel,
            style: AppTextStyles.body(weight: FontWeight.w700, color: AppColors.faint)),
      );
    }

    return LayoutBuilder(builder: (context, box) {
      _halfTravel = (box.maxWidth - _handle) / 2 - 5;
      final progress = (_dx / _halfTravel).clamp(-1.0, 1.0);
      final rightFill = progress > 0 ? progress : 0.0;
      final leftFill = progress < 0 ? -progress : 0.0;

      return Semantics(
        container: true,
        customSemanticsActions: {
          CustomSemanticsAction(label: widget.leftLabel): () => _fire(false),
          CustomSemanticsAction(label: widget.rightLabel): () => _fire(true),
        },
        child: SizedBox(
          height: _height,
          child: Stack(
            alignment: Alignment.center,
            children: [
              // Track
              Container(
                decoration: BoxDecoration(
                  color: AppColors.panel,
                  borderRadius: BorderRadius.circular(_height / 2),
                  border: Border.all(color: AppColors.lineStrong),
                ),
              ),
              // Fill towards the side being swiped
              Positioned.fill(
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(_height / 2),
                  child: Row(
                    children: [
                      Expanded(
                        child: Align(
                          alignment: Alignment.centerRight,
                          child: FractionallySizedBox(
                            widthFactor: leftFill,
                            child: Container(
                                color: AppColors.shopper.withValues(alpha: 0.28)),
                          ),
                        ),
                      ),
                      Expanded(
                        child: Align(
                          alignment: Alignment.centerLeft,
                          child: FractionallySizedBox(
                            widthFactor: rightFill,
                            child: Container(
                                color: AppColors.shopper.withValues(alpha: 0.55)),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
              // Labels (tappable)
              Row(
                children: [
                  Expanded(
                    child: _Side(
                      icon: widget.leftIcon,
                      label: widget.leftLabel,
                      hint: '‹‹',
                      alignEnd: false,
                      emphasis: leftFill,
                      onTap: () => _fire(false),
                    ),
                  ),
                  const SizedBox(width: _handle + 8),
                  Expanded(
                    child: _Side(
                      icon: widget.rightIcon,
                      label: widget.rightLabel,
                      hint: '››',
                      alignEnd: true,
                      emphasis: rightFill,
                      onTap: () => _fire(true),
                    ),
                  ),
                ],
              ),
              // Handle
              Transform.translate(
                offset: Offset(_dx, 0),
                child: GestureDetector(
                  onHorizontalDragStart: (_) {
                    _settle.stop();
                    _armed = false;
                  },
                  onHorizontalDragUpdate: (d) {
                    setState(() {
                      _dx = (_dx + d.delta.dx).clamp(-_halfTravel, _halfTravel);
                    });
                    final armed = (_dx / _halfTravel).abs() >= _trigger;
                    if (armed && !_armed) HapticFeedback.selectionClick();
                    _armed = armed;
                  },
                  onHorizontalDragEnd: (_) {
                    final p = _dx / _halfTravel;
                    if (p >= _trigger) {
                      _fire(true);
                    } else if (p <= -_trigger) {
                      _fire(false);
                    } else {
                      _animateBack();
                    }
                  },
                  child: Container(
                    width: _handle,
                    height: _handle,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      gradient: const LinearGradient(
                        colors: [Color(0xFFC77DFF), AppColors.shopperDeep],
                      ),
                      boxShadow: [
                        BoxShadow(
                          color: AppColors.shopperDeep.withValues(alpha: 0.4),
                          blurRadius: 12,
                          offset: const Offset(0, 4),
                        ),
                      ],
                    ),
                    child: _busy
                        ? const Padding(
                            padding: EdgeInsets.all(15),
                            child: CircularProgressIndicator(
                              strokeWidth: 2.2,
                              color: AppColors.onAccent,
                            ),
                          )
                        : const Icon(Icons.swap_horiz_rounded,
                            color: AppColors.onAccent, size: 26),
                  ),
                ),
              ),
            ],
          ),
        ),
      );
    });
  }
}

class _Side extends StatelessWidget {
  const _Side({
    required this.icon,
    required this.label,
    required this.hint,
    required this.alignEnd,
    required this.emphasis,
    required this.onTap,
  });

  final IconData icon;
  final String label;
  final String hint;
  final bool alignEnd;
  final double emphasis;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final color = Color.lerp(AppColors.paper, AppColors.shopper, emphasis)!;
    final children = [
      Icon(icon, size: 18, color: color),
      const SizedBox(width: 6),
      Flexible(
        child: Text(
          label,
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          style: AppTextStyles.body(size: 14, weight: FontWeight.w800, color: color),
        ),
      ),
    ];
    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTap: onTap,
      child: Padding(
        padding: EdgeInsets.only(left: alignEnd ? 0 : 18, right: alignEnd ? 18 : 0),
        child: Row(
          mainAxisAlignment:
              alignEnd ? MainAxisAlignment.end : MainAxisAlignment.start,
          children: alignEnd
              ? [
                  ...children,
                  const SizedBox(width: 4),
                  Text(hint, style: AppTextStyles.mono(size: 12, color: AppColors.faint)),
                ]
              : [
                  Text(hint, style: AppTextStyles.mono(size: 12, color: AppColors.faint)),
                  const SizedBox(width: 4),
                  ...children,
                ],
        ),
      ),
    );
  }
}
