import 'package:flutter/foundation.dart';

@immutable
class HighlightFeedback {
  final String sessionId;
  final Duration totalDuration;

  /// 백엔드 run.duration의 raw 값. 0이면 미저장 상태(null 또는 0).
  /// 화면이 영상 길이로 백필 PUT을 할지 결정하는 데 사용.
  final int backendDurationSec;

  final List<HighlightSegment> segments;
  final String message;
  final String? videoUrl;

  const HighlightFeedback({
    required this.sessionId,
    required this.totalDuration,
    required this.backendDurationSec,
    required this.segments,
    required this.message,
    this.videoUrl,
  });

  factory HighlightFeedback.fromHighlights({
    required String sessionId,
    required int durationSec,
    required List<Map<String, dynamic>> highlights,
    String? videoUrl,
  }) {
    final segments = highlights.map((h) {
      return HighlightSegment(
        start: _parseTime(h['startTime'] as String? ?? '00:00:00'),
        end: _parseTime(h['endTime'] as String? ?? '00:00:00'),
        issueType: h['issueType'] as String?,
        message: h['message'] as String?,
      );
    }).toList();

    final messages = highlights
        .map((h) => h['message'] as String?)
        .where((m) => m != null && m.isNotEmpty)
        .toSet()
        .join('\n');

    return HighlightFeedback(
      sessionId: sessionId,
      totalDuration: Duration(seconds: durationSec > 0 ? durationSec : 60),
      backendDurationSec: durationSec,
      segments: segments,
      message: messages.isEmpty ? '하이라이트 피드백이 없습니다.' : messages,
      videoUrl: videoUrl,
    );
  }

  static Duration _parseTime(String time) {
    final parts = time.split(':');
    if (parts.length != 3) return Duration.zero;
    return Duration(
      hours: int.tryParse(parts[0]) ?? 0,
      minutes: int.tryParse(parts[1]) ?? 0,
      seconds: int.tryParse(parts[2]) ?? 0,
    );
  }
}

@immutable
class HighlightSegment {
  final Duration start;
  final Duration end;
  final String? issueType;
  final String? message;

  const HighlightSegment({
    required this.start,
    required this.end,
    this.issueType,
    this.message,
  });

  Duration get duration => end - start;
}
