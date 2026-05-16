import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../model/report_session.dart';

/// 리포트 목록 Provider.
///
/// 현재는 mock 데이터를 반환. 추후 백엔드 연동 시 FutureProvider로 교체.
final reportListProvider = Provider<List<ReportSession>>((ref) {
  return mockReportSessions;
});
