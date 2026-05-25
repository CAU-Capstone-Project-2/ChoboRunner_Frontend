import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_typography.dart';
import '../model/report_metric.dart';
import '../viewmodel/analysis_report_viewmodel.dart';

class MetricDetailScreen extends ConsumerWidget {
  const MetricDetailScreen({
    super.key,
    required this.sessionId,
    required this.metricType,
  });

  final String sessionId;
  final MetricType metricType;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final asyncReport = ref.watch(analysisReportProvider(sessionId));

    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        title: const Text('세부 지표', style: AppTypography.screenTitle),
        backgroundColor: AppColors.background,
        elevation: 0,
        centerTitle: true,
        iconTheme: const IconThemeData(color: AppColors.textPrimary),
      ),
      body: SafeArea(
        child: asyncReport.when(
          loading: () => const Center(
            child: CircularProgressIndicator(color: AppColors.textPrimary),
          ),
          error: (err, _) => const Center(
            child:
                Text('데이터를 불러올 수 없습니다.', style: AppTypography.bodyMuted),
          ),
          data: (report) {
            if (report == null) {
              return const Center(
                child: Text('리포트를 찾을 수 없습니다.',
                    style: AppTypography.bodyMuted),
              );
            }
            final metric = report.metrics.cast<ReportMetric?>().firstWhere(
                  (m) => m!.type == metricType,
                  orElse: () => null,
                );
            if (metric == null) {
              return const Center(
                child: Text('해당 지표 데이터가 없습니다.',
                    style: AppTypography.bodyMuted),
              );
            }
            return SingleChildScrollView(
              padding: const EdgeInsets.fromLTRB(24, 16, 24, 32),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  _Header(metric: metric),
                  const SizedBox(height: 36),
                  _Section(
                    title: '부위별 피드백 요약',
                    body: metric.summary ?? '데이터가 없습니다.',
                  ),
                  const SizedBox(height: 28),
                  _Section(
                    title: '문제점',
                    body: metric.problem ?? '특이사항이 없습니다.',
                  ),
                  const SizedBox(height: 28),
                  _Section(
                    title: '개선 방법',
                    body: metric.improvement ?? '데이터가 없습니다.',
                  ),
                  const SizedBox(height: 28),
                  _ScoreComparison(
                    reference: metric.referenceValue,
                    measured: metric.measuredValue,
                    unit: metric.unit,
                    status: metric.status,
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

class _Header extends StatelessWidget {
  const _Header({required this.metric});
  final ReportMetric metric;

  @override
  Widget build(BuildContext context) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.center,
      children: [
        Expanded(
          child: Text(
            metric.label,
            style: const TextStyle(
              color: AppColors.textPrimary,
              fontSize: 36,
              fontWeight: FontWeight.w700,
              height: 1.15,
              letterSpacing: -0.5,
            ),
          ),
        ),
        const SizedBox(width: 16),
        if (metric.score != null) _LargeScoreCircle(score: metric.score!),
      ],
    );
  }
}

class _LargeScoreCircle extends StatelessWidget {
  const _LargeScoreCircle({required this.score});
  final int score;

  @override
  Widget build(BuildContext context) {
    final color = _scoreColor(score);
    return Container(
      width: 96,
      height: 96,
      alignment: Alignment.center,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        border: Border.all(color: color, width: 3),
      ),
      child: Text(
        '$score',
        style: TextStyle(
          color: color,
          fontSize: 36,
          fontWeight: FontWeight.w700,
        ),
      ),
    );
  }
}

class _Section extends StatelessWidget {
  const _Section({required this.title, required this.body});
  final String title;
  final String body;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(title, style: _sectionTitleStyle),
        const SizedBox(height: 12),
        Center(
          child: Text(
            body,
            textAlign: TextAlign.center,
            style: AppTypography.body.copyWith(fontSize: 15),
          ),
        ),
      ],
    );
  }
}

class _ScoreComparison extends StatelessWidget {
  const _ScoreComparison({
    required this.reference,
    required this.measured,
    required this.unit,
    this.status,
  });

  final double? reference;
  final double? measured;
  final String? unit;
  final String? status;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text('지표 점수들', style: _sectionTitleStyle),
        const SizedBox(height: 16),
        Row(
          children: [
            Expanded(
              child: _ValueColumn(
                label: '기준 값',
                value: reference,
                unit: unit,
              ),
            ),
            Expanded(
              child: _ValueColumn(
                label: '측정 값',
                value: measured,
                unit: unit,
              ),
            ),
          ],
        ),
        if (status != null) ...[
          const SizedBox(height: 16),
          Center(
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
              decoration: BoxDecoration(
                color: status == '주의'
                    ? AppColors.scoreLow.withValues(alpha: 0.15)
                    : AppColors.scoreHigh.withValues(alpha: 0.15),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Text(
                status!,
                style: TextStyle(
                  color:
                      status == '주의' ? AppColors.scoreLow : AppColors.scoreHigh,
                  fontSize: 14,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
          ),
        ],
      ],
    );
  }
}

class _ValueColumn extends StatelessWidget {
  const _ValueColumn({
    required this.label,
    required this.value,
    required this.unit,
  });

  final String label;
  final double? value;
  final String? unit;

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Text(label, style: AppTypography.bodyMuted.copyWith(fontSize: 14)),
        const SizedBox(height: 8),
        Text(
          value == null ? '-' : '${_formatValue(value!)}${unit ?? ''}',
          style: const TextStyle(
            color: AppColors.textPrimary,
            fontSize: 22,
            fontWeight: FontWeight.w700,
          ),
        ),
      ],
    );
  }

  String _formatValue(double v) {
    if (v == v.roundToDouble()) return v.toInt().toString();
    return v.toStringAsFixed(1);
  }
}

const TextStyle _sectionTitleStyle = TextStyle(
  color: AppColors.primaryAction,
  fontSize: 15,
  fontWeight: FontWeight.w600,
);

Color _scoreColor(int score) {
  if (score >= 75) return AppColors.scoreHigh;
  if (score >= 60) return AppColors.scoreMid;
  return AppColors.scoreLow;
}
