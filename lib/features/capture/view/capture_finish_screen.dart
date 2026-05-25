import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/router/app_router.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_typography.dart';
import '../model/analysis_result_message.dart';
import '../viewmodel/capture_websocket_viewmodel.dart';

class CaptureFinishScreen extends ConsumerWidget {
  const CaptureFinishScreen({super.key, this.elapsedSec = 0});

  final int elapsedSec;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final wsState = ref.watch(captureWebSocketViewModelProvider);
    final result = wsState.finalResult;

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
        child: Column(
          children: [
            // 러닝 시간
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 16),
              child: _RunningTimeRow(elapsedSec: elapsedSec),
            ),

            // analysis_result 디버그 영역
            Expanded(
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16),
                child: Container(
                  width: double.infinity,
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: AppColors.surface,
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: SingleChildScrollView(
                    child: result != null
                        ? SelectableText(
                            _formatResult(result),
                            style: const TextStyle(
                              color: AppColors.textPrimary,
                              fontSize: 12,
                              fontFamily: 'monospace',
                            ),
                          )
                        : Column(
                            children: [
                              const SizedBox(height: 40),
                              const CircularProgressIndicator(
                                color: AppColors.primaryAction,
                              ),
                              const SizedBox(height: 16),
                              Text(
                                'analysis_result 대기 중...\n'
                                'runId: ${wsState.currentRunId ?? "없음"}\n'
                                'WS: ${wsState.status.name}',
                                textAlign: TextAlign.center,
                                style: const TextStyle(
                                  color: AppColors.textSecondary,
                                  fontSize: 13,
                                ),
                              ),
                            ],
                          ),
                  ),
                ),
              ),
            ),

            // 홈으로 버튼
            Padding(
              padding: const EdgeInsets.fromLTRB(24, 12, 24, 16),
              child: SizedBox(
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
                  child:
                      const Text('홈으로', style: AppTypography.primaryButton),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  String _formatResult(AnalysisResultMessage r) {
    final buf = StringBuffer();
    buf.writeln('=== analysis_result ===');
    buf.writeln('status: ${r.status.name}');
    buf.writeln('analysisSide: ${r.analysisSide ?? "null"}');
    buf.writeln('message: ${r.message ?? "null"}');
    buf.writeln('primaryReasonCode: ${r.primaryReasonCode ?? "null"}');
    buf.writeln('reasonCodes: ${r.reasonCodes}');
    buf.writeln();

    if (r.metrics != null) {
      final m = r.metrics!;
      buf.writeln('--- metrics ---');
      buf.writeln('footStrikePattern: ${m.footStrikePattern.name}');
      buf.writeln('footStrikeAngleDeg: ${m.footStrikeAngleDeg}');
      buf.writeln('initialKneeFlexionDeg: ${m.initialKneeFlexionDeg}');
      buf.writeln('trunkLeanDeg: ${m.trunkLeanDeg}');
      buf.writeln();
    }

    if (r.metricDetails != null && r.metricDetails!.isNotEmpty) {
      buf.writeln('--- metricDetails ---');
      for (final e in r.metricDetails!.entries) {
        buf.writeln('${e.key}:');
        buf.writeln('  median: ${e.value.median}');
        buf.writeln('  iqr: ${e.value.iqr}');
        buf.writeln('  nStrides: ${e.value.nStrides}');
      }
      buf.writeln();
    }

    final v = r.videoMeta;
    buf.writeln('--- videoMeta ---');
    buf.writeln('durationSec: ${v.durationSec}');
    buf.writeln('fpsActual: ${v.fpsActual}');
    buf.writeln('resolution: ${v.resolution.width}x${v.resolution.height}');
    buf.writeln('totalFrames: ${v.totalFrames}');
    buf.writeln();

    if (r.qualitySummary != null) {
      final q = r.qualitySummary!;
      buf.writeln('--- qualitySummary ---');
      buf.writeln('validFrameRatio: ${q.validFrameRatio}');
      buf.writeln('icCandidateCount: ${q.icCandidateCount}');
      buf.writeln('validStrideCount: ${q.validStrideCount}');
      buf.writeln('landmarkVisibilityAvg: ${q.landmarkVisibilityAvg}');
      buf.writeln('trackingStability: ${q.targetTrackingStability.name}');
      buf.writeln();
    }

    if (r.feedbackMessages.isNotEmpty) {
      buf.writeln('--- feedbackMessages (${r.feedbackMessages.length}) ---');
      for (final f in r.feedbackMessages) {
        buf.writeln('[${f.category.name}] metric=${f.metric}');
        buf.writeln('  display: ${f.displayText}');
        buf.writeln('  tts: ${f.ttsText}');
        buf.writeln('  priority=${f.priority} ttsEnabled=${f.ttsEnabled} '
            'confidencePrefix=${f.confidencePrefix}');
      }
    }

    return buf.toString();
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
