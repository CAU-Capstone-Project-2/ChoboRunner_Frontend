import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/router/app_router.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_typography.dart';
import '../model/report_metric.dart';
import '../viewmodel/analysis_report_viewmodel.dart';

class AnalysisReportScreen extends ConsumerWidget {
  const AnalysisReportScreen({super.key, required this.sessionId});

  final String sessionId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final asyncReport = ref.watch(analysisReportProvider(sessionId));

    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        title: const Text('분석 리포트', style: AppTypography.screenTitle),
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
          error: (err, _) => Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Text('리포트를 불러올 수 없습니다.',
                    style: AppTypography.bodyMuted),
                const SizedBox(height: 12),
                FilledButton(
                  onPressed: () =>
                      ref.invalidate(analysisReportProvider(sessionId)),
                  child: const Text('다시 시도'),
                ),
              ],
            ),
          ),
          data: (report) {
            if (report == null) {
              return const Center(
                child: Text(
                  '아직 분석 리포트가 생성되지 않았습니다.\n잠시 후 다시 시도해주세요.',
                  textAlign: TextAlign.center,
                  style: AppTypography.bodyMuted,
                ),
              );
            }
            final scoredMetrics = report.metrics
                .where((m) => m.type.hasScore)
                .toList();
            final footStrikeMetric = report.metrics
                .cast<ReportMetric?>()
                .firstWhere(
                  (m) => m!.type == MetricType.footStrikePattern,
                  orElse: () => null,
                );

            return ListView(
              padding: const EdgeInsets.fromLTRB(16, 16, 16, 24),
              children: [
                if (scoredMetrics.isNotEmpty)
                  _ScoreChartCard(metrics: scoredMetrics),
                if (footStrikeMetric != null) ...[
                  const SizedBox(height: 12),
                  _FootStrikePatternCard(metric: footStrikeMetric),
                ],
                const SizedBox(height: 24),
                if (report.totalFeedback != null &&
                    report.totalFeedback!.isNotEmpty) ...[
                  const Padding(
                    padding: EdgeInsets.symmetric(horizontal: 4),
                    child: Text('전체 피드백 내용',
                        style: AppTypography.displayMedium),
                  ),
                  const SizedBox(height: 8),
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 4),
                    child: Text(
                      report.totalFeedback!,
                      style: AppTypography.body.copyWith(fontSize: 14),
                    ),
                  ),
                  const SizedBox(height: 20),
                ],
                ...report.metrics.map(
                  (m) => Padding(
                    padding: const EdgeInsets.only(bottom: 12),
                    child: _MetricEntryCard(
                      metric: m,
                      onTap: () => context.push(
                        AppRoutes.metricDetail(sessionId, m.type.name),
                      ),
                    ),
                  ),
                ),
              ],
            );
          },
        ),
      ),
    );
  }
}

class _ScoreChartCard extends StatelessWidget {
  const _ScoreChartCard({required this.metrics});

  final List<ReportMetric> metrics;

