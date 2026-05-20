import 'package:flutter/foundation.dart';

/// 한 번의 러닝 측정 세션 결과.
///
/// 분석 리포트 / 하이라이트 피드백 두 화면이 동일한 세션을 공유.
@immutable
class ReportSession {
  final String id;
  final DateTime date;
  final int score;
  final bool hasHighlight;

  const ReportSession({
    required this.id,
    required this.date,
    required this.score,
    this.hasHighlight = true,
  });
}

/// 리포트 선택 화면용 mock 데이터.
final List<ReportSession> mockReportSessions = [
  ReportSession(
    id: 'session-2026-03-01-a',
    date: DateTime(2026, 3, 1),
    score: 70,
  ),
  ReportSession(
    id: 'session-2026-03-01-b',
    date: DateTime(2026, 3, 1),
    score: 70,
  ),
  ReportSession(
    id: 'session-2026-03-01-c',
    date: DateTime(2026, 3, 1),
    score: 70,
  ),
];
