import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../model/highlight_feedback.dart';

/// 세션 ID로 하이라이트 피드백을 조회하는 family Provider.
///
/// 현재는 mock 데이터 맵에서 조회. 추후 백엔드 연동 시
/// FutureProvider.family로 교체하면 화면 쪽 변경 없이 비동기화 가능하도록 의도.
final highlightFeedbackProvider =
    Provider.family<HighlightFeedback?, String>((ref, sessionId) {
  return mockHighlightFeedbacks[sessionId];
});
