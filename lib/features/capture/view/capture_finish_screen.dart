import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/router/app_router.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_typography.dart';
import '../../report/viewmodel/report_list_viewmodel.dart';
import '../model/analysis_result_message.dart';
import '../viewmodel/capture_websocket_viewmodel.dart';

class CaptureFinishScreen extends ConsumerStatefulWidget {
  const CaptureFinishScreen({super.key, this.elapsedSec = 0});

  final int elapsedSec;

  @override
  ConsumerState<CaptureFinishScreen> createState() =>
      _CaptureFinishScreenState();
}

class _CaptureFinishScreenState extends ConsumerState<CaptureFinishScreen> {
  bool _disconnected = false;

  void _disconnectOnce() {
    if (_disconnected) return;
    _disconnected = true;
    ref.read(captureWebSocketViewModelProvider.notifier).disconnect();
  }

  @override
  Widget build(BuildContext context) {
    final wsState = ref.watch(captureWebSocketViewModelProvider);
    final hasResult = wsState.hasFinalResult;

    if (hasResult && !_disconnected) {
      WidgetsBinding.instance.addPostFrameCallback((_) => _disconnectOnce());
    }

    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        title: Text(
          hasResult ? '러닝 종료' : '분석 중',
          style: AppTypography.screenTitle,
        ),
        backgroundColor: AppColors.background,
        elevation: 0,
        centerTitle: true,
        automaticallyImplyLeading: false,
      ),
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 24),
          child: hasResult
              ? _CompletedBody(
                  elapsedSec: widget.elapsedSec,
                  isFailed: wsState.finalResult?.status ==
                      AnalysisStatus.failed,
                  onGoHome: () {
                    ref
                        .read(captureWebSocketViewModelProvider.notifier)
                        .releaseCamera();
                    ref.invalidate(reportListProvider);
                    context.go(AppRoutes.home);
                  },
                )
              : _AnalyzingBody(elapsedSec: widget.elapsedSec),
        ),
      ),
    );
  }
}

// ─────────── 분석 대기 화면 ───────────

class _AnalyzingBody extends StatelessWidget {
  const _AnalyzingBody({required this.elapsedSec});
  final int elapsedSec;

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        const Spacer(flex: 2),

        const SizedBox(
          width: 64,
          height: 64,
          child: CircularProgressIndicator(
            strokeWidth: 4,
            color: AppColors.primaryAction,
          ),
        ),

        const SizedBox(height: 32),

        const Text('러닝 데이터를 분석하고 있습니다', style: AppTypography.body),
        const SizedBox(height: 8),
        const Text(
          '잠시만 기다려 주세요...',
          style: AppTypography.bodyMuted,
        ),

        const Spacer(flex: 1),

        _RunningTimeRow(elapsedSec: elapsedSec),

        const Spacer(flex: 2),
      ],
    );
  }
}

// ─────────── 분석 완료 화면 ───────────

class _CompletedBody extends StatelessWidget {
  const _CompletedBody({
    required this.elapsedSec,
    required this.isFailed,
    required this.onGoHome,
  });

  final int elapsedSec;
  final bool isFailed;
  final VoidCallback onGoHome;

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        const Spacer(flex: 2),

        Icon(
          isFailed ? Icons.refresh : Icons.check_circle_outline,
          size: 120,
          color: isFailed ? AppColors.statusError : AppColors.primaryAction,
        ),

        const SizedBox(height: 24),

        Text(
          isFailed ? '재촬영 필요' : '측정 성공',
          style: AppTypography.displayMedium.copyWith(
            color: isFailed ? AppColors.statusError : AppColors.primaryAction,
            fontSize: 24,
          ),
        ),

        if (isFailed) ...[
          const SizedBox(height: 8),
          const Text(
            '분석에 실패했습니다. 다시 촬영해 주세요.',
            style: AppTypography.bodyMuted,
          ),
        ],

        const Spacer(flex: 2),

        _RunningTimeRow(elapsedSec: elapsedSec),

        const Spacer(flex: 1),

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
            onPressed: onGoHome,
            child: const Text('홈으로', style: AppTypography.primaryButton),
          ),
        ),

        const SizedBox(height: 16),
      ],
    );
  }
}

// ─────────── 러닝 시간 표시 ───────────

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
