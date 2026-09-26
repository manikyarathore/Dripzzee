import 'dart:async';

import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';

import '../../core/config/app_config.dart';
import '../../core/theme/app_theme.dart';
import '../../core/utils/validators.dart';
import '../../core/widgets/buttons.dart';
import '../../core/widgets/drip_logo.dart';
import '../../core/widgets/state_views.dart';
import '../../data/repositories/auth_repository.dart';
import '../../navigation.dart';
import '../../state/auth_controller.dart';
import '../legal/legal_screen.dart';
import 'widgets/fashion_mosaic.dart';

enum _Step { phone, otp }

/// Phone number → OTP. First sign-in creates the account automatically;
/// the session then persists until the user logs out.
class LoginScreen extends StatefulWidget {
  const LoginScreen({super.key});

  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> {
  final _phone = TextEditingController();
  final _otp = TextEditingController();
  final _otpFocus = FocusNode();
  _Step _step = _Step.phone;
  String? _verificationId;
  int? _resendToken;
  bool _sending = false;
  bool _verifying = false;
  bool _googleLoading = false;
  String? _error;
  int _resendIn = 0;
  Timer? _resendTimer;

  @override
  void dispose() {
    _resendTimer?.cancel();
    _phone.dispose();
    _otp.dispose();
    _otpFocus.dispose();
    super.dispose();
  }

  String get _e164 =>
      '${AppConfig.phoneCountryCode}${Validators.normalizePhone(_phone.text)}';

  String get _prettyPhone {
    final d = Validators.normalizePhone(_phone.text);
    return d.length == 10
        ? '${AppConfig.phoneCountryCode} ${d.substring(0, 5)} ${d.substring(5)}'
        : _e164;
  }

  void _startResendTimer() {
    _resendTimer?.cancel();
    setState(() => _resendIn = 30);
    _resendTimer = Timer.periodic(const Duration(seconds: 1), (t) {
      if (!mounted) return t.cancel();
      setState(() => _resendIn--);
      if (_resendIn <= 0) t.cancel();
    });
  }

  Future<void> _sendCode({bool resend = false}) async {
    FocusScope.of(context).unfocus();
    final problem = Validators.phone(_phone.text);
    if (problem != null) {
      setState(() => _error = problem);
      return;
    }
    setState(() {
      _sending = true;
      _error = null;
    });
    await context.read<AuthController>().sendOtp(
          phoneE164: _e164,
          resendToken: resend ? _resendToken : null,
          onCodeSent: (id, token) {
            if (!mounted) return;
            setState(() {
              _verificationId = id;
              _resendToken = token;
              _sending = false;
              _step = _Step.otp;
              _otp.clear();
            });
            _startResendTimer();
            _otpFocus.requestFocus();
          },
          onAutoVerified: () {
            // Signed in; AuthGate moves on automatically.
          },
          onError: (AuthFailure f) {
            if (!mounted) return;
            setState(() {
              _sending = false;
              _verifying = false;
              _error = f.userText;
            });
          },
        );
  }

  Future<void> _verify() async {
    final code = _otp.text.trim();
    if (code.length != 6 || _verificationId == null || _verifying) {
      if (code.length != 6) setState(() => _error = 'Enter the 6-digit code.');
      return;
    }
    setState(() {
      _verifying = true;
      _error = null;
    });
    try {
      await context.read<AuthController>().verifyOtp(_verificationId!, code);
    } on AuthFailure catch (e) {
      if (mounted) {
        setState(() {
          _verifying = false;
          _error = e.userText;
        });
      }
    }
  }

  Future<void> _google() async {
    setState(() {
      _googleLoading = true;
      _error = null;
    });
    try {
      await context.read<AuthController>().signInWithGoogle();
    } on AuthFailure catch (e) {
      if (mounted) setState(() => _error = e.userText);
    } finally {
      if (mounted) setState(() => _googleLoading = false);
    }
  }

  void _changeNumber() {
    _resendTimer?.cancel();
    setState(() {
      _step = _Step.phone;
      _error = null;
      _verifying = false;
    });
  }

  @override
  Widget build(BuildContext context) {
    final bottomInset = MediaQuery.viewInsetsOf(context).bottom;
    final keyboardOpen = bottomInset > 0;

    return PopScope(
      canPop: _step == _Step.phone,
      onPopInvokedWithResult: (didPop, _) {
        if (!didPop) _changeNumber();
      },
      child: Scaffold(
        resizeToAvoidBottomInset: true,
        body: Stack(
          children: [
            const Positioned.fill(child: FashionMosaic()),
            Positioned.fill(
              child: IgnorePointer(
                child: DecoratedBox(
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      begin: Alignment.topCenter,
                      end: Alignment.bottomCenter,
                      colors: [
                        AppColors.ink.withValues(alpha: 0.25),
                        AppColors.ink.withValues(alpha: 0.55),
                        AppColors.ink.withValues(alpha: 0.96),
                        AppColors.ink,
                      ],
                      stops: const [0, 0.35, 0.62, 1],
                    ),
                  ),
                ),
              ),
            ),
            SafeArea(
              child: LayoutBuilder(
                builder: (context, box) => SingleChildScrollView(
                  child: ConstrainedBox(
                    constraints: BoxConstraints(minHeight: box.maxHeight),
                    child: IntrinsicHeight(
                      child: Column(
                        children: [
                          Expanded(
                            child: AnimatedOpacity(
                              duration: const Duration(milliseconds: 200),
                              opacity: keyboardOpen ? 0 : 1,
                              child: Padding(
                                padding: const EdgeInsets.symmetric(vertical: 24),
                                child: Center(
                                  child: Column(
                                    mainAxisSize: MainAxisSize.min,
                                    children: [
                                      const DripLogo(height: 36, onNavy: true),
                                      const SizedBox(height: 12),
                                      Text(
                                        'Fashion from stores around you',
                                        style: AppTextStyles.body(
                                          size: 14,
                                          weight: FontWeight.w700,
                                          color: AppColors.paper,
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                              ),
                            ),
                          ),
                          _Panel(
                            child: AnimatedSwitcher(
                              duration: const Duration(milliseconds: 280),
                              transitionBuilder: (child, a) => FadeTransition(
                                opacity: a,
                                child: SlideTransition(
                                  position: Tween(
                                    begin: const Offset(0.08, 0),
                                    end: Offset.zero,
                                  ).animate(a),
                                  child: child,
                                ),
                              ),
                              child: _step == _Step.phone
                                  ? _phoneStep()
                                  : _otpStep(),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _phoneStep() {
    return Column(
      key: const ValueKey('phone'),
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Text('Log in or sign up', style: AppTextStyles.heading(size: 26)),
        const SizedBox(height: 6),
        Text(
          'We\'ll text you a 6-digit code. New here? Your account is created automatically.',
          style: AppTextStyles.body(size: 13, color: AppColors.mute, height: 1.4),
        ),
        const SizedBox(height: 18),
        if (_error != null) ...[
          InlineNotice(message: _error!),
          const SizedBox(height: 12),
        ],
        Container(
          height: 56,
          decoration: BoxDecoration(
            color: AppColors.panelHover,
            borderRadius: BorderRadius.circular(14),
            border: Border.all(color: AppColors.lineStrong),
          ),
          child: Row(
            children: [
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 14),
                child: Text(
                  '🇮🇳 ${AppConfig.phoneCountryCode}',
                  style: AppTextStyles.body(size: 16, weight: FontWeight.w700),
                ),
              ),
              Container(width: 1, height: 26, color: AppColors.lineStrong),
              Expanded(
                child: TextField(
                  controller: _phone,
                  keyboardType: TextInputType.phone,
                  autofillHints: const [AutofillHints.telephoneNumberNational],
                  inputFormatters: [
                    FilteringTextInputFormatter.digitsOnly,
                    LengthLimitingTextInputFormatter(10),
                  ],
                  textInputAction: TextInputAction.done,
                  onSubmitted: (_) => _sendCode(),
                  style: AppTextStyles.body(
                    size: 17,
                    weight: FontWeight.w700,
                  ).copyWith(letterSpacing: 1.5),
                  decoration: InputDecoration(
                    border: InputBorder.none,
                    contentPadding: const EdgeInsets.symmetric(horizontal: 14),
                    hintText: 'Mobile number',
                    hintStyle: AppTextStyles.body(size: 16, color: AppColors.faint),
                  ),
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 14),
        PrimaryButton(label: 'Get OTP', loading: _sending, onPressed: _sendCode),
        const SizedBox(height: 16),
        Row(
          children: [
            Expanded(child: Divider(color: AppColors.line)),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 12),
              child: Text('or', style: AppTextStyles.mono(size: 11)),
            ),
            Expanded(child: Divider(color: AppColors.line)),
          ],
        ),
        const SizedBox(height: 16),
        SecondaryButton(
          label: 'Continue with Google',
          icon: Icons.g_mobiledata_rounded,
          loading: _googleLoading,
          onPressed: _sending ? null : _google,
        ),
        const SizedBox(height: 14),
        _TermsLine(),
      ],
    );
  }

  Widget _otpStep() {
    return Column(
      key: const ValueKey('otp'),
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Text('Enter the code', style: AppTextStyles.heading(size: 26)),
        const SizedBox(height: 6),
        Row(
          children: [
            Flexible(
              child: Text(
                'Sent to $_prettyPhone',
                style: AppTextStyles.body(size: 13, color: AppColors.mute),
              ),
            ),
            TextButton(
              onPressed: _verifying ? null : _changeNumber,
              child: Text(
                'Change',
                style: AppTextStyles.body(
                  size: 13,
                  weight: FontWeight.w700,
                  color: AppColors.shopper,
                ),
              ),
            ),
          ],
        ),
        const SizedBox(height: 12),
        if (_error != null) ...[
          InlineNotice(message: _error!),
          const SizedBox(height: 12),
        ],
        TextField(
          controller: _otp,
          focusNode: _otpFocus,
          keyboardType: TextInputType.number,
          autofillHints: const [AutofillHints.oneTimeCode],
          textAlign: TextAlign.center,
          inputFormatters: [
            FilteringTextInputFormatter.digitsOnly,
            LengthLimitingTextInputFormatter(6),
          ],
          onChanged: (v) {
            if (v.length == 6) _verify();
          },
          style: AppTextStyles.heading(size: 30, weight: FontWeight.w600)
              .copyWith(letterSpacing: 14),
          decoration: InputDecoration(
            hintText: '••••••',
            hintStyle: AppTextStyles.heading(size: 30, color: AppColors.faint)
                .copyWith(letterSpacing: 14),
            filled: true,
            fillColor: AppColors.panelHover,
            contentPadding: const EdgeInsets.symmetric(vertical: 14),
            enabledBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(14),
              borderSide: BorderSide(color: AppColors.lineStrong),
            ),
            focusedBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(14),
              borderSide: BorderSide(color: AppColors.shopper, width: 1.5),
            ),
          ),
        ),
        const SizedBox(height: 14),
        PrimaryButton(
          label: 'Verify & continue',
          loading: _verifying,
          onPressed: _verify,
        ),
        const SizedBox(height: 8),
        Center(
          child: _resendIn > 0
              ? Padding(
                  padding: const EdgeInsets.symmetric(vertical: 12),
                  child: Text(
                    'Resend code in 0:${_resendIn.toString().padLeft(2, '0')}',
                    style: AppTextStyles.mono(size: 12),
                  ),
                )
              : TextButton(
                  onPressed: _sending ? null : () => _sendCode(resend: true),
                  child: Text(
                    _sending ? 'Sending…' : 'Resend code',
                    style: AppTextStyles.body(
                      size: 14,
                      weight: FontWeight.w700,
                      color: AppColors.shopper,
                    ),
                  ),
                ),
        ),
      ],
    );
  }
}

class _Panel extends StatelessWidget {
  const _Panel({required this.child});
  final Widget child;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      constraints: const BoxConstraints(maxWidth: 520),
      margin: const EdgeInsets.fromLTRB(12, 0, 12, 12),
      padding: const EdgeInsets.fromLTRB(20, 22, 20, 16),
      decoration: BoxDecoration(
        color: AppColors.panel.withValues(alpha: 0.94),
        borderRadius: BorderRadius.circular(26),
        border: Border.all(color: AppColors.line),
      ),
      child: AnimatedSize(
        duration: const Duration(milliseconds: 250),
        curve: Curves.easeOutCubic,
        alignment: Alignment.topCenter,
        child: child,
      ),
    );
  }
}

class _TermsLine extends StatefulWidget {
  @override
  State<_TermsLine> createState() => _TermsLineState();
}

class _TermsLineState extends State<_TermsLine> {
  late final _terms = TapGestureRecognizer()
    ..onTap = () => AppNav.push(context, const LegalScreen(doc: LegalDoc.terms));
  late final _privacy = TapGestureRecognizer()
    ..onTap =
        () => AppNav.push(context, const LegalScreen(doc: LegalDoc.privacy));

  @override
  void dispose() {
    _terms.dispose();
    _privacy.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final link = AppTextStyles.body(
      size: 12,
      weight: FontWeight.w700,
      color: AppColors.shopper,
    );
    return Text.rich(
      TextSpan(
        style: AppTextStyles.body(size: 12, color: AppColors.mute, height: 1.4),
        children: [
          const TextSpan(text: 'By continuing, you agree to our '),
          TextSpan(text: 'Terms & Conditions', style: link, recognizer: _terms),
          const TextSpan(text: ' and '),
          TextSpan(text: 'Privacy Policy', style: link, recognizer: _privacy),
          const TextSpan(text: '.'),
        ],
      ),
      textAlign: TextAlign.center,
    );
  }
}
