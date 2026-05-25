import 'dart:convert';
import 'dart:io';

import 'package:http/http.dart' as http;

import '../../../core/api/api_config.dart';
import 'run_session.dart';

class RunSessionApiService {
  RunSessionApiService({http.Client? client})
      : _client = client ?? http.Client();

  final http.Client _client;

  Uri _uri(String path, [Map<String, String>? query]) =>
      Uri.parse('$kApiBaseUrl$path').replace(queryParameters: query);

  Future<List<RunSession>> getAllRuns() async {
    final res =
        await _client.get(_uri('/api/runs'), headers: defaultHeaders());
    if (res.statusCode != 200) {
      throw Exception('GET /api/runs failed (${res.statusCode})');
    }
    final decoded = jsonDecode(utf8.decode(res.bodyBytes));
    if (decoded is! List) return [];
    return decoded
        .whereType<Map<String, dynamic>>()
        .map(RunSession.fromJson)
        .toList();
  }

  /// 전체 run 중 최대 id + 1로 글로벌 유니크 runId 생성.
  Future<String> generateRunId() async {
    final allRuns = await getAllRuns();
    int maxId = 0;
    for (final run in allRuns) {
      final id = int.tryParse(run.id) ?? 0;
      if (id > maxId) maxId = id;
    }
    return (maxId + 1).toString();
  }

  Future<RunSession> createRun(RunSession run) async {
    final res = await _client.post(
      _uri('/api/runs'),
      headers: defaultHeaders(withJson: true),
      body: jsonEncode(run.toCreateJson()),
    );
    if (res.statusCode != 200 && res.statusCode != 201) {
      throw Exception(
          'POST /api/runs failed (${res.statusCode}): ${res.body}');
    }
    if (res.body.isNotEmpty) {
      final decoded = jsonDecode(utf8.decode(res.bodyBytes));
      if (decoded is Map<String, dynamic>) {
        return RunSession.fromJson(decoded);
      }
    }
    return run;
  }

  /// 원본 mp4를 업로드하여 AI 오버레이 합성 요청.
  /// 서버가 합성 완료 후 갱신된 RunSessionDto를 반환 (videoS3Key 포함).
  /// 응답까지 2~3분 소요될 수 있음.
  Future<RunSession> uploadOverlay({
    required String runSessionId,
    required File videoFile,
  }) async {
    final uri = _uri('/api/analyze/overlay', {
      'RunSessionId': runSessionId,
    });
    final request = http.MultipartRequest('POST', uri)
      ..headers.addAll(defaultHeaders())
      ..files.add(await http.MultipartFile.fromPath('video', videoFile.path));

    final streamed = await request.send().timeout(
          const Duration(minutes: 5),
        );
    final res = await http.Response.fromStream(streamed);

    if (res.statusCode != 200) {
      throw Exception(
          'POST /api/analyze/overlay failed (${res.statusCode}): ${res.body}');
    }
    final decoded = jsonDecode(utf8.decode(res.bodyBytes));
    return RunSession.fromJson(decoded as Map<String, dynamic>);
  }

  /// S3 presigned URL 조회. 영상 재생용.
  Future<String> getPresignedUrl(
    String key, {
    int expiresInSeconds = 3600,
  }) async {
    final res = await _client.get(
      _uri('/api/s3/presigned-url', {
        'key': key,
        'expiresInSeconds': expiresInSeconds.toString(),
      }),
      headers: defaultHeaders(),
    );
    if (res.statusCode != 200) {
      throw Exception(
          'GET /api/s3/presigned-url failed (${res.statusCode}): ${res.body}');
    }
    final decoded = jsonDecode(utf8.decode(res.bodyBytes));
    return decoded['url'] as String;
  }
}
