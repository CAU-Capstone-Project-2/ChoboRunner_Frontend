import 'dart:convert';

import 'package:http/http.dart' as http;

import '../../../core/api/api_config.dart';

class ReportApiService {
  ReportApiService({http.Client? client}) : _client = client ?? http.Client();
  final http.Client _client;

  Uri _uri(String path) => Uri.parse('$kApiBaseUrl$path');

  Future<List<Map<String, dynamic>>> _getList(String path) async {
    final res = await _client.get(_uri(path), headers: defaultHeaders());
    if (res.statusCode != 200) {
      throw Exception('GET $path failed (${res.statusCode})');
    }
    final decoded = jsonDecode(utf8.decode(res.bodyBytes));
    if (decoded is! List) return [];
    return decoded.cast<Map<String, dynamic>>();
  }

  Future<Map<String, dynamic>?> _getOne(String path) async {
    final res = await _client.get(_uri(path), headers: defaultHeaders());
    if (res.statusCode != 200) return null;
    final decoded = jsonDecode(utf8.decode(res.bodyBytes));
    if (decoded is Map<String, dynamic>) return decoded;
    return null;
  }

  Future<List<Map<String, dynamic>>> getRunsByUser(String userId) =>
      _getList('/api/runs/by-user/$userId');

  Future<Map<String, dynamic>?> getRun(String runId) =>
      _getOne('/api/runs/$runId');

  Future<List<Map<String, dynamic>>> getReportsByRun(String runId) =>
      _getList('/api/reports/by-run/$runId');

  Future<List<Map<String, dynamic>>> getDetailedReports(String reportId) =>
      _getList('/api/detailed-reports/by-report/$reportId');

  Future<List<Map<String, dynamic>>> getHighlightsByRun(String runId) =>
      _getList('/api/highlights/by-run/$runId');

  Future<List<Map<String, dynamic>>> getFeedbacksByRun(String runId) =>
      _getList('/api/feedbacks/by-run/$runId');

  /// run.duration만 부분 PUT. 백엔드가 @DynamicUpdate를 적용해 다른 필드는
  /// 보존된다. 하이라이트 화면에서 영상 길이를 알게 됐을 때 비어있던 duration을
  /// 백필하는 용도.
  Future<void> patchRunDuration(String runId, int durationSec) async {
    await _client.put(
      _uri('/api/runs/$runId'),
      headers: defaultHeaders(withJson: true),
      body: jsonEncode({'duration': durationSec}),
    );
  }

  Future<String?> getPresignedUrl(String key) async {
    final res = await _client.get(
      Uri.parse('$kApiBaseUrl/api/s3/presigned-url')
          .replace(queryParameters: {'key': key}),
      headers: defaultHeaders(),
    );
    if (res.statusCode != 200) return null;
    final decoded = jsonDecode(utf8.decode(res.bodyBytes));
    return decoded['url'] as String?;
  }
}
