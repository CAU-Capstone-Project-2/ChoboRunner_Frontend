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
  Map<String, dynamic> toUpdateJson() {
    return {
      'userId': int.parse(userId),
      'createdDate': createdDate ?? DateTime.now().toIso8601String(),
      'mode': mode ?? 'normal',
      'status': status ?? 'DONE',
      if (duration != null) 'duration': duration,
      if (videoS3Key != null) 'videoS3Key': videoS3Key,
    };
  }
}
