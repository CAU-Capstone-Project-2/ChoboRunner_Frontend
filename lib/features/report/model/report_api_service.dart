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
}
