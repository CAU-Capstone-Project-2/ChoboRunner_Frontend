import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/router/app_router.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_typography.dart';
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
    final result = wsState.finalResult;

    if (result != null && !_disconnected) {
      WidgetsBinding.instance.addPostFrameCallback((_) => _disconnectOnce());
    }

    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        title: const Text('러닝 종료', style: AppTypography.screenTitle),
        backgroundColor: AppColors.background,
        elevation: 0,
        centerTitle: true,
        automaticallyImplyLeading: false,
      ),
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 24),
          child: Column(
            children: [
              const Spacer(flex: 2),

              const Icon(
                Icons.directions_run,
                size: 200,
                color: AppColors.textPrimary,
              ),

              const Spacer(flex: 2),

              _RunningTimeRow(elapsedSec: widget.elapsedSec),

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
                  onPressed: () {
                    ref
                        .read(captureWebSocketViewModelProvider.notifier)
                        .releaseCamera();
                    context.go(AppRoutes.home);
                  },
                  child:
                      const Text('홈으로', style: AppTypography.primaryButton),
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
