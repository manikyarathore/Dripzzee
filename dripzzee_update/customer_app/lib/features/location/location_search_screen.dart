import 'dart:async';

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../core/theme/app_theme.dart';
import '../../core/widgets/buttons.dart';
import '../../core/widgets/drip_app_bar.dart';
import '../../core/widgets/feedback.dart';
import '../../core/widgets/state_views.dart';
import '../../core/widgets/text_field.dart';
import '../../data/models/address.dart';
import '../../data/models/saved_location.dart';
import '../../data/repositories/user_repository.dart';
import '../../data/services/location_service.dart';
import '../../state/auth_controller.dart';
import '../../state/location_controller.dart';

/// Change location: GPS, place search, or one of the saved addresses.
class LocationSearchScreen extends StatefulWidget {
  const LocationSearchScreen({super.key});

  @override
  State<LocationSearchScreen> createState() => _LocationSearchScreenState();
}

class _LocationSearchScreenState extends State<LocationSearchScreen> {
  final _query = TextEditingController();
  Timer? _debounce;
  bool _searching = false;
  bool _applying = false;
  String? _searchError;
  List<SavedLocation> _results = const [];
  String _lastQuery = '';
  Stream<List<Address>>? _addresses;

  @override
  void initState() {
    super.initState();
    final uid = context.read<AuthController>().uid;
    if (uid != null) {
      _addresses = context.read<UserRepository>().watchAddresses(uid);
    }
  }

  @override
  void dispose() {
    _debounce?.cancel();
    _query.dispose();
    super.dispose();
  }

  void _onChanged(String value) {
    _debounce?.cancel();
    _debounce = Timer(const Duration(milliseconds: 600), () => _search(value));
  }

  Future<void> _search(String value) async {
    final q = value.trim();
    if (q == _lastQuery) return;
    _lastQuery = q;
    if (q.length < 3) {
      setState(() {
        _results = const [];
        _searchError = null;
        _searching = false;
      });
      return;
    }
    setState(() {
      _searching = true;
      _searchError = null;
    });
    try {
      final results = await context.read<LocationService>().search(q);
      if (!mounted || q != _lastQuery) return;
      setState(() => _results = results);
    } catch (_) {
      if (!mounted) return;
      setState(() => _searchError =
          'Search failed. Check your connection and try again.');
    } finally {
      if (mounted && q == _lastQuery) setState(() => _searching = false);
    }
  }

  Future<void> _apply(SavedLocation location) async {
    await context.read<LocationController>().setLocation(location);
    if (mounted) Navigator.of(context).pop();
  }

  Future<void> _useGps() async {
    final failure = await context.read<LocationController>().detectAndSave();
    if (!mounted) return;
    if (failure == null) {
      Navigator.of(context).pop();
    }
  }