  static const double _chartHeight = 200;
  static const double _labelHeight = 36;
  static const double _circleSize = 36;
  static const double _topPadding = _circleSize / 2 + 4;

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(16),
      ),
      padding: const EdgeInsets.fromLTRB(20, 20, 20, 16),
      child: SizedBox(
        height: _topPadding + _chartHeight + _labelHeight,
        child: Stack(
          clipBehavior: Clip.none,
          children: [
            Padding(
              padding: const EdgeInsets.only(top: _topPadding),
              child: BarChart(
                BarChartData(
                  alignment: BarChartAlignment.spaceAround,
                  maxY: 100,
                  minY: 0,
                  barTouchData: BarTouchData(enabled: false),
                  gridData: const FlGridData(show: false),
                  borderData: FlBorderData(show: false),
                  titlesData: FlTitlesData(
                    leftTitles: const AxisTitles(
                        sideTitles: SideTitles(showTitles: false)),
                    rightTitles: const AxisTitles(
                        sideTitles: SideTitles(showTitles: false)),
                    topTitles: const AxisTitles(
                        sideTitles: SideTitles(showTitles: false)),
                    bottomTitles: AxisTitles(
                      sideTitles: SideTitles(
                        showTitles: true,
                        reservedSize: _labelHeight,
                        getTitlesWidget: (value, meta) {
                          final i = value.toInt();
                          if (i < 0 || i >= metrics.length) {
                            return const SizedBox.shrink();
                          }
                          return Padding(
                            padding: const EdgeInsets.only(top: 8),
                            child: Text(
                              metrics[i].label,
                              style: const TextStyle(
                                color: AppColors.textPrimary,
                                fontSize: 12,
                                fontWeight: FontWeight.w500,
                              ),
                            ),
                          );
                        },
                      ),
                    ),
                  ),
                  barGroups: List.generate(metrics.length, (i) {
                    final m = metrics[i];
                    final score = m.displayScore.toDouble();
                    final color = _scoreColor(m.displayScore);
                    return BarChartGroupData(
                      x: i,
                      barRods: [
                        BarChartRodData(
                          toY: score,
                          color: color,
                          width: 22,
                          borderRadius: BorderRadius.circular(12),
                          backDrawRodData: BackgroundBarChartRodData(
                            show: true,
                            toY: 100,
                            color: AppColors.divider,
                          ),
                        ),
                      ],
                    );
                  }),
                ),
              ),
            ),
            Positioned.fill(
              bottom: _labelHeight,
              child: LayoutBuilder(
                builder: (context, constraints) {
                  final barAreaHeight = constraints.maxHeight;
                  return Row(
                    children: List.generate(metrics.length, (i) {
                      final m = metrics[i];
                      final fillRatio =
                          (m.displayScore / 100).clamp(0.0, 1.0);
                      final topOffset =
                          (1 - fillRatio) * (barAreaHeight - _topPadding);
                      return Expanded(
                        child: Stack(
                          alignment: Alignment.topCenter,
                          children: [
                            Padding(
                              padding: EdgeInsets.only(top: topOffset),
                              child: _ScoreCircle(score: m.displayScore),
                            ),
                          ],
                        ),
                      );
                    }),
                  );
                },
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _ScoreCircle extends StatelessWidget {
  const _ScoreCircle({required this.score});
  final int score;

  @override
  Widget build(BuildContext context) {
    final color = _scoreColor(score);
    return Container(
      width: 36,
      height: 36,
      alignment: Alignment.center,
      decoration: BoxDecoration(
        color: AppColors.surface,
        shape: BoxShape.circle,
        border: Border.all(color: color, width: 2),
      ),
      child: Text(
        score == 0 ? '-' : '$score',
        style: TextStyle(
          color: color,
          fontSize: 13,
          fontWeight: FontWeight.w700,
        ),
      ),
    );
  }
}

class _MetricEntryCard extends StatelessWidget {
  const _MetricEntryCard({required this.metric, required this.onTap});

  final ReportMetric metric;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final isFootStrike = metric.type == MetricType.footStrikePattern;
    final footPattern =
        isFootStrike ? FootStrikePattern.fromStatus(metric.status) : null;

    // 라벨 아래 보조 텍스트: 발 착지 패턴이면 한글만, 그 외는 정상/주의
    final statusText = isFootStrike ? footPattern?.koreanLabel : metric.status;
    final statusColor = isFootStrike
        ? footStrikeColor(footPattern)
        : (metric.status == '주의' ? AppColors.scoreLow : AppColors.scoreHigh);

    final scoreColor = _scoreColor(metric.displayScore);

    return Material(
      color: AppColors.analysisCard,
      borderRadius: BorderRadius.circular(16),
      child: InkWell(
        borderRadius: BorderRadius.circular(16),
        onTap: onTap,
        child: Container(
          height: 64,
          padding: const EdgeInsets.symmetric(horizontal: 18),
          child: Row(
            children: [
              Expanded(
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      metric.label,
                      style: AppTypography.cardBody.copyWith(
                        fontSize: 16,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    if (statusText != null)
                      Text(
                        statusText,
                        style: TextStyle(
                          fontSize: 12,
                          color: statusColor,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                  ],
                ),
              ),
              if (isFootStrike && footPattern != null)
                _PatternBadge(pattern: footPattern, size: 36, fontSize: 11)
              else if (metric.score != null)
                Container(
                  width: 36,
                  height: 36,
                  alignment: Alignment.center,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    border: Border.all(color: scoreColor, width: 2),
                  ),
                  child: Text(
                    '${metric.score}',
                    style: TextStyle(
                      color: scoreColor,
                      fontSize: 13,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ),
              const SizedBox(width: 8),
              Icon(
                Icons.chevron_right,
                size: 24,
                color: AppColors.analysisText.withValues(alpha: 0.6),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// 발 착지 패턴 약어(FFS/MFS/RFS) 원형 배지.
/// 점수형 지표의 `_ScoreCircle` / `_LargeScoreCircle` 자리에 대체로 사용.
class _PatternBadge extends StatelessWidget {
  const _PatternBadge({
    required this.pattern,
    required this.size,
    required this.fontSize,
  });

  final FootStrikePattern pattern;
  final double size;
  final double fontSize;

  @override
  Widget build(BuildContext context) {
    final color = footStrikeColor(pattern);
    return Container(
      width: size,
      height: size,
      alignment: Alignment.center,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        border: Border.all(color: color, width: 2),
      ),
      child: Text(
        pattern.abbreviation,
        style: TextStyle(
          color: color,
          fontSize: fontSize,
          fontWeight: FontWeight.w700,
          letterSpacing: -0.3,
        ),
      ),
    );
  }
}

/// 외부에서 PatternBadge를 사용하기 위한 팩토리.
Widget buildPatternBadge({
  required FootStrikePattern pattern,
  required double size,
  required double fontSize,
}) =>
    _PatternBadge(pattern: pattern, size: size, fontSize: fontSize);

class _FootStrikePatternCard extends StatelessWidget {
  const _FootStrikePatternCard({required this.metric});

  final ReportMetric metric;

  @override
  Widget build(BuildContext context) {
    final pattern = FootStrikePattern.fromStatus(metric.status);
    final color = footStrikeColor(pattern);

    return Container(
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(16),
      ),
      padding: const EdgeInsets.fromLTRB(20, 16, 20, 16),
      child: Row(
        children: [
          Container(
            width: 4,
            height: 44,
            decoration: BoxDecoration(
              color: color,
              borderRadius: BorderRadius.circular(2),
            ),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  '발 착지 패턴',
                  style: AppTypography.bodyMuted.copyWith(fontSize: 12),
                ),
                const SizedBox(height: 4),
                Text(
                  pattern?.displayLabel ?? (metric.status ?? '측정 안 됨'),
                  style: TextStyle(
                    color: color,
                    fontSize: 18,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

/// 발 착지 패턴 → 색상.
/// 의학적 우열이 아닌 시각적 구분 목적.
Color footStrikeColor(FootStrikePattern? pattern) => switch (pattern) {
      FootStrikePattern.ffs => AppColors.scoreHigh,
      FootStrikePattern.mfs => AppColors.feedbackInfo,
      FootStrikePattern.rfs => AppColors.feedbackWarning,
      null => AppColors.textMuted,
    };

Color _scoreColor(int score) {
  if (score >= 75) return AppColors.scoreHigh;
  if (score >= 60) return AppColors.scoreMid;
  return AppColors.scoreLow;
}
