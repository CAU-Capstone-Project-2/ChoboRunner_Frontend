import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../model/capture_websocket_service.dart';

/// WebSocket 연결 URI
///
/// 로컬 개발: ws://127.0.0.1:8080/ws/chobo-runner
/// 운영:      wss://capstone2-backend.foopky.com/ws/chobo-runner
///
/// TODO: 추후 dart-define 또는 환경 변수로 분리
const String _kWebSocketUrl = 'wss://capstone2-backend.foopky.com/ws/chobo-runner';
// const String _kWebSocketUrl = 'wss://capstone2-backend.foopky.com/ws/chobo-runner';

/// 측정용 WebSocket 서비스 Provider
///
/// 앱 전역에서 단일 인스턴스를 공유.
/// Provider가 폐기될 때 service.dispose()가 호출됨.
final captureWebSocketServiceProvider =
    Provider<CaptureWebSocketService>((ref) {
  final service = CaptureWebSocketService(
    uri: Uri.parse(_kWebSocketUrl),
  );

  ref.onDispose(() {
    service.dispose();
  });

  return service;
});
