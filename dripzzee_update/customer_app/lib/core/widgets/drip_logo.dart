import 'package:flutter/material.dart';

import '../theme/app_theme.dart';

/// Brand navy behind the wordmark (matches the app icon).
const kBrandNavy = Color(0xFF02082C);

/// The Dripzzee wordmark. Always the image asset — never styled text.
/// On light backgrounds it sits on a navy chip so the pale lettering stays
/// readable.
class DripLogo extends StatelessWidget {
  const DripLogo({super.key, this.height = 22, this.onNavy = false});

  final double height;

  /// Force the navy chip (e.g. over photos).
  final bool onNavy;

  @override
  Widget build(BuildContext context) {
    final image = Image.asset(
      'assets/logo.png',
      height: height,
      fit: BoxFit.contain,
      filterQuality: FilterQuality.medium,
      semanticLabel: 'Dripzzee',
    );
    if (!onNavy && !AppColors.isLight) return image;
    return Container(
      padding: EdgeInsets.symmetric(
        horizontal: height * 0.55,
        vertical: height * 0.32,
      ),
      decoration: BoxDecoration(
        color: kBrandNavy,
        borderRadius: BorderRadius.circular(height * 0.45),
      ),
      child: image,
    );
  }
}
