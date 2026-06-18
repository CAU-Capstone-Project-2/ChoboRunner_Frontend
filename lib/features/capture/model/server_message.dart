import 'dart:convert';

import 'analysis_progress_message.dart';
import 'analysis_result_message.dart';
import 'frame_inference_message.dart';
// LEGACY_REMOVE_AFTER_BACKEND_MIGRATION
import 'legacy_inference_adapter.dart';

/// 서버가 보내는 모든 메시지의 부모 sealed class
///
/// 4종 자식:
/// - FrameInferenceServerMessage
/// - AnalysisProgressServerMessage
/// - AnalysisResultServerMessage
/// - ErrorServerMessage
///
/// + 명세에 없는 값에 대비한 UnknownServerMessage
sealed class ServerMessage {
  const ServerMessage();

  /// JSON 문자열에서 직접 파싱
  /// 실패 시 null 반환 (앱이 안 죽음)
  static ServerMessage? tryParse(String raw) {
    try {
      final json = jsonDecode(raw);
      if (json is! Map<String, dynamic>) return null;
      return _fromJson(json);
    } catch (_) {
      return null;
    }
  }

  static ServerMessage _fromJson(Map<String, dynamic> json) {
    final type = json['type'] as String?;
    switch (type) {
      case 'frame_inference':
        return FrameInferenceServerMessage(
          FrameInferenceMessage.fromJson(json),
        );
      case 'analysis_progress':
        return AnalysisProgressServerMessage(
          AnalysisProgressMessage.fromJson(json),
        );
      case 'analysis_result':
        return AnalysisResultServerMessage(
          AnalysisResultMessage.fromJson(json),
        );
      case 'error':
        return ErrorServerMessage.fromJson(json);
      // LEGACY_REMOVE_AFTER_BACKEND_MIGRATION
      // 백엔드가 신명세(2-3-7)로 마이그레이션 완료 시 이 case 통째로 제거.
      case 'inference_result':
        final adapted = adaptLegacyInferenceResult(json);
        return adapted ?? UnknownServerMessage(rawType: type, raw: json);
      default:
        return UnknownServerMessage(rawType: type, raw: json);
    }
  }
}

/// frame_inference 메시지 (디버그용)
final class FrameInferenceServerMessage extends ServerMessage {
  final FrameInferenceMessage data;
  const FrameInferenceServerMessage(this.data);
}

/// analysis_progress 메시지 (진행 상태 + 실시간 피드백)
final class AnalysisProgressServerMessage extends ServerMessage {
  final AnalysisProgressMessage data;
  const AnalysisProgressServerMessage(this.data);
}

/// analysis_result 메시지 (최종 누적 결과)
final class AnalysisResultServerMessage extends ServerMessage {
  final AnalysisResultMessage data;
  const AnalysisResultServerMessage(this.data);
}

/// error 메시지 (시스템 에러)
final class ErrorServerMessage extends ServerMessage {
  final int? frameIndex;
  final String errorCode;
  final String? errorDetail;

  const ErrorServerMessage({
    this.frameIndex,
    required this.errorCode,
    this.errorDetail,
  });

  factory ErrorServerMessage.fromJson(Map<String, dynamic> json) {
    return ErrorServerMessage(
      frameIndex: (json['frame_index'] as num?)?.toInt(),
      errorCode: json['error_code'] as String? ?? 'unknown',
      errorDetail: json['error_detail'] as String?,
    );
  }
}

/// 명세에 없는 type에 대한 fallback
///
/// 새로운 type이 추가되었을 때 앱이 안 죽도록.
/// 디버그 로깅용.
final class UnknownServerMessage extends ServerMessage {
  final String? rawType;
  final Map<String, dynamic> raw;

  const UnknownServerMessage({this.rawType, required this.raw});
}
