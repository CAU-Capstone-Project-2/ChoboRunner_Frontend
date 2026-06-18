class RunSession {
  final String id;
  final String userId;
  final String? createdDate;
  final String? mode;
  final String? status;
  final String? videoS3Key;
  final int? duration;

  const RunSession({
    required this.id,
    required this.userId,
    this.createdDate,
    this.mode,
    this.status,
    this.videoS3Key,
    this.duration,
  });

  factory RunSession.fromJson(Map<String, dynamic> json) {
    return RunSession(
      id: json['id'].toString(),
      userId: json['userId'].toString(),
      createdDate: json['createdDate'] as String?,
      mode: json['mode'] as String?,
      status: json['status'] as String?,
      videoS3Key: json['videoS3Key'] as String?,
      duration: (json['duration'] as num?)?.toInt(),
    );
  }

  /// POST /api/runs 요청 body. id는 서버 자동 생성.
  Map<String, dynamic> toCreateJson() {
    return {
      'userId': int.parse(userId),
      'createdDate': createdDate ?? DateTime.now().toIso8601String(),
      'mode': mode ?? 'normal',
      'status': status ?? 'RUNNING',
      if (duration != null) 'duration': duration,
    };
  }

  /// PUT /api/runs/{id} 요청 body.
  ///
  /// 백엔드가 부분 업데이트(@DynamicUpdate)를 지원하므로, null인 필드는
  /// 보내지 않아 기존 DB 값을 보존시킨다. 예: duration만 보내고 status는
  /// 그대로 RUNNING으로 유지되게 하는 등 분리 호출이 가능.
  Map<String, dynamic> toUpdateJson() {
    return {
      'userId': int.parse(userId),
      if (createdDate != null) 'createdDate': createdDate,
      if (mode != null) 'mode': mode,
      if (status != null) 'status': status,
      if (duration != null) 'duration': duration,
      if (videoS3Key != null) 'videoS3Key': videoS3Key,
    };
  }
}
