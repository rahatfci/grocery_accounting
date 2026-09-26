import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_tokens.dart';
import 'app_mark.dart';

/// Shown while the saved session is still being restored, so a signed-in
/// member never sees the sign in form flash past.
class SplashView extends StatelessWidget {
  const SplashView({super.key});

  @override
  Widget build(BuildContext context) {
    final text = Theme.of(context).textTheme;

    return AnnotatedRegion<SystemUiOverlayStyle>(
      value: SystemUiOverlayStyle.light,
      child: Scaffold(
        backgroundColor: AppColors.brand,
        body: SafeArea(
          child: Column(
            children: [
              Expanded(
                child: Semantics(
                  label: 'Loading',
                  liveRegion: true,
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      const AppMark(size: 88, reversed: true),
                      const SizedBox(height: AppSpace.s16),
                      Text(
                        'Grocery Accounting',
                        textAlign: TextAlign.center,
                        style: text.headlineMedium?.copyWith(
                          color: AppColors.onBrand,
                        ),
                      ),
                      const SizedBox(height: AppSpace.s4),
                      Text(
                        'di Quattro Nero',
                        style: text.bodyLarge?.copyWith(
                          color: AppColors.onBrand.withValues(alpha: 0.8),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
              Padding(
                padding: const EdgeInsets.only(bottom: AppSpace.s16),
                child: Text(
                  'Spend · Pantry · Shopping list',
                  style: text.labelMedium?.copyWith(
                    color: AppColors.onBrand.withValues(alpha: 0.7),
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
