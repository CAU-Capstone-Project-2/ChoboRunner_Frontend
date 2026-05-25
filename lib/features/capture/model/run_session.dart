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

  Map<String, dynamic> toCreateJson() {
    return {
      'id': int.parse(id),
      'userId': int.parse(userId),
      if (mode != null) 'mode': mode,
      if (status != null) 'status': status,
      if (videoS3Key != null) 'videoS3Key': videoS3Key,
      if (duration != null) 'duration': duration,
    };
  }
}
