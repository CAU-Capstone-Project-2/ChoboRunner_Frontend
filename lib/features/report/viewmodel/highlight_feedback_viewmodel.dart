import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../model/highlight_feedback.dart';
import '../model/report_api_service.dart';

final highlightFeedbackProvider =
    FutureProvider.family<HighlightFeedback?, String>((ref, runId) async {
  final api = ReportApiService();

  final highlights = await api.getHighlightsByRun(runId);
  if (highlights.isEmpty) return null;

  final run = await api.getRun(runId);
  final durationSec = (run?['duration'] as num?)?.toInt() ?? 0;

  return HighlightFeedback.fromHighlights(
    sessionId: runId,
    durationSec: durationSec,
    highlights: highlights,
  );
});
