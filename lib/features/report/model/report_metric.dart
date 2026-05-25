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

  static MetricType? fromBackendType(String? type) => switch (type) {
        'trunk_lean' => MetricType.torsoAngle,
        'initial_knee_flexion' => MetricType.kneeAngleOnContact,
        'foot_strike_pattern' => MetricType.footStrikePattern,
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
