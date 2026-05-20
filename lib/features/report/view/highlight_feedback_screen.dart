import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_typography.dart';
import '../model/highlight_feedback.dart';
import '../viewmodel/highlight_feedback_viewmodel.dart';

/// 하이라이트 피드백 화면.
///
/// 상단: 하이라이트된 영상 영역 placeholder.
/// 중단: 영상 시간대 라벨 + 전체 영상 길이 대비 하이라이트 구간 타임라인 바.
/// 하단: 사용자 러닝 피드백 문구.
class HighlightFeedbackScreen extends ConsumerWidget {
  const HighlightFeedbackScreen({super.key, required this.sessionId});

  final String sessionId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final feedback = ref.watch(highlightFeedbackProvider(sessionId));

    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        title: const Text('하이라이트 피드백', style: AppTypography.screenTitle),
        backgroundColor: AppColors.background,
        elevation: 0,
        centerTitle: true,
        iconTheme: const IconThemeData(color: AppColors.textPrimary),
      ),
      body: SafeArea(
        child: feedback == null
            ? const Center(
                child: Text(
                  '하이라이트 피드백을 찾을 수 없습니다.',
                  style: AppTypography.bodyMuted,
                ),
              )
            : SingleChildScrollView(
                padding: const EdgeInsets.fromLTRB(20, 16, 20, 32),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    const _VideoPlaceholder(),
                    const SizedBox(height: 28),
                    _TimelineLabel(segments: feedback.segments),
                    const SizedBox(height: 12),
                    _TimelineBar(
                      totalDuration: feedback.totalDuration,
                      segments: feedback.segments,
                    ),
                    const SizedBox(height: 32),
                    Center(
                      child: Text(
                        feedback.message,
                        textAlign: TextAlign.center,
                        style: AppTypography.body.copyWith(fontSize: 15),
                      ),
                    ),
                  ],
                ),
              ),
      ),
    );
  }
}

// ─────────── 영상 영역 placeholder ───────────

class _VideoPlaceholder extends StatelessWidget {
  const _VideoPlaceholder();

  @override
  Widget build(BuildContext context) {
    return AspectRatio(
      aspectRatio: 1,
      child: Container(
        decoration: BoxDecoration(
          color: AppColors.cameraPlaceholder,
          borderRadius: BorderRadius.circular(12),
        ),
        alignment: Alignment.center,
        child: const Text(
          '하이라이트된 영상 나오는 부분',
          style: TextStyle(
            color: Colors.white,
            fontSize: 14,
            fontWeight: FontWeight.w500,
          ),
        ),
      ),
    );
  }
}

// ─────────── 시간대 라벨 ───────────

class _TimelineLabel extends StatelessWidget {
  const _TimelineLabel({required this.segments});
  final List<HighlightSegment> segments;

  @override
  Widget build(BuildContext context) {
    final example = segments.isNotEmpty
        ? '${_format(segments.first.start)}~${_format(segments.first.end)}'
        : '-';
    return Center(
      child: Text(
        '영상의 시간대 ( Ex. $example )',
        style: AppTypography.bodyMuted.copyWith(fontSize: 14),
      ),
    );
  }

  static String _format(Duration d) {
    final m = d.inMinutes;
    final s = d.inSeconds.remainder(60).toString().padLeft(2, '0');
    return '$m:$s';
  }
}

// ─────────── 타임라인 바 ───────────

class _TimelineBar extends StatelessWidget {
  const _TimelineBar({
    required this.totalDuration,
    required this.segments,
  });

  final Duration totalDuration;
  final List<HighlightSegment> segments;

  static const double _barHeight = 12;
  static const double _minMarkerWidth = 8;

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final width = constraints.maxWidth;
        final totalMs = totalDuration.inMilliseconds;
        return SizedBox(
          height: _barHeight,
          child: Stack(
            children: [
              Container(
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(_barHeight / 2),
                ),
              ),
              if (totalMs > 0)
                ...segments.map((seg) {
                  final startRatio =
                      (seg.start.inMilliseconds / totalMs).clamp(0.0, 1.0);
                  final endRatio =
                      (seg.end.inMilliseconds / totalMs).clamp(0.0, 1.0);
                  final left = startRatio * width;
                  final markerWidth =
                      ((endRatio - startRatio) * width).clamp(_minMarkerWidth, width);
                  return Positioned(
                    left: left,
                    top: 0,
                    bottom: 0,
                    width: markerWidth,
                    child: Container(
                      decoration: BoxDecoration(
                        color: AppColors.primaryAction,
                        borderRadius: BorderRadius.circular(_barHeight / 2),
                      ),
                    ),
                  );
                }),
            ],
          ),
        );
      },
    );
  }
}
