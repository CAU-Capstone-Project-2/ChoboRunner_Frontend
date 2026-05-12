import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../../core/router/app_router.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_typography.dart';

/// 임시 홈 화면. 측정 진입만 가능. 본격적인 홈 화면은 추후 별도 구현.
class HomeScreen extends StatelessWidget {
  const HomeScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        title: const Text('ChoboRunner', style: AppTypography.screenTitle),
        backgroundColor: AppColors.background,
        elevation: 0,
        centerTitle: true,
      ),
      body: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(
              Icons.directions_run,
              size: 96,
              color: AppColors.primaryAction,
            ),
            const SizedBox(height: 24),
            const Text('러닝을 시작해볼까요?', style: AppTypography.displayMedium),
            const SizedBox(height: 8),
            const Text(
              '버튼을 눌러 자세 분석을 시작합니다',
              style: AppTypography.bodyMuted,
            ),
            const SizedBox(height: 40),
            SizedBox(
              width: double.infinity,
              height: 52,
              child: FilledButton(
                style: FilledButton.styleFrom(
                  backgroundColor: AppColors.primaryAction,
                  foregroundColor: AppColors.primaryActionText,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(26),
                  ),
                ),
                // 촬영 설정 화면을 거쳐 측정 화면으로 진입.
                onPressed: () => context.go(AppRoutes.captureSetup),
                child: const Text('러닝 측정 시작', style: AppTypography.primaryButton),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
