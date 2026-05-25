import 'dart:convert';

import 'package:http/http.dart' as http;

import '../../../core/api/api_config.dart';
import 'user.dart';

/// Thrown when the username already exists during signup.
class UsernameTakenException implements Exception {
  final String username;
  UsernameTakenException(this.username);
  @override
  String toString() => 'Username already taken: $username';
}

/// Thrown when sign-in credentials are rejected by the server.
class InvalidCredentialsException implements Exception {
  final int statusCode;
  InvalidCredentialsException(this.statusCode);
  @override
  String toString() => 'Invalid credentials (HTTP $statusCode)';
}

class UserApiException implements Exception {
  final int statusCode;
  final String body;
  UserApiException(this.statusCode, this.body);

  String get userMessage {
    try {
      final map = jsonDecode(body);
      if (map is Map<String, dynamic> && map.containsKey('message')) {
        return map['message'] as String;
      }
    } catch (_) {}
    return '서버 오류 ($statusCode)';
  }

  @override
  String toString() => 'UserApiException($statusCode): $body';
}

/// User REST 클라이언트.
///
/// 백엔드 `/api/users` CRUD + `POST /api/users/login` 인증.
class UserApiService {
  UserApiService({http.Client? client}) : _client = client ?? http.Client();

  final http.Client _client;

  Uri _uri(String path) => Uri.parse('$kApiBaseUrl$path');

  /// 전체 사용자 조회.
  Future<List<User>> getAllUsers() async {
    final res = await _client.get(_uri('/api/users'), headers: defaultHeaders());
    if (res.statusCode != 200) {
      throw UserApiException(res.statusCode, res.body);
    }
    final decoded = jsonDecode(utf8.decode(res.bodyBytes));
    if (decoded is! List) {
      throw UserApiException(res.statusCode, 'expected list, got ${decoded.runtimeType}');
    }
    return decoded
        .whereType<Map<String, dynamic>>()
        .map(User.fromJson)
        .toList();
  }

  /// 단일 조회. 없으면 null.
  Future<User?> getById(String id) async {
    final res = await _client.get(_uri('/api/users/$id'), headers: defaultHeaders());
    if (res.statusCode == 404) return null;
    if (res.statusCode != 200) {
      throw UserApiException(res.statusCode, res.body);
    }
    final decoded = jsonDecode(utf8.decode(res.bodyBytes));
    if (decoded is! Map<String, dynamic>) {
      throw UserApiException(res.statusCode, 'expected object');
    }
    return User.fromJson(decoded);
  }

  /// 사용자 생성. id 중복/username 중복은 호출 측이 [findByUsername]으로 사전 체크.
  ///
  /// 백엔드가 id를 자동 발급하므로 응답에서 id를 받아 반환. 응답이 비어 있으면
  /// username으로 재조회.
  Future<User> createUser(User user) async {
    final res = await _client.post(
      _uri('/api/users'),
      headers: defaultHeaders(withJson: true),
      body: jsonEncode(user.toCreateJson()),
    );
    if (res.statusCode != 200 && res.statusCode != 201) {
      throw UserApiException(res.statusCode, res.body);
    }
    if (res.body.isNotEmpty) {
      final decoded = jsonDecode(utf8.decode(res.bodyBytes));
      if (decoded is Map<String, dynamic>) {
        return User.fromJson(decoded);
      }
    }
    final fetched = await findByUsername(user.username);
    if (fetched != null) return fetched;
    throw UserApiException(res.statusCode, 'createUser: empty body and re-fetch failed');
  }

  /// username으로 사용자 검색. 없으면 null.
  ///
  /// 전체 조회 후 클라에서 매칭. 사용자 수가 많아지면 백엔드에
  /// `/api/users/by-username/{username}` 추가 요청 필요.
  Future<User?> findByUsername(String username) async {
    final all = await getAllUsers();
    for (final u in all) {
      if (u.username == username) return u;
    }
    return null;
  }

  /// 로그인.
  ///
  /// `POST /api/users/login {username, password}` → 200 OK면 User 반환,
  /// 그 외 상태는 [InvalidCredentialsException].
  Future<User> login({required String username, required String password}) async {
    final res = await _client.post(
      _uri('/api/users/login'),
      headers: defaultHeaders(withJson: true),
      body: jsonEncode({'username': username, 'password': password}),
    );
    if (res.statusCode != 200) {
      throw InvalidCredentialsException(res.statusCode);
    }
    final decoded = jsonDecode(utf8.decode(res.bodyBytes));
    if (decoded is! Map<String, dynamic>) {
      throw UserApiException(res.statusCode, 'expected object');
    }
    return User.fromJson(decoded);
  }
}
