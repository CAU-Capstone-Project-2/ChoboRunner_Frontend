import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_typography.dart';
import '../model/report_metric.dart';
import '../viewmodel/analysis_report_viewmodel.dart';

/// 세부 지표 화면.
///
/// 분석 리포트 → 항목별 카드 탭으로 진입. 단일 metric의 점수와
/// 부위별 피드백 요약 / 문제점 / 개선 방법 / 지표 점수들(기준값 vs 측정값)을 표시.
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
    final report = ref.watch(analysisReportProvider(sessionId));
    final metric = report?.metrics.firstWhere(
      (m) => m.type == metricType,
      orElse: () => ReportMetric(type: metricType, score: 0),
    );

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
        child: metric == null
            ? const Center(
                child: Text(
                  '리포트를 찾을 수 없습니다.',
                  style: AppTypography.bodyMuted,
                ),
              )
            : SingleChildScrollView(
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
                    ),
                  ],
                ),
              ),
      ),
    );
  }
}

// ─────────── 헤더: 큰 타이틀 + 점수 원 ───────────

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
        _LargeScoreCircle(score: metric.score),
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

// ─────────── 일반 섹션 (라임 헤더 + 본문) ───────────

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

// ─────────── 지표 점수들 섹션 (기준 값 / 측정 값) ───────────

class _ScoreComparison extends StatelessWidget {
  const _ScoreComparison({
    required this.reference,
    required this.measured,
    required this.unit,
  });

  final double? reference;
  final double? measured;
  final String? unit;

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
        Text(
          label,
          style: AppTypography.bodyMuted.copyWith(fontSize: 14),
        ),
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

// ─────────── 공통 ───────────

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
