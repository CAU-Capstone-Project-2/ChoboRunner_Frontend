/// 피드백 메시지의 카테고리
enum FeedbackCategory {
  systemInfo,    // 시스템 안내 (예: 분석 시작/종료)
  postureWarning, // 자세 경고 (개선 필요)
  postureInfo,    // 자세 정보 (현재 상태 안내)
  unknown,
}

/// analysis_progress / analysis_result의 feedback_messages 배열 요소
class FeedbackItem {
  final FeedbackCategory category;
  final String? metric;          // 예: "trunk_lean", "initial_knee_flexion". system_info는 null
  final String? ttsText;         // TTS 음성용 짧은 문구. tts_enabled가 false면 null 가능
  final String displayText;      // 화면 표시용 자세한 문구
  final int priority;            // 1(최우선), 2, 3
  final bool ttsEnabled;         // Android에서 TTS 합성 여부
  final bool confidencePrefix;   // true면 "측정 신뢰도가 낮아 ..." prefix 추가

  const FeedbackItem({
    required this.category,
    this.metric,
    this.ttsText,
    required this.displayText,
    required this.priority,
    required this.ttsEnabled,
    required this.confidencePrefix,
  });

  factory FeedbackItem.fromJson(Map<String, dynamic> json) {
    return FeedbackItem(
      category: _parseCategory(json['category'] as String?),
      metric: json['metric'] as String?,
      ttsText: json['tts_text'] as String?,
      displayText: json['display_text'] as String? ?? '',
      priority: (json['priority'] as num?)?.toInt() ?? 3,
      ttsEnabled: json['tts_enabled'] as bool? ?? false,
      confidencePrefix: json['confidence_prefix'] as bool? ?? false,
    );
  }

  static FeedbackCategory _parseCategory(String? raw) {
    switch (raw) {
      case 'system_info':
        return FeedbackCategory.systemInfo;
      case 'posture_warning':
        return FeedbackCategory.postureWarning;
      case 'posture_info':
        return FeedbackCategory.postureInfo;
      default:
        return FeedbackCategory.unknown;
    }
  }

  /// 화면에 표시할 최종 문구
  /// confidence_prefix가 true면 안내 prefix를 자동으로 붙임
  String get displayTextWithPrefix {
    if (confidencePrefix) {
      return '측정 신뢰도가 낮아 참고용으로만 확인해주세요. $displayText';
    }
    return displayText;
  }
}

/// JSON 배열을 FeedbackItem 리스트로 변환 (방어적)
List<FeedbackItem> parseFeedbackItems(dynamic raw) {
  if (raw is! List) return const [];
  final result = <FeedbackItem>[];
  for (final item in raw) {
    if (item is Map<String, dynamic>) {
      try {
        result.add(FeedbackItem.fromJson(item));
      } catch (_) {
        // 파싱 실패한 항목은 건너뜀
      }
    }
  }
  return result;
}
