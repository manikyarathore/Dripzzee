import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../core/theme/app_theme.dart';
import '../../core/widgets/drip_app_bar.dart';
import '../../core/widgets/drip_logo.dart';
import '../../core/widgets/feedback.dart';
import '../../data/models/app_user.dart';
import '../../data/repositories/user_repository.dart';
import '../../data/services/location_service.dart';
import '../../navigation.dart';
import '../../state/auth_controller.dart';
import '../../state/location_controller.dart';
import '../../state/shell_controller.dart';
import '../../state/theme_controller.dart';
import '../checkout/addresses_screen.dart';
import '../legal/legal_screen.dart';
import '../location/location_search_screen.dart';
import '../returns/returns_screen.dart';
import 'edit_profile_screen.dart';
import 'help_screen.dart';

class ProfileScreen extends StatefulWidget {
  const ProfileScreen({super.key});

  @override
  State<ProfileScreen> createState() => _ProfileScreenState();
}

class _ProfileScreenState extends State<ProfileScreen> {
  late final Stream<AppUser?> _user = context
      .read<UserRepository>()
      .watchUser(context.read<AuthController>().uid!);

  Future<void> _logout() async {
    final ok = await confirmDialog(
      context,
      title: 'Log out?',
      message: 'Your cart stays saved on this device for next time.',
      confirmLabel: 'Log out',
      destructive: true,
    );
    if (!ok || !mounted) return;
    Navigator.of(context).popUntil((r) => r.isFirst);
    await context.read<AuthController>().signOut();
  }

  void _openTab(ShellTab tab) {
    context.read<ShellController>().goTo(tab);
    Navigator.of(context).popUntil((r) => r.isFirst);
  }

