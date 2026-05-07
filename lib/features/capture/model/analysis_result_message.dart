import 'feedback_item.dart';

/// analysis_result 메시지의 status
enum AnalysisStatus {
  /// 분석 성공, 모든 데이터 응답
  success,

  /// 분석 성공이지만 신뢰도가 낮음. 결과 표시 + 재촬영 권장
  lowConfidence,

  /// 분석 실패. metrics 등 분석 데이터 없음, 재촬영 안내만
  failed,

  /// 명세에 없는 값
  unknown,
}

/// 착지 패턴 분류
enum FootStrikePattern {
  rearfoot, // RFS - 뒤꿈치 중심 착지
  midfoot,  // MFS - 중족부 착지
  forefoot, // FFS - 앞발 중심 착지
  unknown,
}

/// 분석 대상자 추적 안정성
enum TrackingStability {
  stable,
  borderline,
  unstable,
  unknown,
}

/// analysis_result 메시지 (최종 누적 결과)
///
/// 분석 종료 시점에 1회 응답됨.
/// 사용자 결과 화면의 단일 정답 위치.
class AnalysisResultMessage {
  final AnalysisStatus status;
  final VideoMeta videoMeta;
  final String? analysisSide; // "left" | "right" | null (failed)
  final PostureMetrics? metrics; // null when failed
  final Map<String, MetricStats>? metricDetails; // null when failed
  final QualitySummary? qualitySummary; // null when failed
  final String? primaryReasonCode;
  final List<String> reasonCodes;
  final String? message;
  final List<FeedbackItem> feedbackMessages;

  const AnalysisResultMessage({
    required this.status,
    required this.videoMeta,
    this.analysisSide,
    this.metrics,
    this.metricDetails,
    this.qualitySummary,
    this.primaryReasonCode,
    this.reasonCodes = const [],
    this.message,
    this.feedbackMessages = const [],
  });

  factory AnalysisResultMessage.fromJson(Map<String, dynamic> json) {
    return AnalysisResultMessage(
      status: _parseStatus(json['status'] as String?),
      videoMeta: json['video_meta'] is Map<String, dynamic>
          ? VideoMeta.fromJson(json['video_meta'] as Map<String, dynamic>)
          : VideoMeta.empty(),
      analysisSide: json['analysis_side'] as String?,
      metrics: json['metrics'] is Map<String, dynamic>
          ? PostureMetrics.fromJson(json['metrics'] as Map<String, dynamic>)
          : null,
      metricDetails: _parseMetricDetails(json['metric_details']),
      qualitySummary: json['quality_summary'] is Map<String, dynamic>
          ? QualitySummary.fromJson(
              json['quality_summary'] as Map<String, dynamic>)
          : null,
      primaryReasonCode: json['primary_reason_code'] as String?,
      reasonCodes: _parseStringList(json['reason_codes']),
      message: json['message'] as String?,
      feedbackMessages: parseFeedbackItems(json['feedback_messages']),
    );
  }

  static AnalysisStatus _parseStatus(String? raw) {
    switch (raw) {
      case 'success':
        return AnalysisStatus.success;
      case 'low_confidence':
        return AnalysisStatus.lowConfidence;
      case 'failed':
        return AnalysisStatus.failed;
      default:
        return AnalysisStatus.unknown;
    }
  }

  static Map<String, MetricStats>? _parseMetricDetails(dynamic raw) {
    if (raw is! Map<String, dynamic>) return null;
    final result = <String, MetricStats>{};
    raw.forEach((key, value) {
      if (value is Map<String, dynamic>) {
        result[key] = MetricStats.fromJson(value);
      }
    });
    return result.isEmpty ? null : result;
  }

  static List<String> _parseStringList(dynamic raw) {
    if (raw is! List) return const [];
    return raw.whereType<String>().toList();
  }

  /// 결과 데이터를 화면에 표시할 수 있는 상태인지
  /// (success 또는 low_confidence 일 때 true)
  bool get hasResultData =>
      status == AnalysisStatus.success ||
      status == AnalysisStatus.lowConfidence;

  /// 재촬영 권장 여부 (low_confidence 또는 failed)
  bool get shouldRecapture =>
      status == AnalysisStatus.lowConfidence ||
      status == AnalysisStatus.failed;
}

// ─────────── 중첩 객체들 ───────────

/// 영상 메타데이터
class VideoMeta {
  final double durationSec;
  final double fpsActual;
  final Resolution resolution;
  final int totalFrames;

  const VideoMeta({
    required this.durationSec,
    required this.fpsActual,
    required this.resolution,
    required this.totalFrames,
  });

  factory VideoMeta.empty() => const VideoMeta(
        durationSec: 0,
        fpsActual: 0,
        resolution: Resolution(width: 0, height: 0),
        totalFrames: 0,
      );

