// LEGACY_REMOVE_AFTER_BACKEND_MIGRATION
// ────────────────────────────────────────────────────────────
// 이 파일은 백엔드가 신명세(2-3-7, type: frame_inference/analysis_progress/
// analysis_result/error)로 마이그레이션하기 전까지의 임시 호환 어댑터입니다.
//
// 백엔드가 신명세 적용 완료 시 다음 작업을 수행:
// 1. 이 파일 (legacy_inference_adapter.dart) 삭제
// 2. server_message.dart에서 "inference_result" 분기 제거 (관련 import 제거 포함)
// 3. grep "LEGACY_REMOVE_AFTER_BACKEND_MIGRATION" 으로 잔여 마커 확인
// ────────────────────────────────────────────────────────────

import 'frame_inference_message.dart';
import 'server_message.dart';

/// LEGACY_REMOVE_AFTER_BACKEND_MIGRATION
///
/// 옛 mock 명세의 inference_result(JSON Map)를 신명세 메시지로 변환.
///
/// 옛 명세: {"type":"inference_result", "status":"ok"|"error", ...}
/// 신명세: {"type":"frame_inference"|"error", ...}
///
/// 매핑 규칙:
/// - status: "ok"  → FrameInferenceServerMessage (디버그 카운트만 증가, 화면 표시 X)
/// - status: "error" → ErrorServerMessage
/// - 그 외 → null (호출 측에서 UnknownServerMessage 처리)
ServerMessage? adaptLegacyInferenceResult(Map<String, dynamic> json) {
  final status = json['status'] as String?;

  if (status == 'ok') {
    // 옛 형식 → 신명세 frame_inference 형식으로 매핑
    // 옛 result에는 pose_detected, width, height, metadata만 있고
    // 신명세 frame_inference의 frame_index, timestamp_sec, frame_quality_flags는 없음.
    // 누락된 필드는 기본값(0, 빈 배열)으로 채움.
    final result = json['result'];
    final poseDetected = result is Map<String, dynamic>
        ? (result['pose_detected'] as bool? ?? false)
        : false;

    final mappedJson = <String, dynamic>{
      'type': 'frame_inference',
      'frame_index': 0,
      'timestamp_sec': 0.0,
      'result': {
        'pose_detected': poseDetected,
        'frame_quality_flags': <String>[],
      },
    };

    return FrameInferenceServerMessage(
      FrameInferenceMessage.fromJson(mappedJson),
    );
  }

  if (status == 'error') {
    // 옛 에러 응답 → 신명세 error 메시지로 매핑
    return ErrorServerMessage(
      frameIndex: (json['frame_id'] as num?)?.toInt(),
      errorCode: json['error'] as String? ?? 'unknown',
      errorDetail: null,
    );
  }

  // 알 수 없는 status → null 반환 (호출 측이 UnknownServerMessage로 처리)
  return null;
}
