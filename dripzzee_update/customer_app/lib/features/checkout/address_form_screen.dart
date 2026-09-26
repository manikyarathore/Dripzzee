import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../core/theme/app_theme.dart';
import '../../core/utils/validators.dart';
import '../../core/widgets/buttons.dart';
import '../../core/widgets/drip_app_bar.dart';
import '../../core/widgets/drip_chip.dart';
import '../../core/widgets/feedback.dart';
import '../../core/widgets/text_field.dart';
import '../../data/models/address.dart';
import '../../data/repositories/user_repository.dart';
import '../../data/services/location_service.dart';
import '../../state/auth_controller.dart';

/// Add or edit a delivery address. Pops with the saved [Address].
class AddressFormScreen extends StatefulWidget {
  const AddressFormScreen({super.key, this.initial});

  final Address? initial;

  @override
  State<AddressFormScreen> createState() => _AddressFormScreenState();
}

class _AddressFormScreenState extends State<AddressFormScreen> {
  final _formKey = GlobalKey<FormState>();
  late final Address? _a = widget.initial;
  late final _name = TextEditingController(
      text: _a?.name ?? context.read<AuthController>().user?.displayName ?? '');
  late final _phone = TextEditingController(text: _a?.phone ?? '');
  late final _line1 = TextEditingController(text: _a?.line1 ?? '');
  late final _line2 = TextEditingController(text: _a?.line2 ?? '');
  late final _landmark = TextEditingController(text: _a?.landmark ?? '');
  late final _city = TextEditingController(text: _a?.city ?? '');
  late final _state = TextEditingController(text: _a?.state ?? '');
  late final _pincode = TextEditingController(text: _a?.pincode ?? '');
  late String _label = _a?.label ?? 'Home';
  late bool _isDefault = _a?.isDefault ?? false;
  late double? _lat = _a?.lat;
  late double? _lng = _a?.lng;
  bool _saving = false;
  bool _locating = false;

  @override
  void dispose() {
    for (final c in [_name, _phone, _line1, _line2, _landmark, _city, _state, _pincode]) {
      c.dispose();
    }
    super.dispose();
  }

  Future<void> _fillFromGps() async {
    setState(() => _locating = true);
    final service = context.read<LocationService>();
    final fix = await service.detectCurrent();
    if (!mounted) return;
    final loc = fix.location;
    if (loc == null) {
      setState(() => _locating = false);
      showSnack(context, fix.failure?.message ?? 'Couldn\'t get your location.',
          error: true);
      return;
    }
    final details = await service.placeDetails(loc.lat, loc.lng);
    if (!mounted) return;
    setState(() {
      _locating = false;
      _lat = loc.lat;
      _lng = loc.lng;
      if (details != null) {
        if (_line2.text.isEmpty) _line2.text = details.line1;
        if (details.city.isNotEmpty) _city.text = details.city;
        if (details.state.isNotEmpty) _state.text = details.state;
        if (details.pincode.isNotEmpty) _pincode.text = details.pincode;
      }
    });
    showSnack(context, 'Location pinned. Add your flat/house number.');
  }

  Future<void> _save() async {
    FocusScope.of(context).unfocus();
    if (!_formKey.currentState!.validate() || _saving) return;
    setState(() => _saving = true);
    final uid = context.read<AuthController>().uid!;
    final address = Address(
      id: _a?.id ?? '',
      label: _label,
      name: _name.text.trim(),
      phone: Validators.normalizePhone(_phone.text),
      line1: _line1.text.trim(),
      line2: _line2.text.trim(),
      landmark: _landmark.text.trim(),
      city: _city.text.trim(),
      state: _state.text.trim(),
      pincode: _pincode.text.trim(),
      lat: _lat,
      lng: _lng,
      isDefault: _isDefault,
    );
    try {
      final saved = await context.read<UserRepository>().saveAddress(uid, address);
      if (mounted) Navigator.of(context).pop(saved);
    } catch (_) {
      if (mounted) {
        setState(() => _saving = false);
        showSnack(context, 'Couldn\'t save the address. Try again.', error: true);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    const gap = SizedBox(height: 14);
    return Scaffold(
      appBar: dripAppBar(title: _a == null ? 'Add address' : 'Edit address'),
      body: Form(
        key: _formKey,
        child: ListView(
          keyboardDismissBehavior: ScrollViewKeyboardDismissBehavior.onDrag,
          padding: const EdgeInsets.fromLTRB(16, 4, 16, 32),
          children: [
            SecondaryButton(
              label: _lat != null ? 'Location pinned · update' : 'Use my current location',
              icon: Icons.my_location_rounded,
              loading: _locating,
              onPressed: _fillFromGps,
            ),
            const SizedBox(height: 20),
            Wrap(
              spacing: 8,
              children: [
                for (final l in const ['Home', 'Work', 'Other'])
                  DripChip(
                    label: l,
                    selected: _label == l,
                    onTap: () => setState(() => _label = l),
                  ),
              ],
            ),
            const SizedBox(height: 18),
            AppTextField(
              controller: _name,
              label: 'Receiver\'s name',
              textCapitalization: TextCapitalization.words,
              textInputAction: TextInputAction.next,
              validator: Validators.name,
            ),
            gap,
            AppTextField(
              controller: _phone,
              label: 'Mobile number',
              keyboardType: TextInputType.phone,
              textInputAction: TextInputAction.next,
              validator: (v) => Validators.phone(v),
            ),
            gap,
            AppTextField(
              controller: _line1,
              label: 'Flat / house no., building',
              textInputAction: TextInputAction.next,
              validator: (v) => Validators.required(v, 'flat/house number'),
            ),
            gap,
            AppTextField(
              controller: _line2,
              label: 'Area, street, locality',
              textInputAction: TextInputAction.next,
              validator: (v) => Validators.required(v, 'area or street'),
            ),
            gap,
            AppTextField(
              controller: _landmark,
              label: 'Landmark (optional)',
              textInputAction: TextInputAction.next,
            ),
            gap,
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Expanded(
                  child: AppTextField(
                    controller: _city,
                    label: 'City',
                    textInputAction: TextInputAction.next,
                    validator: (v) => Validators.required(v, 'city'),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: AppTextField(
                    controller: _pincode,
                    label: 'Pincode',
                    keyboardType: TextInputType.number,
                    textInputAction: TextInputAction.next,
                    validator: Validators.pincode,
                  ),
                ),
              ],
            ),
            gap,
            AppTextField(
              controller: _state,
              label: 'State',
              textInputAction: TextInputAction.done,
              validator: (v) => Validators.required(v, 'state'),
            ),
            const SizedBox(height: 16),
            Align(
              alignment: Alignment.centerLeft,
              child: DripChip(
                label: 'Set as default address',
                icon: _isDefault
                    ? Icons.check_circle_rounded
                    : Icons.radio_button_unchecked_rounded,
                selected: _isDefault,
                onTap: () => setState(() => _isDefault = !_isDefault),
              ),
            ),
            const SizedBox(height: 24),
            PrimaryButton(label: 'Save address', loading: _saving, onPressed: _save),
            if (_lat == null) ...[
              const SizedBox(height: 10),
              Text(
                'Tip: pin your location so the store can find you faster.',
                textAlign: TextAlign.center,
                style: AppTextStyles.body(size: 12, color: AppColors.mute),
              ),
            ],
          ],
        ),
      ),
    );
  }
}
