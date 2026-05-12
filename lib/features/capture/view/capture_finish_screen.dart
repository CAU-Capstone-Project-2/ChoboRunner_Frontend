import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../../core/router/app_router.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_typography.dart';

class CaptureFinishScreen extends StatelessWidget {
  const CaptureFinishScreen({super.key, this.elapsedSec = 0});

  /// 러닝 경과 시간 (초). URL 쿼리 파라미터로 전달됨.
  final int elapsedSec;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        title: const Text('러닝 종료', style: AppTypography.screenTitle),
        backgroundColor: AppColors.background,
        elevation: 0,
        centerTitle: true,
        // 뒤로 가기 비활성화 — 종료 후 측정 화면으로 돌아가지 않도록.
        automaticallyImplyLeading: false,
      ),
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 24),
          child: Column(
            children: [
              const Spacer(flex: 2),

              // 큰 러닝 아이콘
              const Icon(
                Icons.directions_run,
                size: 200,
                color: AppColors.textPrimary,
              ),

              const Spacer(flex: 2),

              // 러닝 시간 표시
              _RunningTimeRow(elapsedSec: elapsedSec),

              const Spacer(flex: 1),

              // 홈으로 버튼
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
                  onPressed: () => context.go(AppRoutes.home),
                  child: const Text('홈으로', style: AppTypography.primaryButton),
                ),
              ),

              const SizedBox(height: 16),
            ],
          ),
        ),
      ),
    );
  }
}

class _RunningTimeRow extends StatelessWidget {
  const _RunningTimeRow({required this.elapsedSec});
  final int elapsedSec;

  @override
  Widget build(BuildContext context) {
    final mm = (elapsedSec ~/ 60).toString().padLeft(2, '0');
    final ss = (elapsedSec % 60).toString().padLeft(2, '0');

    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      crossAxisAlignment: CrossAxisAlignment.baseline,
      textBaseline: TextBaseline.alphabetic,
      children: [
        const Text('러닝 시간', style: AppTypography.displayMedium),
        const SizedBox(width: 12),
        Text('$mm:$ss', style: AppTypography.displayLarge),
      ],
    );
  }
}
