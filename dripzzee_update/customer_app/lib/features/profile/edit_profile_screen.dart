import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../core/theme/app_theme.dart';
import '../../core/utils/formatters.dart';
import '../../core/utils/validators.dart';
import '../../core/widgets/buttons.dart';
import '../../core/widgets/drip_app_bar.dart';
import '../../core/widgets/drip_chip.dart';
import '../../core/widgets/feedback.dart';
import '../../core/widgets/text_field.dart';
import '../../data/models/app_user.dart';
import '../../data/repositories/user_repository.dart';
import '../../state/auth_controller.dart';

const _genders = [
  ('female', 'Female'),
  ('male', 'Male'),
  ('other', 'Non-binary'),
  ('prefer_not', 'Prefer not to say'),
];

class EditProfileScreen extends StatefulWidget {
  const EditProfileScreen({super.key, required this.user});

  final AppUser user;

  @override
  State<EditProfileScreen> createState() => _EditProfileScreenState();
}

class _EditProfileScreenState extends State<EditProfileScreen> {
  final _formKey = GlobalKey<FormState>();
  late final _name = TextEditingController(text: widget.user.name);
  late final _phone = TextEditingController(text: widget.user.phone);
  late final _email = TextEditingController(text: widget.user.email);
  late DateTime? _dob = widget.user.dob;
  late String _gender = widget.user.gender;
  bool _saving = false;

  /// Phone sign-ins can't change their login number here.
  late final bool _phoneLocked =
      (context.read<AuthController>().user?.phoneNumber ?? '').isNotEmpty;

  /// Google/email sign-ins keep their login email.
  late final bool _emailLocked =
      (context.read<AuthController>().user?.email ?? '').isNotEmpty;

  @override
  void dispose() {
    _name.dispose();
    _phone.dispose();
    _email.dispose();
    super.dispose();
  }

  Future<void> _pickDob() async {
    final now = DateTime.now();
    final picked = await showDatePicker(
      context: context,
      initialDate: _dob ?? DateTime(now.year - 22, 1, 1),
      firstDate: DateTime(now.year - 100),
      lastDate: DateTime(now.year - 13, now.month, now.day),
      helpText: 'Date of birth',
    );
    if (picked != null) setState(() => _dob = picked);
  }

  Future<void> _save() async {
    FocusScope.of(context).unfocus();
    if (!_formKey.currentState!.validate() || _saving) return;
    setState(() => _saving = true);
    final auth = context.read<AuthController>();
    try {
      await context.read<UserRepository>().updateProfile(
            widget.user.uid,
            name: _name.text,
            phone: Validators.normalizePhone(_phone.text),
            email: _email.text,
            dob: _dob,
            gender: _gender,
          );
      await auth.updateDisplayName(_name.text);
      if (!mounted) return;
      showSnack(context, 'Profile updated');
      Navigator.of(context).pop();
    } catch (_) {
      if (mounted) {
        setState(() => _saving = false);
        showSnack(context, 'Couldn\'t save. Try again.', error: true);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: dripAppBar(title: 'Edit profile'),
      body: Form(
        key: _formKey,
        child: ListView(
          padding: const EdgeInsets.fromLTRB(16, 8, 16, 32),
          children: [
            AppTextField(
              controller: _name,
              label: 'Full name',
              prefixIcon: Icons.person_outline_rounded,
              textCapitalization: TextCapitalization.words,
              validator: Validators.name,
            ),
            const SizedBox(height: 14),
            AppTextField(
              controller: _phone,
              label: 'Mobile number',
              helper: _phoneLocked ? 'This is the number you log in with.' : null,
              prefixIcon: Icons.phone_outlined,
              keyboardType: TextInputType.phone,
              enabled: !_phoneLocked,
              validator: (v) => Validators.phone(v, required: false),
            ),
            const SizedBox(height: 14),
            AppTextField(
              controller: _email,
              label: 'Email (optional)',
              helper: _emailLocked ? 'Your Google login email.' : null,
              prefixIcon: Icons.alternate_email_rounded,
              keyboardType: TextInputType.emailAddress,
              enabled: !_emailLocked,
              validator: (v) =>
                  (v == null || v.trim().isEmpty) ? null : Validators.email(v),
            ),
            const SizedBox(height: 14),
            InkWell(
              borderRadius: BorderRadius.circular(14),
              onTap: _pickDob,
              child: InputDecorator(
                decoration: appInputDecoration(
                  label: 'Date of birth',
                  prefixIcon: Icons.cake_outlined,
                ),
                child: Row(
                  children: [
                    Expanded(
                      child: Text(
                        _dob == null ? 'Add your birthday' : formatDate(_dob!),
                        style: AppTextStyles.body(
                          size: 15,
                          color: _dob == null ? AppColors.faint : AppColors.paper,
                        ),
                      ),
                    ),
                    if (_dob != null)
                      GestureDetector(
                        onTap: () => setState(() => _dob = null),
                        child: Icon(Icons.close_rounded,
                            size: 18, color: AppColors.mute),
                      ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 20),
            Text('Gender', style: AppTextStyles.body(weight: FontWeight.w700)),
            const SizedBox(height: 10),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                for (final (value, label) in _genders)
                  DripChip(
                    label: label,
                    selected: _gender == value,
                    onTap: () => setState(
                        () => _gender = _gender == value ? '' : value),
                  ),
              ],
            ),
            const SizedBox(height: 28),
            PrimaryButton(label: 'Save changes', loading: _saving, onPressed: _save),
          ],
        ),
      ),
    );
  }
}
