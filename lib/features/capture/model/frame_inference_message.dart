/// frame_inference 메시지 (디버그/모니터링용)
///
/// 매 프레임 추론 직후 즉시 응답되는 단발성 메시지.
/// 단일 frame 추론 결과는 노이즈가 크므로 사용자 화면에 직접 표시하지 않음.
class FrameInferenceMessage {
  final int frameIndex;
  final double timestampSec;
  final FrameInferenceResult result;

  const FrameInferenceMessage({
    required this.frameIndex,
    required this.timestampSec,
    required this.result,
  });

  factory FrameInferenceMessage.fromJson(Map<String, dynamic> json) {
    return FrameInferenceMessage(
      frameIndex: (json['frame_index'] as num?)?.toInt() ?? 0,
      timestampSec: (json['timestamp_sec'] as num?)?.toDouble() ?? 0.0,
      result: json['result'] is Map<String, dynamic>
          ? FrameInferenceResult.fromJson(json['result'] as Map<String, dynamic>)
          : const FrameInferenceResult(
              poseDetected: false,
              frameQualityFlags: [],
            ),
    );
  }
}

/// frame_inference의 result 객체
class FrameInferenceResult {
  final bool poseDetected;
  final List<String> frameQualityFlags;

  const FrameInferenceResult({
    required this.poseDetected,
    required this.frameQualityFlags,
  });

  factory FrameInferenceResult.fromJson(Map<String, dynamic> json) {
    final flagsRaw = json['frame_quality_flags'];
    final flags = <String>[];
    if (flagsRaw is List) {
      for (final f in flagsRaw) {
        if (f is String) flags.add(f);
      }
    }

    return FrameInferenceResult(
      poseDetected: json['pose_detected'] as bool? ?? false,
      frameQualityFlags: flags,
    );
  }

  /// 품질 검사 통과 여부 (플래그가 하나도 없으면 true)
  bool get isQualityOk => frameQualityFlags.isEmpty;

  /// 특정 품질 플래그 보유 여부 확인
  bool hasFlag(String flag) => frameQualityFlags.contains(flag);
}
