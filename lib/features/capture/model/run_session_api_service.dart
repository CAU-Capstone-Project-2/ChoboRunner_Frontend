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
    final decoded = jsonDecode(utf8.decode(res.bodyBytes));
    return RunSession.fromJson(decoded as Map<String, dynamic>);
  }

  Future<RunSession> updateRun(RunSession run) async {
    final res = await _client.put(
      _uri('/api/runs/${run.id}'),
      headers: defaultHeaders(withJson: true),
      body: jsonEncode(run.toUpdateJson()),
    );
    if (res.statusCode != 200) {
      throw Exception(
          'PUT /api/runs/${run.id} failed (${res.statusCode}): ${res.body}');
    }
    final decoded = jsonDecode(utf8.decode(res.bodyBytes));
    return RunSession.fromJson(decoded as Map<String, dynamic>);
  }

  /// 원본 mp4를 업로드하여 AI 오버레이 합성 요청.
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
