import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/router/app_router.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_typography.dart';
import '../model/report_session.dart';
import '../viewmodel/report_list_viewmodel.dart';

class ReportListScreen extends ConsumerWidget {
  const ReportListScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final asyncSessions = ref.watch(reportListProvider);

    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        title: const Text('러닝 분석', style: AppTypography.screenTitle),
        backgroundColor: AppColors.background,
        elevation: 0,
        centerTitle: true,
        iconTheme: const IconThemeData(color: AppColors.textPrimary),
      ),
      body: SafeArea(
        child: asyncSessions.when(
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
                  onPressed: () => ref.invalidate(reportListProvider),
                  child: const Text('다시 시도'),
                ),
              ],
            ),
          ),
          data: (sessions) {
            if (sessions.isEmpty) {
              return const Center(
                child: Text('완료된 러닝 기록이 없습니다.',
                    style: AppTypography.bodyMuted),
              );
            }
            return ListView.separated(
              padding: const EdgeInsets.fromLTRB(16, 16, 16, 24),
              itemCount: sessions.length,
              separatorBuilder: (_, __) => const SizedBox(height: 12),
              itemBuilder: (context, i) =>
                  _SessionCard(session: sessions[i]),
            );
          },
        ),
      ),
    );
  }
}

class _SessionCard extends StatelessWidget {
  const _SessionCard({required this.session});
  final ReportSession session;

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppColors.divider, width: 1),
      ),
      padding: const EdgeInsets.fromLTRB(16, 14, 16, 14),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      _formatDate(session.date),
                      style: AppTypography.body.copyWith(
                        fontSize: 16,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    if (session.duration != null) ...[
                      const SizedBox(height: 4),
                      Text(
                        _formatDuration(session.duration!),
                        style: AppTypography.bodyMuted.copyWith(fontSize: 13),
                      ),
                    ],
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              Expanded(
                child: Builder(
                  builder: (context) => _PillButton(
                    label: '분석 리포트',
                    filled: true,
                    onPressed: () => context.push(
                      AppRoutes.analysisReport(session.id),
                    ),
                  ),
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Builder(
                  builder: (context) => _PillButton(
                    label: '하이라이트 피드백',
                    filled: false,
                    onPressed: () => context.push(
                      AppRoutes.highlightFeedback(session.id),
                    ),
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  String _formatDate(DateTime d) {
    final y = d.year.toString().padLeft(4, '0');
    final m = d.month.toString().padLeft(2, '0');
    final day = d.day.toString().padLeft(2, '0');
    final h = d.hour.toString().padLeft(2, '0');
    final min = d.minute.toString().padLeft(2, '0');
    return '$y-$m-$day $h:$min';
  }

  String _formatDuration(int sec) {
    final mm = (sec ~/ 60).toString();
    final ss = (sec % 60).toString().padLeft(2, '0');
    return '$mm분 $ss초';
  }
}

class _PillButton extends StatelessWidget {
  const _PillButton({
    required this.label,
    required this.filled,
    required this.onPressed,
  });

  final String label;
  final bool filled;
  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) {
    if (filled) {
      return SizedBox(
        height: 36,
        child: FilledButton(
          style: FilledButton.styleFrom(
            backgroundColor: AppColors.cameraPlaceholder,
            foregroundColor: AppColors.primaryActionText,
            padding: EdgeInsets.zero,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(18),
            ),
          ),
          onPressed: onPressed,
          child: Text(
            label,
            style: const TextStyle(
              fontSize: 13,
              fontWeight: FontWeight.w600,
            ),
          ),
        ),
      );
    }
    return SizedBox(
      height: 36,
      child: OutlinedButton(
        style: OutlinedButton.styleFrom(
          foregroundColor: AppColors.primaryAction,
          side: const BorderSide(color: AppColors.primaryAction, width: 1.5),
          padding: EdgeInsets.zero,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(18),
          ),
        ),
        onPressed: onPressed,
        child: Text(
          label,
          style: const TextStyle(
            fontSize: 13,
            fontWeight: FontWeight.w600,
          ),
        ),
      ),
    );
  }
}
