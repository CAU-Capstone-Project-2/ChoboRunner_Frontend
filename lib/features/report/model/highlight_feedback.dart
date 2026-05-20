import 'package:flutter/foundation.dart';

/// 한 세션의 하이라이트 피드백.
///
/// 영상에서 코칭이 의미 있는 구간(`segments`)과
/// 사용자 러닝 전반에 대한 피드백 문구(`message`)를 함께 담는다.
@immutable
class HighlightFeedback {
  final String sessionId;

  /// 전체 영상 길이. 타임라인 바의 분모로 사용.
  final Duration totalDuration;

  /// 하이라이트된 구간들. 타임라인 위에 라임색 마커로 표시.
  final List<HighlightSegment> segments;

  /// 사용자 러닝 피드백 문구.
  final String message;

  const HighlightFeedback({
    required this.sessionId,
    required this.totalDuration,
    required this.segments,
    required this.message,
  });
}

/// 영상 내 하이라이트 한 구간.
@immutable
class HighlightSegment {
  final Duration start;
  final Duration end;

  const HighlightSegment({required this.start, required this.end});

  Duration get duration => end - start;
}

// ─────────── mock 데이터 ───────────

/// 세션 ID → 하이라이트 피드백 mock.
///
/// 추후 백엔드 연동 시 FutureProvider.family로 교체.
final Map<String, HighlightFeedback> mockHighlightFeedbacks = {
  'session-2026-03-01-a': HighlightFeedback(
    sessionId: 'session-2026-03-01-a',
    totalDuration: const Duration(minutes: 12),
    segments: const [
      HighlightSegment(
        start: Duration(minutes: 2, seconds: 30),
        end: Duration(minutes: 2, seconds: 48),
      ),
      HighlightSegment(
        start: Duration(minutes: 5, seconds: 0),
        end: Duration(minutes: 5, seconds: 14),
      ),
      HighlightSegment(
        start: Duration(minutes: 9, seconds: 20),
        end: Duration(minutes: 9, seconds: 35),
      ),
    ],
    message: '5분 구간에서 상체가 앞으로 기울며 보폭이 짧아졌어요. 코어에 힘을 주고 시선을 멀리 두며 달려보세요.',
  ),
  'session-2026-03-01-b': HighlightFeedback(
    sessionId: 'session-2026-03-01-b',
    totalDuration: const Duration(minutes: 10),
    segments: const [
      HighlightSegment(
        start: Duration(minutes: 1, seconds: 10),
        end: Duration(minutes: 1, seconds: 22),
      ),
      HighlightSegment(
        start: Duration(minutes: 6, seconds: 5),
        end: Duration(minutes: 6, seconds: 20),
      ),
    ],
    message: '뒤꿈치 착지가 반복되는 구간이 있어요. 중족부로 가볍게 착지하는 감각을 의식해보세요.',
  ),
  'session-2026-03-01-c': HighlightFeedback(
    sessionId: 'session-2026-03-01-c',
    totalDuration: const Duration(minutes: 15),
    segments: const [
      HighlightSegment(
        start: Duration(minutes: 3, seconds: 40),
        end: Duration(minutes: 3, seconds: 58),
      ),
      HighlightSegment(
        start: Duration(minutes: 8, seconds: 10),
        end: Duration(minutes: 8, seconds: 25),
      ),
      HighlightSegment(
        start: Duration(minutes: 12, seconds: 50),
        end: Duration(minutes: 13, seconds: 6),
      ),
    ],
    message: '후반부로 갈수록 무릎 각도가 펴지는 경향이 있어요. 접지 시 무릎을 조금 더 굽혀 충격을 흡수해보세요.',
  ),
};
