import 'feedback_item.dart';

/// analysis_progress 메시지의 분석 단계
enum AnalysisStage {
  /// 첫 IC 검출 전 (frame 누적 중) - "분석 준비 중..."
  warmingUp,

  /// 첫 IC 검출 완료, 유효 stride 3개 미만 - "분석 중..."
  collectingStrides,

  /// 유효 stride 3개 누적 후, 매 stride마다 결과 갱신 - "분석 중... (결과 갱신)"
  analyzing,

  /// 명세에 없는 값
  unknown,
}

/// analysis_progress 메시지
///
/// 분석 단계 전환 시 또는 analyzing 단계에서 stride 갱신 시 응답됨.
/// 측정 화면의 "분석 중" 상태 표시 + 실시간 피드백 전달에 사용.
class AnalysisProgressMessage {
  final AnalysisStage stage;
  final int validStrideCount;
  final double elapsedSec;
  final String? message;
  final List<FeedbackItem> feedbackMessages;

  const AnalysisProgressMessage({
    required this.stage,
    required this.validStrideCount,
    required this.elapsedSec,
    this.message,
    this.feedbackMessages = const [],
  });

  factory AnalysisProgressMessage.fromJson(Map<String, dynamic> json) {
    return AnalysisProgressMessage(
      stage: _parseStage(json['stage'] as String?),
      validStrideCount: (json['valid_stride_count'] as num?)?.toInt() ?? 0,
      elapsedSec: (json['elapsed_sec'] as num?)?.toDouble() ?? 0.0,
      message: json['message'] as String?,
      feedbackMessages: parseFeedbackItems(json['feedback_messages']),
    );
  }

  static AnalysisStage _parseStage(String? raw) {
    switch (raw) {
      case 'warming_up':
        return AnalysisStage.warmingUp;
      case 'collecting_strides':
        return AnalysisStage.collectingStrides;
      case 'analyzing':
        return AnalysisStage.analyzing;
      default:
        return AnalysisStage.unknown;
    }
  }

  /// 사용자 화면에 표시할 단계별 기본 문구
  String get stageLabel {
    switch (stage) {
      case AnalysisStage.warmingUp:
        return '분석 준비 중...';
      case AnalysisStage.collectingStrides:
        return '분석 중...';
      case AnalysisStage.analyzing:
        return '분석 중... (결과 갱신)';
      case AnalysisStage.unknown:
        return '진행 중';
    }
  }

  /// 실시간 피드백 메시지가 있는지 여부
  bool get hasFeedback => feedbackMessages.isNotEmpty;

  /// TTS로 출력해야 할 메시지 (한 응답에 최대 1개 보장됨)
  FeedbackItem? get ttsItem {
    for (final item in feedbackMessages) {
      if (item.ttsEnabled) return item;
    }
    return null;
  }

  /// 화면에 표시할 메시지들 (priority 오름차순 정렬, 1이 가장 위)
  List<FeedbackItem> get displayItems {
    final sorted = List<FeedbackItem>.from(feedbackMessages);
    sorted.sort((a, b) => a.priority.compareTo(b.priority));
    return sorted;
  }

  /// 화면에 표시할 단일 피드백 메시지
  /// priority가 가장 높은(숫자가 가장 작은) 메시지 1개 반환.
  /// 비어있으면 null.
  FeedbackItem? get topPriorityItem {
    if (feedbackMessages.isEmpty) return null;
    FeedbackItem? best;
    for (final item in feedbackMessages) {
      if (best == null || item.priority < best.priority) {
        best = item;
      }
    }
    return best;
  }
}
