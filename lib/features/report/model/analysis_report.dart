import 'package:flutter/foundation.dart';

import 'report_metric.dart';

@immutable
class AnalysisReport {
  final String sessionId;
  final int overallScore;
  final String? totalFeedback;
  final List<ReportMetric> metrics;

  const AnalysisReport({
    required this.sessionId,
    required this.overallScore,
    this.totalFeedback,
    required this.metrics,
  });
}