  factory VideoMeta.fromJson(Map<String, dynamic> json) {
    return VideoMeta(
      durationSec: (json['duration_sec'] as num?)?.toDouble() ?? 0,
      fpsActual: (json['fps_actual'] as num?)?.toDouble() ?? 0,
      resolution: json['resolution'] is Map<String, dynamic>
          ? Resolution.fromJson(json['resolution'] as Map<String, dynamic>)
          : const Resolution(width: 0, height: 0),
      totalFrames: (json['total_frames'] as num?)?.toInt() ?? 0,
    );
  }
}

class Resolution {
  final int width;
  final int height;

  const Resolution({required this.width, required this.height});

  factory Resolution.fromJson(Map<String, dynamic> json) {
    return Resolution(
      width: (json['width'] as num?)?.toInt() ?? 0,
      height: (json['height'] as num?)?.toInt() ?? 0,
    );
  }
}

/// 핵심 자세 지표 3개
class PostureMetrics {
  final FootStrikePattern footStrikePattern;
  final double? footStrikeAngleDeg;
  final double? initialKneeFlexionDeg;
  final double? trunkLeanDeg;

  const PostureMetrics({
    required this.footStrikePattern,
    this.footStrikeAngleDeg,
    this.initialKneeFlexionDeg,
    this.trunkLeanDeg,
  });

  factory PostureMetrics.fromJson(Map<String, dynamic> json) {
    return PostureMetrics(
      footStrikePattern:
          _parseFootStrikePattern(json['foot_strike_pattern'] as String?),
      footStrikeAngleDeg: (json['foot_strike_angle_deg'] as num?)?.toDouble(),
      initialKneeFlexionDeg:
          (json['initial_knee_flexion_deg'] as num?)?.toDouble(),
      trunkLeanDeg: (json['trunk_lean_deg'] as num?)?.toDouble(),
    );
  }

  static FootStrikePattern _parseFootStrikePattern(String? raw) {
    switch (raw) {
      case 'RFS':
        return FootStrikePattern.rearfoot;
      case 'MFS':
        return FootStrikePattern.midfoot;
      case 'FFS':
        return FootStrikePattern.forefoot;
      default:
        return FootStrikePattern.unknown;
    }
  }
}

/// 지표별 stride 단위 통계
class MetricStats {
  final double median;
  final List<double> iqr; // [Q1, Q3]
  final int nStrides;

  const MetricStats({
    required this.median,
    required this.iqr,
    required this.nStrides,
  });

  factory MetricStats.fromJson(Map<String, dynamic> json) {
    final iqrRaw = json['iqr'];
    final iqr = <double>[];
    if (iqrRaw is List) {
      for (final v in iqrRaw) {
        if (v is num) iqr.add(v.toDouble());
      }
    }

    return MetricStats(
      median: (json['median'] as num?)?.toDouble() ?? 0,
      iqr: iqr,
      nStrides: (json['n_strides'] as num?)?.toInt() ?? 0,
    );
  }

  /// IQR이 정상적으로 [Q1, Q3] 두 값인지
  bool get hasValidIqr => iqr.length == 2;

  /// IQR 하한 (Q1)
  double? get q1 => hasValidIqr ? iqr[0] : null;

  /// IQR 상한 (Q3)
  double? get q3 => hasValidIqr ? iqr[1] : null;
}

/// 품질 검사 요약
class QualitySummary {
  final double validFrameRatio;
  final int icCandidateCount;
  final int validStrideCount;
  final double landmarkVisibilityAvg;
  final TrackingStability targetTrackingStability;

  const QualitySummary({
    required this.validFrameRatio,
    required this.icCandidateCount,
    required this.validStrideCount,
    required this.landmarkVisibilityAvg,
    required this.targetTrackingStability,
  });

  factory QualitySummary.fromJson(Map<String, dynamic> json) {
    return QualitySummary(
      validFrameRatio: (json['valid_frame_ratio'] as num?)?.toDouble() ?? 0,
      icCandidateCount: (json['ic_candidate_count'] as num?)?.toInt() ?? 0,
      validStrideCount: (json['valid_stride_count'] as num?)?.toInt() ?? 0,
      landmarkVisibilityAvg:
          (json['landmark_visibility_avg'] as num?)?.toDouble() ?? 0,
      targetTrackingStability:
          _parseStability(json['target_tracking_stability'] as String?),
    );
  }

  static TrackingStability _parseStability(String? raw) {
    switch (raw) {
      case 'stable':
        return TrackingStability.stable;
      case 'borderline':
        return TrackingStability.borderline;
      case 'unstable':
        return TrackingStability.unstable;
      default:
        return TrackingStability.unknown;
    }
  }
}
