import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:video_player/video_player.dart';

import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_typography.dart';
import '../model/highlight_feedback.dart';
import '../model/report_metric.dart';
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
            return _HighlightBody(feedback: feedback);
          },
        ),
      ),
    );
  }
}

// ─────────── 메인 바디 (영상 + 타임라인 + 피드백) ───────────

class _HighlightBody extends StatefulWidget {
  const _HighlightBody({required this.feedback});
  final HighlightFeedback feedback;

  @override
  State<_HighlightBody> createState() => _HighlightBodyState();
}

class _HighlightBodyState extends State<_HighlightBody> {
  VideoPlayerController? _videoController;
  int? _selectedIndex;
  Timer? _loopTimer;

  HighlightFeedback get feedback => widget.feedback;

  @override
  void initState() {
    super.initState();
    _initVideo();
  }

  Future<void> _initVideo() async {
    final url = feedback.videoUrl;
    if (url == null) return;

    final controller = VideoPlayerController.networkUrl(Uri.parse(url));
    _videoController = controller;

    try {
      await controller.initialize();
      if (mounted) setState(() {});
    } catch (_) {}
  }

  @override
  void dispose() {
    _loopTimer?.cancel();
    _videoController?.dispose();
    super.dispose();
  }

  void _onSegmentTap(int index) {
    final controller = _videoController;
    if (controller == null || !controller.value.isInitialized) return;

    final seg = feedback.segments[index];

    setState(() => _selectedIndex = index);

    controller.seekTo(seg.start);
    controller.play();

    _loopTimer?.cancel();
    _loopTimer = Timer.periodic(const Duration(milliseconds: 200), (_) {
      if (!mounted || _selectedIndex != index) {
        _loopTimer?.cancel();
        return;
      }
      final pos = controller.value.position;
      if (pos >= seg.end) {
        controller.seekTo(seg.start);
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    final selectedSeg =
        _selectedIndex != null ? feedback.segments[_selectedIndex!] : null;

    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 8, 20, 8),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // 영상 (7할)
          Expanded(
            flex: 7,
            child: _VideoArea(
              controller: _videoController,
              hasVideoUrl: feedback.videoUrl != null,
            ),
          ),

          const SizedBox(height: 12),

          // 타임라인 + 피드백 (3할)
          if (feedback.segments.isNotEmpty)
            Expanded(
              flex: 3,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  _TimelineBar(
                    totalDuration: feedback.totalDuration,
                    segments: feedback.segments,
                    selectedIndex: _selectedIndex,
                    onSegmentTap: _onSegmentTap,
                  ),
                  const SizedBox(height: 12),
                  Expanded(
                    child: selectedSeg != null
                        ? _SegmentCard(segment: selectedSeg)
                        : Center(
                            child: Text(
                              '타임라인의 하이라이트 구간을 탭하세요',
                              style: AppTypography.bodyMuted
                                  .copyWith(fontSize: 14),
                            ),
                          ),
                  ),
                ],
              ),
            ),

          if (feedback.segments.isEmpty)
            Expanded(
              flex: 3,
              child: Center(
                child: Text(
                  feedback.message,
                  textAlign: TextAlign.center,
                  style: AppTypography.body.copyWith(fontSize: 15),
                ),
              ),
            ),
        ],
      ),
    );
  }
}

// ─────────── 영상 영역 ───────────

class _VideoArea extends StatelessWidget {
  const _VideoArea({required this.controller, required this.hasVideoUrl});
  final VideoPlayerController? controller;
  final bool hasVideoUrl;

  @override
  Widget build(BuildContext context) {
    final ctrl = controller;

    if (ctrl == null || !ctrl.value.isInitialized) {
      return AspectRatio(
        aspectRatio: 16 / 9,
        child: Container(
          decoration: BoxDecoration(
            color: AppColors.surface,
            borderRadius: BorderRadius.circular(12),
          ),
          alignment: Alignment.center,
          child: hasVideoUrl
              ? const CircularProgressIndicator(
                  color: AppColors.textMuted, strokeWidth: 2)
              : const Text(
                  '하이라이트 영상이 존재하지 않습니다',
                  style: AppTypography.bodyMuted,
                ),
        ),
      );
    }

    // 영상은 native 비율 유지하면서 영역을 꽉 채우고 넘치는 좌우는 잘라냄.
    // (landscape 영상이 portrait 영역에 letterbox로 작게 보이는 문제 해결)
    return ClipRRect(
      borderRadius: BorderRadius.circular(12),
      child: LayoutBuilder(
        builder: (context, constraints) {
          return SizedBox(
            width: constraints.maxWidth,
            height: constraints.maxHeight,
            child: FittedBox(
              fit: BoxFit.cover,
              clipBehavior: Clip.hardEdge,
              child: SizedBox(
                width: ctrl.value.size.width,
                height: ctrl.value.size.height,
                child: VideoPlayer(ctrl),
              ),
            ),
          );
        },
      ),
    );
  }
}

// ─────────── 인터랙티브 타임라인 바 ───────────

class _TimelineBar extends StatelessWidget {
  const _TimelineBar({
    required this.totalDuration,
    required this.segments,
    required this.selectedIndex,
    required this.onSegmentTap,
  });

  final Duration totalDuration;
  final List<HighlightSegment> segments;
  final int? selectedIndex;
  final ValueChanged<int> onSegmentTap;

  static const double _barHeight = 36;
  static const double _minMarkerWidth = 12;

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
              // 배경 바
              Container(
                decoration: BoxDecoration(
                  color: AppColors.surface,
                  borderRadius: BorderRadius.circular(_barHeight / 2),
                  border: Border.all(color: AppColors.divider, width: 1),
                ),
              ),
              // 세그먼트 마커
              if (totalMs > 0)
                ...List.generate(segments.length, (i) {
                  final seg = segments[i];
                  final startRatio =
                      (seg.start.inMilliseconds / totalMs).clamp(0.0, 1.0);
                  final endRatio =
                      (seg.end.inMilliseconds / totalMs).clamp(0.0, 1.0);
                  final left = startRatio * width;
                  final markerWidth = ((endRatio - startRatio) * width)
                      .clamp(_minMarkerWidth, width);
                  final isSelected = selectedIndex == i;

                  return Positioned(
                    left: left,
                    top: 0,
                    bottom: 0,
                    width: markerWidth,
                    child: GestureDetector(
                      onTap: () => onSegmentTap(i),
                      child: Container(
                        decoration: BoxDecoration(
                          color: isSelected
                              ? AppColors.primaryAction
                              : AppColors.primaryAction.withValues(alpha: 0.5),
                          borderRadius:
                              BorderRadius.circular(_barHeight / 2),
                          border: isSelected
                              ? Border.all(
                                  color: Colors.white, width: 2)
                              : null,
                        ),
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

// ─────────── 세그먼트 카드 ───────────

class _SegmentCard extends StatelessWidget {
  const _SegmentCard({required this.segment});
  final HighlightSegment segment;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppColors.primaryAction, width: 1.5),
      ),
      child: Row(
        children: [
          Container(
            width: 4,
            height: 40,
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
                  '${_issueLabel(segment.issueType)}',
                  style: AppTypography.bodyMuted.copyWith(fontSize: 12),
                ),
                if (segment.message != null) ...[
                  const SizedBox(height: 6),
                  Text(
                    segment.message!,
                    style: AppTypography.body.copyWith(fontSize: 14),
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

  static String _issueLabel(String? issueType) {
    if (issueType == null || issueType.isEmpty) return '';
    final mapped = MetricType.fromBackendType(issueType)?.label ?? issueType;
    return '  [$mapped]';
  }
}
