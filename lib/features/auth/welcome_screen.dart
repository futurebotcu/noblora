import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import '../../core/theme/app_colors.dart';
import '../../core/theme/app_spacing.dart';
import '../../core/theme/app_tokens.dart';
import '../../core/theme/premium.dart';
import '../../shared/widgets/app_button.dart';
import 'sign_in_screen.dart';
import 'sign_up_screen.dart';

class WelcomeScreen extends StatelessWidget {
  const WelcomeScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: context.bgColor,
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: AppSpacing.xxl),
          child: Column(
            children: [
              const Spacer(flex: 2),
              Text(
                'Noblara',
                style: GoogleFonts.playfairDisplay(
                  fontSize: 52,
                  fontWeight: FontWeight.w700,
                  color: AppColors.emerald500,
                  letterSpacing: 4,
                ),
              ),
              const SizedBox(height: AppSpacing.sm),
              Text(
                'Where elegance meets connection.',
                style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                      color: context.textMuted,
                      letterSpacing: 0.5,
                    ),
                textAlign: TextAlign.center,
              ),
              const Spacer(flex: 3),
              Container(
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(AppSpacing.radiusMd),
                  boxShadow: Premium.emeraldGlow(intensity: 0.7),
                ),
                child: AppButton(
                  label: 'Sign In',
                  onPressed: () => Navigator.of(context).push(
                    MaterialPageRoute(builder: (_) => const SignInScreen()),
                  ),
                ),
              ),
              const SizedBox(height: AppSpacing.md),
              AppButton(
                label: 'Create Account',
                variant: AppButtonVariant.outline,
                onPressed: () => Navigator.of(context).push(
                  MaterialPageRoute(builder: (_) => const SignUpScreen()),
                ),
              ),
              const SizedBox(height: AppSpacing.xxxl),
            ],
          ),
        ),
      ),
    );
  }
}