  Future<void> _pickAppearance() async {
    final theme = context.read<ThemeController>();
    final picked = await showModalBottomSheet<AppearanceMode>(
      context: context,
      builder: (ctx) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text('Appearance', style: AppTextStyles.heading(size: 20)),
            const SizedBox(height: 8),
            for (final (mode, icon) in const [
              (AppearanceMode.system, Icons.brightness_auto_outlined),
              (AppearanceMode.light, Icons.light_mode_outlined),
              (AppearanceMode.dark, Icons.dark_mode_outlined),
            ])
              ListTile(
                leading: Icon(icon, color: AppColors.mute),
                title: Text(mode.label, style: AppTextStyles.body(size: 15)),
                subtitle: mode == AppearanceMode.system
                    ? Text('Follows your phone\'s setting',
                        style: AppTextStyles.body(size: 12, color: AppColors.mute))
                    : null,
                trailing: theme.mode == mode
                    ? Icon(Icons.check_rounded, color: AppColors.shopper)
                    : null,
                onTap: () => Navigator.of(ctx).pop(mode),
              ),
            const SizedBox(height: 8),
          ],
        ),
      ),
    );
    if (picked != null) await theme.setMode(picked);
  }

  @override
  Widget build(BuildContext context) {
    final auth = context.watch<AuthController>();
    final appearance = context.watch<ThemeController>().mode;
    final location = context.watch<LocationController>().current;

    return Scaffold(
      appBar: dripAppBar(title: 'Profile'),
      body: StreamBuilder<AppUser?>(
        stream: _user,
        builder: (context, snap) {
          final user = snap.data;
          final name = (user?.name.isNotEmpty ?? false)
              ? user!.name
              : (auth.user?.displayName ?? 'Dripzzee shopper');
          final initials = user?.initials ??
              (name.isNotEmpty ? name[0].toUpperCase() : '?');

          return ListView(
            padding: const EdgeInsets.fromLTRB(16, 4, 16, 32),
            children: [
              Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: AppColors.panel,
                  borderRadius: BorderRadius.circular(AppRadius.lg),
                  border: Border.all(color: AppColors.line),
                ),
                child: Row(
                  children: [
                    CircleAvatar(
                      radius: 28,
                      backgroundColor: AppColors.shopperSoft,
                      child: Text(initials,
                          style: AppTextStyles.heading(
                              size: 20, color: AppColors.shopper)),
                    ),
                    const SizedBox(width: 14),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(name,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: AppTextStyles.heading(size: 20)),
                          const SizedBox(height: 2),
                          if (user != null && user.phone.isNotEmpty)
                            Text('+91 ${user.phone}',
                                style: AppTextStyles.body(
                                    size: 13, color: AppColors.mute)),
                          if ((user?.email ?? auth.email).isNotEmpty)
                            Text(user?.email.isNotEmpty == true ? user!.email : auth.email,
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                style: AppTextStyles.mono(size: 11)),
                        ],
                      ),
                    ),
                    IconButton(
                      tooltip: 'Edit profile',
                      icon: Icon(Icons.edit_outlined, color: AppColors.mute),
                      onPressed: user == null
                          ? null
                          : () => AppNav.push(context, EditProfileScreen(user: user)),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 20),
              _Group(children: [
                _Row(
                  icon: Icons.receipt_long_outlined,
                  title: 'Your orders',
                  subtitle: 'Track, cancel, rate',
                  onTap: () => _openTab(ShellTab.orders),
                ),
                _Row(
                  icon: Icons.favorite_border_rounded,
                  title: 'Wishlist',
                  onTap: () => _openTab(ShellTab.saved),
                ),
                _Row(
                  icon: Icons.assignment_return_outlined,
                  title: 'Returns & exchanges',
                  onTap: () => AppNav.push(context, const ReturnsScreen()),
                ),
              ]),
              const SizedBox(height: 14),
              _Group(children: [
                _Row(
                  icon: Icons.home_outlined,
                  title: 'Saved addresses',
                  onTap: () => AppNav.push(context, const AddressesScreen()),
                ),
                _Row(
                  icon: Icons.location_on_outlined,
                  title: 'Shopping location',
                  subtitle: location?.label ?? 'Not set',
                  onTap: () => AppNav.push(context, const LocationSearchScreen()),
                ),
                _Row(
                  icon: Icons.notifications_none_rounded,
                  title: 'Notification settings',
                  subtitle: 'Order updates and restock alerts',
                  onTap: () => context.read<LocationService>().openAppSettings(),
                ),
                _Row(
                  icon: Icons.person_outline_rounded,
                  title: 'Edit profile',
                  subtitle: 'Name, phone, email, birthday, gender',
                  onTap: user == null
                      ? null
                      : () => AppNav.push(context, EditProfileScreen(user: user)),
                ),
                _Row(
                  icon: Icons.contrast_rounded,
                  title: 'Appearance',
                  subtitle: appearance.label,
                  onTap: _pickAppearance,
                ),
              ]),
              const SizedBox(height: 14),
              _Group(children: [
                _Row(
                  icon: Icons.help_outline_rounded,
                  title: 'Help & support',
                  subtitle: 'FAQs and helpline',
                  onTap: () => AppNav.push(context, const HelpScreen()),
                ),
                _Row(
                  icon: Icons.description_outlined,
                  title: 'Terms & Conditions',
                  onTap: () => AppNav.push(
                      context, const LegalScreen(doc: LegalDoc.terms)),
                ),
                _Row(
                  icon: Icons.privacy_tip_outlined,
                  title: 'Privacy Policy',
                  onTap: () => AppNav.push(
                      context, const LegalScreen(doc: LegalDoc.privacy)),
                ),
                _Row(
                  icon: Icons.logout_rounded,
                  title: 'Log out',
                  destructive: true,
                  onTap: _logout,
                ),
              ]),
              const SizedBox(height: 28),
              const Center(child: Opacity(opacity: 0.5, child: DripLogo(height: 16))),
              const SizedBox(height: 6),
              Center(
                child: Text('Fashion around you · v1.0.0',
                    style: AppTextStyles.mono(size: 10)),
              ),
            ],
          );
        },
      ),
    );
  }
}

class _Group extends StatelessWidget {
  const _Group({required this.children});
  final List<Widget> children;

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: AppColors.panel,
        borderRadius: BorderRadius.circular(AppRadius.md),
        border: Border.all(color: AppColors.line),
      ),
      clipBehavior: Clip.antiAlias,
      child: Column(
        children: [
          for (var i = 0; i < children.length; i++) ...[
            if (i > 0) const Divider(indent: 52),
            children[i],
          ],
        ],
      ),
    );
  }
}

class _Row extends StatelessWidget {
  const _Row({
    required this.icon,
    required this.title,
    required this.onTap,
    this.subtitle,
    this.destructive = false,
  });

  final IconData icon;
  final String title;
  final String? subtitle;
  final VoidCallback? onTap;
  final bool destructive;

  @override
  Widget build(BuildContext context) {
    final color = destructive ? AppColors.danger : AppColors.paper;
    return InkWell(
      onTap: onTap,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
        child: Row(
          children: [
            Icon(icon, size: 22, color: destructive ? AppColors.danger : AppColors.mute),
            const SizedBox(width: 14),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(title,
                      style: AppTextStyles.body(
                          size: 15, weight: FontWeight.w600, color: color)),
                  if (subtitle != null)
                    Text(subtitle!,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: AppTextStyles.body(size: 12, color: AppColors.mute)),
                ],
              ),
            ),
            if (!destructive)
              Icon(Icons.chevron_right_rounded, color: AppColors.faint),
          ],
        ),
      ),
    );
  }
}
