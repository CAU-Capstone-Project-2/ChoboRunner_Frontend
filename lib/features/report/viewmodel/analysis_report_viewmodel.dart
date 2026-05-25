import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../model/analysis_report.dart';
import '../model/report_api_service.dart';
import '../model/report_metric.dart';

final analysisReportProvider =
    FutureProvider.family<AnalysisReport?, String>((ref, runId) async {
  final api = ReportApiService();

  final reports = await api.getReportsByRun(runId);
  if (reports.isEmpty) return null;

  final report = reports.first;
  final reportId = report['id'].toString();
  final totalFeedback = report['totalFeedback'] as String?;

  final details = await api.getDetailedReports(reportId);

  final metrics = details
      .map((json) {
        final type = MetricType.fromBackendType(json['type'] as String?);
        if (type == null) return null;
        return ReportMetric.fromJson(json);
      })
      .whereType<ReportMetric>()
      .toList();

  final scores = metrics.map((m) => m.score).whereType<int>();
  final overallScore = scores.isEmpty
      ? 0
      : (scores.reduce((a, b) => a + b) / scores.length).round();

  return AnalysisReport(
    sessionId: runId,
    overallScore: overallScore,
    totalFeedback: totalFeedback,
    metrics: metrics,
  );
});