  Future<void> _useAddress(Address a) async {
    if (_applying) return;
    setState(() => _applying = true);
    try {
      var lat = a.lat;
      var lng = a.lng;
      if (lat == null || lng == null) {
        final found = await context
            .read<LocationService>()
            .search('${a.line1}, ${a.city} ${a.pincode}');
        if (found.isEmpty) {
          if (mounted) {
            showSnack(context,
                'Couldn\'t place this address on the map. Try searching your area.',
                error: true);
          }
          return;
        }
        lat = found.first.lat;
        lng = found.first.lng;
      }
      await _apply(SavedLocation(
        label: a.label,
        detail: a.fullText,
        lat: lat,
        lng: lng,
        source: 'address',
      ));
    } finally {
      if (mounted) setState(() => _applying = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final location = context.watch<LocationController>();
    final current = location.current;
    final failure = location.lastFailure;

    return Scaffold(
      appBar: dripAppBar(title: 'Choose location'),
      body: ListView(
        keyboardDismissBehavior: ScrollViewKeyboardDismissBehavior.onDrag,
        padding: const EdgeInsets.fromLTRB(16, 8, 16, 32),
        children: [
          TextField(
            controller: _query,
            autofocus: current != null,
            onChanged: _onChanged,
            onSubmitted: _search,
            textInputAction: TextInputAction.search,
            style: AppTextStyles.body(size: 15),
            decoration: appInputDecoration(
              hint: 'Search area, street or landmark',
              prefixIcon: Icons.search_rounded,
              suffix: _searching
                  ? const Padding(
                      padding: EdgeInsets.all(14),
                      child: SizedBox(
                        width: 18,
                        height: 18,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      ),
                    )
                  : null,
            ),
          ),
          const SizedBox(height: 12),
          _Tile(
            icon: Icons.my_location_rounded,
            title: 'Use my current location',
            subtitle: location.detecting ? 'Detecting…' : 'Using GPS',
            accent: true,
            onTap: location.detecting ? null : _useGps,
          ),
          if (failure != null) ...[
            const SizedBox(height: 8),
            InlineNotice(message: failure.message),
            if (failure == LocationFailure.deniedForever)
              Align(
                alignment: Alignment.centerLeft,
                child: LinkButton(
                  label: 'Open app settings',
                  onPressed: location.service.openAppSettings,
                ),
              ),
            if (failure == LocationFailure.serviceDisabled)
              Align(
                alignment: Alignment.centerLeft,
                child: LinkButton(
                  label: 'Turn on location',
                  onPressed: location.service.openLocationSettings,
                ),
              ),
          ],
          if (_searchError != null) ...[
            const SizedBox(height: 12),
            InlineNotice(message: _searchError!),
          ],
          if (_results.isNotEmpty) ...[
            const SizedBox(height: 20),
            Text('RESULTS', style: AppTextStyles.mono(size: 11)),
            const SizedBox(height: 8),
            for (final r in _results)
              _Tile(
                icon: Icons.location_on_outlined,
                title: r.label,
                subtitle: r.detail,
                onTap: () => _apply(r),
              ),
          ] else if (!_searching &&
              _lastQuery.length >= 3 &&
              _searchError == null) ...[
            const SizedBox(height: 20),
            Text(
              'No places found for "$_lastQuery". Try a nearby landmark or pincode.',
              style: AppTextStyles.body(size: 13, color: AppColors.mute),
            ),
          ],
          if (_addresses != null)
            StreamBuilder<List<Address>>(
              stream: _addresses,
              builder: (context, snap) {
                final addresses = snap.data ?? const <Address>[];
                if (addresses.isEmpty) return const SizedBox.shrink();
                return Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    const SizedBox(height: 24),
                    Text('SAVED ADDRESSES', style: AppTextStyles.mono(size: 11)),
                    const SizedBox(height: 8),
                    for (final a in addresses)
                      _Tile(
                        icon: a.label == 'Work'
                            ? Icons.work_outline_rounded
                            : Icons.home_outlined,
                        title: a.label,
                        subtitle: a.fullText,
                        onTap: _applying ? null : () => _useAddress(a),
                      ),
                  ],
                );
              },
            ),
          if (current != null) ...[
            const SizedBox(height: 24),
            Text('CURRENTLY SHOPPING AROUND', style: AppTextStyles.mono(size: 11)),
            const SizedBox(height: 8),
            _Tile(
              icon: Icons.check_circle_outline_rounded,
              title: current.label,
              subtitle: current.detail,
              onTap: null,
            ),
          ],
        ],
      ),
    );
  }
}

class _Tile extends StatelessWidget {
  const _Tile({
    required this.icon,
    required this.title,
    required this.onTap,
    this.subtitle,
    this.accent = false,
  });

  final IconData icon;
  final String title;
  final String? subtitle;
  final VoidCallback? onTap;
  final bool accent;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Material(
        color: AppColors.panel,
        borderRadius: BorderRadius.circular(AppRadius.md),
        child: InkWell(
          borderRadius: BorderRadius.circular(AppRadius.md),
          onTap: onTap,
          child: Container(
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(AppRadius.md),
              border: Border.all(color: AppColors.line),
            ),
            child: Row(
              children: [
                Icon(icon,
                    size: 22,
                    color: accent ? AppColors.shopper : AppColors.mute),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        title,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: AppTextStyles.body(
                          size: 15,
                          weight: FontWeight.w700,
                          color: accent ? AppColors.shopper : AppColors.paper,
                        ),
                      ),
                      if (subtitle != null && subtitle!.isNotEmpty) ...[
                        const SizedBox(height: 2),
                        Text(
                          subtitle!,
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                          style: AppTextStyles.body(
                              size: 12, color: AppColors.mute),
                        ),
                      ],
                    ],
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
