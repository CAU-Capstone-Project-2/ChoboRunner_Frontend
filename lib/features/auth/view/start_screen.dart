import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../../core/router/app_router.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_typography.dart';

/// 앱 첫 진입 화면 (로그인 전).
///
/// 로고 + 로그인/회원가입 진입 버튼 두 개.
class StartScreen extends StatelessWidget {
  const StartScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 32),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              const Spacer(flex: 3),
              const Icon(
                Icons.directions_run,
                color: AppColors.primaryAction,
                size: 96,
              ),
              const SizedBox(height: 16),
              const Text(
                'Chobo Runner',
                textAlign: TextAlign.center,
                style: AppTypography.brandTitle,
              ),
              const Spacer(flex: 4),
              SizedBox(
                height: 56,
                child: FilledButton(
                  style: FilledButton.styleFrom(
                    backgroundColor: AppColors.primaryAction,
                    foregroundColor: AppColors.primaryActionText,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(28),
                    ),
                  ),
                  onPressed: () => context.push(AppRoutes.login),
                  child: const Text('로그인', style: AppTypography.primaryButton),
                ),
              ),
              const SizedBox(height: 12),
              SizedBox(
                height: 56,
                child: FilledButton(
                  style: FilledButton.styleFrom(
                    backgroundColor: AppColors.secondaryAction,
                    foregroundColor: AppColors.secondaryActionText,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(28),
                    ),
                  ),
                  onPressed: () => context.push(AppRoutes.signup),
                  child: const Text(
                    '회원가입',
                    style: TextStyle(
                      color: AppColors.secondaryActionText,
                      fontSize: 16,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
              ),
              const SizedBox(height: 40),
            ],
          ),
        ),
      ),
    );
  }
}
