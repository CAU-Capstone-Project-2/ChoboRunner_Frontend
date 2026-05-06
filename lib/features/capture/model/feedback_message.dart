import 'dart:convert';

/// 서버 응답 status 구분
enum InferenceStatus { ok, error, unknown }

/// 백엔드에서 받는 inference_result 메시지 전체
class FeedbackMessage {
  final String type;
  final InferenceStatus status;
  final String? frameId;
  final InferenceResult? result;
  final String? error;

  const FeedbackMessage({
    required this.type,
    required this.status,
    this.frameId,
    this.result,
    this.error,
  });

  /// JSON 문자열에서 직접 파싱 (실패 시 null 반환)
  static FeedbackMessage? tryParse(String raw) {
    try {
      final json = jsonDecode(raw) as Map<String, dynamic>;
      return FeedbackMessage.fromJson(json);
    } catch (_) {
      return null;
    }
  }

  factory FeedbackMessage.fromJson(Map<String, dynamic> json) {
    final statusStr = json['status'] as String?;
    final status = switch (statusStr) {
      'ok' => InferenceStatus.ok,
      'error' => InferenceStatus.error,
      _ => InferenceStatus.unknown,
    };

    return FeedbackMessage(
      type: json['type'] as String? ?? 'unknown',
      status: status,
      frameId: json['frame_id']?.toString(),
      result: json['result'] is Map<String, dynamic>
          ? InferenceResult.fromJson(json['result'] as Map<String, dynamic>)
          : null,
      error: json['error'] as String?,
    );
  }

  bool get isOk => status == InferenceStatus.ok && result != null;
  bool get isError => status == InferenceStatus.error;
}

/// 추론 결과 본문 (status: ok 일 때만 존재)
class InferenceResult {
  final bool poseDetected;
  final int? width;
  final int? height;
  final String? stanceSide; // "left" | "right"
  final int? visibleLandmarks;
  final PoseMetrics metrics;
  final Map<String, dynamic> metadata;

  const InferenceResult({
    required this.poseDetected,
    this.width,
    this.height,
    this.stanceSide,
    this.visibleLandmarks,
    required this.metrics,
    required this.metadata,
  });

  factory InferenceResult.fromJson(Map<String, dynamic> json) {
    return InferenceResult(
      poseDetected: json['pose_detected'] as bool? ?? false,
      width: (json['width'] as num?)?.toInt(),
      height: (json['height'] as num?)?.toInt(),
      stanceSide: json['stance_side'] as String?,
      visibleLandmarks: (json['visible_landmarks'] as num?)?.toInt(),
      metrics: json['metrics'] is Map<String, dynamic>
          ? PoseMetrics.fromJson(json['metrics'] as Map<String, dynamic>)
          : const PoseMetrics(),
      metadata: json['metadata'] is Map<String, dynamic>
          ? Map<String, dynamic>.from(json['metadata'] as Map)
          : const {},
    );
  }
}

/// 자세 분석 핵심 지표
class PoseMetrics {
  /// 상체 기울기 (도)
  final double? trunkLeanDeg;

  /// 왼쪽 무릎 초기 굴곡각 (도)
  final double? initialKneeFlexionLeftDeg;

  /// 오른쪽 무릎 초기 굴곡각 (도)
  final double? initialKneeFlexionRightDeg;

  const PoseMetrics({
    this.trunkLeanDeg,
    this.initialKneeFlexionLeftDeg,
    this.initialKneeFlexionRightDeg,
  });

  factory PoseMetrics.fromJson(Map<String, dynamic> json) {
    return PoseMetrics(
      trunkLeanDeg: (json['trunk_lean_deg'] as num?)?.toDouble(),
      initialKneeFlexionLeftDeg:
          (json['initial_knee_flexion_left_deg'] as num?)?.toDouble(),
      initialKneeFlexionRightDeg:
          (json['initial_knee_flexion_right_deg'] as num?)?.toDouble(),
    );
  }
}
