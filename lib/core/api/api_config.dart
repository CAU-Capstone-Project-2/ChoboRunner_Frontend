/// REST API base URL.
///
/// WebSocket과 도메인 동일 (capstone2-backend.foopky.com).
/// TODO: dart-define으로 분리.
const String kApiBaseUrl = 'https://capstone2-backend.foopky.com';

/// API Bearer 키.
///
/// 백엔드 ApiKeyFilter가 게이트로 사용. 클라가 코드에 박아서 매 요청에 자동 첨부.
const String kApiKey = 'A9fDFgdc3f';

/// 모든 REST 요청에 공통으로 붙는 헤더.
///
/// [withJson] 이 true 면 `Content-Type: application/json` 도 추가.
Map<String, String> defaultHeaders({bool withJson = false}) {
  return {
    if (kApiKey.isNotEmpty) 'Authorization': 'Bearer $kApiKey',
    if (withJson) 'Content-Type': 'application/json',
  };
}
