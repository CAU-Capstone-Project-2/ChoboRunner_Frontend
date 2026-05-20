import 'package:flutter/foundation.dart';

import 'report_metric.dart';

/// 한 세션에 대한 분석 리포트.
///
/// `ReportSession`이 선택 화면(목록)을 위한 요약이라면,
/// `AnalysisReport`는 "분석 리포트" 화면에서 표시할 상세 데이터.
@immutable
class AnalysisReport {
  final String sessionId;
  final int overallScore;
  final List<ReportMetric> metrics;

  const AnalysisReport({
    required this.sessionId,
    required this.overallScore,
    required this.metrics,
  });
}

// ─────────── mock 데이터 ───────────

/// 세션 ID → 분석 리포트 mock.
///
/// 추후 백엔드 연동 시 FutureProvider.family로 교체.
final Map<String, AnalysisReport> mockAnalysisReports = {
  'session-2026-03-01-a': AnalysisReport(
    sessionId: 'session-2026-03-01-a',
    overallScore: 70,
    metrics: [
      _mockMetric(MetricType.torsoAngle, 70),
      _mockMetric(MetricType.kneeAngleOnContact, 90),
      _mockMetric(MetricType.footStrikePattern, 50),
    ],
  ),
  'session-2026-03-01-b': AnalysisReport(
    sessionId: 'session-2026-03-01-b',
    overallScore: 70,
    metrics: [
      _mockMetric(MetricType.torsoAngle, 65),
      _mockMetric(MetricType.kneeAngleOnContact, 80),
      _mockMetric(MetricType.footStrikePattern, 65),
    ],
  ),
  'session-2026-03-01-c': AnalysisReport(
    sessionId: 'session-2026-03-01-c',
    overallScore: 70,
    metrics: [
      _mockMetric(MetricType.torsoAngle, 75),
      _mockMetric(MetricType.kneeAngleOnContact, 70),
      _mockMetric(MetricType.footStrikePattern, 65),
    ],
  ),
};

/// 지표 유형별 mock 세부 정보(텍스트/수치)를 입혀 ReportMetric 생성.
ReportMetric _mockMetric(MetricType type, int score) {
  return ReportMetric(
    type: type,
    score: score,
    summary: _summaryFor(type),
    problem: _problemFor(type),
    improvement: _improvementFor(type),
    referenceValue: _referenceFor(type),
    measuredValue: _measuredFor(type),
    unit: _unitFor(type),
  );
}

String _summaryFor(MetricType t) => switch (t) {
      MetricType.torsoAngle => '달릴 때 상체가 다소 앞으로 기울어 있어요',
      MetricType.kneeAngleOnContact => '접지 순간 무릎이 적절히 굽혀져 있어요',
      MetricType.footStrikePattern => '뒤꿈치 착지 비율이 다소 높습니다',
    };

String _problemFor(MetricType t) => switch (t) {
      MetricType.torsoAngle => '무게 중심이 발끝 쪽으로 쏠려 부상 위험이 커져요',
      MetricType.kneeAngleOnContact => '특이사항이 발견되지 않았습니다',
      MetricType.footStrikePattern => '무릎과 허리에 충격이 누적될 수 있어요',
    };

String _improvementFor(MetricType t) => switch (t) {
      MetricType.torsoAngle => '코어에 힘을 주고 상체를 살짝 세워 달려보세요',
      MetricType.kneeAngleOnContact => '현재 자세를 유지하세요',
      MetricType.footStrikePattern => '중족부(미드풋) 위주로 착지하도록 의식해보세요',
    };

double _referenceFor(MetricType t) => switch (t) {
      MetricType.torsoAngle => 5.0,
      MetricType.kneeAngleOnContact => 25.0,
      MetricType.footStrikePattern => 60.0,
    };

double _measuredFor(MetricType t) => switch (t) {
      MetricType.torsoAngle => 12.4,
      MetricType.kneeAngleOnContact => 27.0,
      MetricType.footStrikePattern => 78.0,
    };

String _unitFor(MetricType t) => switch (t) {
      MetricType.torsoAngle => '°',
      MetricType.kneeAngleOnContact => '°',
      MetricType.footStrikePattern => '%',
    };
