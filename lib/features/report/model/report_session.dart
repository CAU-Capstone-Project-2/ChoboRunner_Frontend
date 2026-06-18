import 'package:flutter/foundation.dart';

@immutable
class ReportSession {
  final String id;
  final DateTime date;
  final int? duration;
  final String status;

  const ReportSession({
    required this.id,
    required this.date,
    this.duration,
    required this.status,
  });

  factory ReportSession.fromJson(Map<String, dynamic> json) {
    return ReportSession(
      id: json['id'].toString(),
      date: DateTime.tryParse(json['createdDate'] as String? ?? '') ??
          DateTime.now(),
      duration: (json['duration'] as num?)?.toInt(),
      status: json['status'] as String? ?? '',
    );
  }
}
