import 'package:flutter/foundation.dart';

/// 분석 리포트의 항목 종류.
///
/// 3가지 고정 항목으로 구성된다 (몸통 각도 / 접지시 무릎 각도 / 발 착지 패턴).
enum MetricType {
  torsoAngle,
  kneeAngleOnContact,
  footStrikePattern;

  String get label => switch (this) {
        MetricType.torsoAngle => '몸통 각도',
        MetricType.kneeAngleOnContact => '접지시 무릎 각도',
        MetricType.footStrikePattern => '발 착지 패턴',
      };
}

/// 분석 리포트 안의 단일 지표(항목)와 점수.
///
/// 세부 지표 화면에서 사용하는 텍스트/수치 필드는 nullable로,
/// mock 데이터에서는 채워서 사용한다.
@immutable
class ReportMetric {
  final MetricType type;
  final int score;

  /// 부위별 피드백 요약 한 줄.
  final String? summary;

  /// 문제점 한 줄.
  final String? problem;

  /// 개선 방법 한 줄.
  final String? improvement;

  /// 기준 값 (이상적인 측정값).
  final double? referenceValue;

  /// 사용자 측정 값.
  final double? measuredValue;

  /// 측정 단위 ("°", "%" 등).
  final String? unit;

  const ReportMetric({
    required this.type,
    required this.score,
    this.summary,
    this.problem,
    this.improvement,
    this.referenceValue,
    this.measuredValue,
    this.unit,
  });

  String get label => type.label;
}
