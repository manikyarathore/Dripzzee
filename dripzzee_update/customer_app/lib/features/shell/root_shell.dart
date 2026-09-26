import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../core/theme/app_theme.dart';
import '../../navigation.dart';
import '../../state/cart_controller.dart';
import '../../state/shell_controller.dart';
import '../home/home_screen.dart';
import '../orders/orders_screen.dart';
import '../search/search_screen.dart';
import '../wishlist/wishlist_screen.dart';

/// Bottom navigation (Home, Search, Saved, Orders) + the floating bag.
/// Profile lives behind the avatar in the Home header.
class RootShell extends StatelessWidget {
  const RootShell({super.key});

  static const _tabs = <Widget>[
    HomeScreen(),
    SearchScreen(),
    WishlistScreen(),
    OrdersScreen(),
  ];

  @override
  Widget build(BuildContext context) {
    final shell = context.watch<ShellController>();
    final index = shell.tab.index;

    return PopScope(
      canPop: index == 0,
      onPopInvokedWithResult: (didPop, _) {
        if (!didPop) shell.goTo(ShellTab.home);
      },
      child: Scaffold(
        body: IndexedStack(
          index: index,
          children: [
            for (var i = 0; i < _tabs.length; i++)
              // Hidden tabs: no animations, no hero flights.
              TickerMode(
                enabled: i == index,
                child: HeroMode(enabled: i == index, child: _tabs[i]),
              ),
          ],
        ),
        bottomNavigationBar: _NavBar(current: shell.tab, onSelect: shell.goTo),
      ),
    );
  }
}

/// Raised shopping bag at the bottom-left of the navigation bar. Bumps when
/// the item count changes.
class _FloatingBag extends StatelessWidget {
  const _FloatingBag();

  @override
  Widget build(BuildContext context) {
    final count = context.select<CartController, int>((c) => c.itemCount);

    return Semantics(
        button: true,
        label: count == 0 ? 'Bag, empty' : 'Bag, $count items',
        child: GestureDetector(
          onTap: () => AppNav.openCart(context),
          child: TweenAnimationBuilder<double>(
            key: ValueKey(count),
            tween: Tween(begin: count == 0 ? 1 : 1.18, end: 1),
            duration: const Duration(milliseconds: 420),
            curve: Curves.elasticOut,
            builder: (context, scale, child) =>
                Transform.scale(scale: scale, child: child),
            child: Stack(
              clipBehavior: Clip.none,
              children: [
                Container(
                  width: 58,
                  height: 58,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    gradient: const LinearGradient(
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                      colors: [Color(0xFFC77DFF), AppColors.shopperDeep],
                    ),
                    boxShadow: [
                      BoxShadow(
                        color: AppColors.shopperDeep.withValues(alpha: 0.45),
                        blurRadius: 18,
                        offset: const Offset(0, 6),
                      ),
                    ],
                  ),
                  child: const Icon(Icons.shopping_bag_rounded,
                      color: AppColors.onAccent, size: 26),
                ),
                if (count > 0)
                  Positioned(
                    right: -2,
                    top: -2,
                    child: Container(
                      constraints:
                          const BoxConstraints(minWidth: 22, minHeight: 22),
                      padding: const EdgeInsets.symmetric(horizontal: 5),
                      alignment: Alignment.center,
                      decoration: BoxDecoration(
                        color: AppColors.marigold,
                        borderRadius: BorderRadius.circular(11),
                        border: Border.all(color: AppColors.ink, width: 2),
                      ),
                      child: Text(
                        count > 99 ? '99+' : '$count',
                        style: AppTextStyles.body(
                          size: 11,
                          weight: FontWeight.w800,
                          color: const Color(0xFF1A1300),
                        ),
                      ),
                    ),
                  ),
              ],
            ),
          ),
        ),
    );
  }
}

class _NavBar extends StatelessWidget {
  const _NavBar({required this.current, required this.onSelect});

  final ShellTab current;
  final ValueChanged<ShellTab> onSelect;

  static const _items = [
    (ShellTab.home, Icons.home_outlined, Icons.home_rounded, 'Home'),
    (ShellTab.search, Icons.search_rounded, Icons.search_rounded, 'Search'),
    (ShellTab.saved, Icons.favorite_border_rounded, Icons.favorite_rounded, 'Saved'),
    (ShellTab.orders, Icons.receipt_long_outlined, Icons.receipt_long_rounded, 'Orders'),
  ];

  @override
  Widget build(BuildContext context) {
    return MediaQuery.withClampedTextScaling(
      maxScaleFactor: 1.2,
      child: Container(
        decoration: BoxDecoration(
          color: AppColors.ink,
          border: Border(top: BorderSide(color: AppColors.line)),
        ),
        child: SafeArea(
          top: false,
          child: SizedBox(
            height: 62,
            child: Row(
              children: [
                SizedBox(
                  width: 84,
                  child: Center(
                    child: Transform.translate(
                      offset: const Offset(0, -12),
                      child: const _FloatingBag(),
                    ),
                  ),
                ),
                for (final (tab, icon, activeIcon, label) in _items)
                  Expanded(
                    child: Semantics(
                      selected: tab == current,
                      button: true,
                      label: label,
                      child: InkWell(
                        onTap: () => onSelect(tab),
                        child: _NavItem(
                          icon: tab == current ? activeIcon : icon,
                          label: label,
                          active: tab == current,
                        ),
                      ),
                    ),
                  ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _NavItem extends StatelessWidget {
  const _NavItem({
    required this.icon,
    required this.label,
    required this.active,
  });

  final IconData icon;
  final String label;
  final bool active;

  @override
  Widget build(BuildContext context) {
    final color = active ? AppColors.shopper : AppColors.mute;
    return Column(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        AnimatedScale(
          scale: active ? 1.12 : 1,
          duration: const Duration(milliseconds: 380),
          curve: Curves.elasticOut,
          child: Icon(icon, size: 22, color: color),
        ),
        const SizedBox(height: 4),
        Text(
          label,
          maxLines: 1,
          style: AppTextStyles.mono(
            size: 10,
            color: color,
            weight: active ? FontWeight.w700 : FontWeight.w400,
          ),
        ),
        AnimatedContainer(
          duration: const Duration(milliseconds: 250),
          margin: const EdgeInsets.only(top: 3),
          width: active ? 4 : 0,
          height: 4,
          decoration: BoxDecoration(
            color: AppColors.shopper,
            shape: BoxShape.circle,
          ),
        ),
      ],
    );
  }
}
