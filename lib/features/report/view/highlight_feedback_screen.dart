import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_typography.dart';
import '../model/highlight_feedback.dart';
import '../viewmodel/highlight_feedback_viewmodel.dart';

class HighlightFeedbackScreen extends ConsumerWidget {
  const HighlightFeedbackScreen({super.key, required this.sessionId});

  final String sessionId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final asyncFeedback = ref.watch(highlightFeedbackProvider(sessionId));

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
        child: asyncFeedback.when(
          loading: () => const Center(
            child: CircularProgressIndicator(color: AppColors.textPrimary),
          ),
          error: (err, _) => Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Text('데이터를 불러올 수 없습니다.',
                    style: AppTypography.bodyMuted),
                const SizedBox(height: 12),
                FilledButton(
                  onPressed: () =>
                      ref.invalidate(highlightFeedbackProvider(sessionId)),
                  child: const Text('다시 시도'),
                ),
              ],
            ),
          ),
          data: (feedback) {
            if (feedback == null) {
              return const Center(
                child: Text(
                  '하이라이트 피드백이 없습니다.',
                  style: AppTypography.bodyMuted,
                ),
              );
            }
            return SingleChildScrollView(
              padding: const EdgeInsets.fromLTRB(20, 16, 20, 32),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  const _VideoPlaceholder(),
                  const SizedBox(height: 28),
                  if (feedback.segments.isNotEmpty) ...[
                    _TimelineLabel(segments: feedback.segments),
                    const SizedBox(height: 12),
                    _TimelineBar(
                      totalDuration: feedback.totalDuration,
                      segments: feedback.segments,
                    ),
                    const SizedBox(height: 24),
                    ...feedback.segments.map(
                      (seg) => Padding(
                        padding: const EdgeInsets.only(bottom: 12),
                        child: _SegmentCard(segment: seg),
                      ),
                    ),
                    const SizedBox(height: 8),
                  ],
                  Center(
                    child: Text(
                      feedback.message,
                      textAlign: TextAlign.center,
                      style: AppTypography.body.copyWith(fontSize: 15),
                    ),
                  ),
                ],
              ),
            );
          },
        ),
      ),
    );
  }
}

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
                  final markerWidth = ((endRatio - startRatio) * width)
                      .clamp(_minMarkerWidth, width);
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

class _SegmentCard extends StatelessWidget {
  const _SegmentCard({required this.segment});
  final HighlightSegment segment;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppColors.divider, width: 1),
      ),
      child: Row(
        children: [
          Container(
            width: 4,
            height: 36,
            decoration: BoxDecoration(
              color: AppColors.primaryAction,
              borderRadius: BorderRadius.circular(2),
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  '${_format(segment.start)} ~ ${_format(segment.end)}'
                  '${segment.issueType != null ? '  [${segment.issueType}]' : ''}',
                  style: AppTypography.bodyMuted.copyWith(fontSize: 12),
                ),
                if (segment.message != null) ...[
                  const SizedBox(height: 4),
                  Text(
                    segment.message!,
                    style: AppTypography.body.copyWith(fontSize: 13),
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                  ),
                ],
              ],
            ),
          ),
        ],
      ),
    );
  }

  static String _format(Duration d) {
    final m = d.inMinutes;
    final s = d.inSeconds.remainder(60).toString().padLeft(2, '0');
    return '$m:$s';
  }
}
