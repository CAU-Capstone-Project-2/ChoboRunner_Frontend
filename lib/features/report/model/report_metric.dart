import 'package:flutter/foundation.dart';

enum MetricType {
  torsoAngle,
  kneeAngleOnContact,
  footStrikePattern;

  String get label => switch (this) {
        MetricType.torsoAngle => '몸통 각도',
        MetricType.kneeAngleOnContact => '접지시 무릎 각도',
        MetricType.footStrikePattern => '발 착지 패턴',
      };

  /// 백엔드 key → MetricType.
  /// 백엔드가 3가지 표기를 혼용하므로 모두 수용:
  /// - DetailedReport.type: `trunk_lean` / `initial_knee_flexion` / `foot_strike_pattern`
  /// - feedback_messages[].metric: `trunk_lean` / `knee_flexion` / `foot_strike`
  /// - metric_details 객체 키: `*_deg` 접미사
  static MetricType? fromBackendType(String? type) => switch (type) {
        'trunk_lean' || 'trunk_lean_deg' => MetricType.torsoAngle,
        'initial_knee_flexion' ||
        'initial_knee_flexion_deg' ||
        'knee_flexion' =>
          MetricType.kneeAngleOnContact,
        'foot_strike_pattern' ||
        'foot_strike_angle_deg' ||
        'foot_strike' =>
          MetricType.footStrikePattern,
        _ => null,
      };

  /// 점수형 지표인지 (foot strike pattern은 점수가 아닌 분류 결과)
  bool get hasScore => this != MetricType.footStrikePattern;
}

/// 발 착지 패턴 (foot strike pattern) 분류.
/// 백엔드 `DetailedReport.status` 값으로 들어옴.
enum FootStrikePattern {
  rfs, // Rearfoot Strike
  mfs, // Midfoot Strike
  ffs; // Forefoot Strike

  String get koreanLabel => switch (this) {
        FootStrikePattern.rfs => '뒤꿈치 착지',
        FootStrikePattern.mfs => '중족부 착지',
        FootStrikePattern.ffs => '앞꿈치 착지',
      };

  String get abbreviation => switch (this) {
        FootStrikePattern.rfs => 'RFS',
        FootStrikePattern.mfs => 'MFS',
        FootStrikePattern.ffs => 'FFS',
      };

  /// "앞꿈치 착지 (FFS)" 형식
  String get displayLabel => '$koreanLabel ($abbreviation)';

  static FootStrikePattern? fromStatus(String? status) =>
      switch (status?.toUpperCase()) {
        'RFS' => FootStrikePattern.rfs,
        'MFS' => FootStrikePattern.mfs,
        'FFS' => FootStrikePattern.ffs,
        _ => null,
      };
}

@immutable
class ReportMetric {
  final MetricType type;
  final int? score;
  final String? status;
  final String? summary;
  final String? problem;
  final String? improvement;
  final double? referenceValue;
  final double? measuredValue;
  final String? unit;

  const ReportMetric({
    required this.type,
    this.score,
    this.status,
    this.summary,
    this.problem,
    this.improvement,
    this.referenceValue,
    this.measuredValue,
    this.unit,
  });

  factory ReportMetric.fromJson(Map<String, dynamic> json) {
    final type = MetricType.fromBackendType(json['type'] as String?);
    return ReportMetric(
      type: type ?? MetricType.torsoAngle,
      score: (json['score'] as num?)?.toInt(),
      status: json['status'] as String?,
      summary: json['summary'] as String?,
      problem: json['problem'] as String?,
      improvement: json['improved'] as String?,
      referenceValue: double.tryParse(json['stdVal']?.toString() ?? ''),
      measuredValue: double.tryParse(json['measured']?.toString() ?? ''),
      unit: type == MetricType.footStrikePattern ? '' : '°',
    );
  }

  String get label => type.label;

  int get displayScore => score ?? 0;
}
