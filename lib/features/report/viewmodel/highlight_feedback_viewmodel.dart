import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../model/highlight_feedback.dart';
import '../model/report_api_service.dart';

final highlightFeedbackProvider =
    FutureProvider.autoDispose.family<HighlightFeedback?, String>((ref, runId) async {
  final api = ReportApiService();

  final highlights = await api.getHighlightsByRun(runId);

  final run = await api.getRun(runId);
  final durationSec = (run?['duration'] as num?)?.toInt() ?? 0;

  String? videoUrl;
  final videoS3Key = run?['videoS3Key'] as String?;
  if (videoS3Key != null && videoS3Key.isNotEmpty) {
    videoUrl = await api.getPresignedUrl(videoS3Key);
  }

  // highlight row가 0건이라도 영상은 있을 수 있음 (백엔드가 detection 0건으로
  // 끝낸 케이스). 둘 다 없을 때만 진짜 빈 상태.
  if (highlights.isEmpty && videoUrl == null) return null;

  return HighlightFeedback.fromHighlights(
    sessionId: runId,
    durationSec: durationSec,
    highlights: highlights,
    videoUrl: videoUrl,
  );
});
