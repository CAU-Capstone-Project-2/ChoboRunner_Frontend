import 'dart:async';
import 'dart:typed_data';

import 'package:web_socket_channel/web_socket_channel.dart';
import 'package:web_socket_channel/status.dart' as ws_status;

import 'server_message.dart';

/// WebSocket 연결 상태
enum ConnectionStatus {
  disconnected,
  connecting,
  connected,
  error,
}

/// 측정용 WebSocket 통신 서비스
///
/// - binary 프레임 전송
/// - 서버에서 받은 JSON 텍스트를 FeedbackMessage로 파싱해서 노출
/// - 연결 상태 스트림 노출
/// - 옵션으로 자동 재연결
class CaptureWebSocketService {
  CaptureWebSocketService({
    required this.uri,
    this.autoReconnect = true,
    this.maxReconnectAttempts = 5,
    this.initialReconnectDelay = const Duration(seconds: 1),
    this.maxReconnectDelay = const Duration(seconds: 30),
  });

  /// 연결할 WebSocket URI (예: wss://.../ws/chobo-runner)
  final Uri uri;

  /// 비정상 종료 시 자동 재연결 여부
  final bool autoReconnect;

  /// 최대 재연결 시도 횟수
  final int maxReconnectAttempts;

  /// 첫 재연결까지 대기 시간 (이후 지수적으로 증가)
  final Duration initialReconnectDelay;

  /// 재연결 대기 시간 상한
  final Duration maxReconnectDelay;

  WebSocketChannel? _channel;
  StreamSubscription<dynamic>? _subscription;

  final _statusController = StreamController<ConnectionStatus>.broadcast();
  final _messageController = StreamController<ServerMessage>.broadcast();

  ConnectionStatus _status = ConnectionStatus.disconnected;
  int _reconnectAttempts = 0;
  Timer? _reconnectTimer;
  bool _intentionallyClosed = false;

  /// 연결 상태 스트림 (UI에서 watch)
  Stream<ConnectionStatus> get statusStream => _statusController.stream;

  /// 파싱된 피드백 메시지 스트림
  Stream<ServerMessage> get messageStream => _messageController.stream;

  /// 현재 연결 상태 (즉시 조회용)
  ConnectionStatus get status => _status;

  bool get isConnected => _status == ConnectionStatus.connected;

  /// WebSocket 연결 시작. [runId]가 있으면 URL에 ?runId= 쿼리 파라미터 추가.
  Future<void> connect({String? runId}) async {
    if (_status == ConnectionStatus.connecting ||
        _status == ConnectionStatus.connected) {
      return;
    }

    _intentionallyClosed = false;
    final connectUri = runId != null
        ? uri.replace(queryParameters: {'runId': runId})
        : uri;
    // ignore: avoid_print
    print('[WS] connecting to $connectUri');
    _setStatus(ConnectionStatus.connecting);

    try {
      _channel = WebSocketChannel.connect(connectUri);

      // ready를 기다려 핸드셰이크 완료 시점을 명확히 함
      await _channel!.ready;

      _setStatus(ConnectionStatus.connected);
      _reconnectAttempts = 0;

      _subscription = _channel!.stream.listen(
        _handleMessage,
        onError: _handleError,
        onDone: _handleDone,
        cancelOnError: false,
      );
    } catch (e, st) {
      // ignore: avoid_print
      print('[WS] connect error: $e');
      // ignore: avoid_print
      print('[WS] stack: $st');
      _setStatus(ConnectionStatus.error);
      _scheduleReconnectIfNeeded();
    }
  }

  /// 카메라 프레임(JPEG bytes) 전송.
  ///
  /// 백엔드 프로토콜: `[8B big-endian int64 ts_ms][JPEG bytes]` 단일 binary 메시지.
  /// ts_ms는 단조시계 기준 ms이며 비감소여야 한다 (Stopwatch.elapsedMilliseconds 사용 권장).
  ///
  /// 연결되지 않은 상태에서 호출하면 false 반환.
  bool sendFrame(Uint8List jpegBytes, {required int tsMs}) {
    if (!isConnected || _channel == null) {
      return false;
    }
    try {
      final framed = Uint8List(8 + jpegBytes.length);
      final header = ByteData.view(framed.buffer, 0, 8);
      header.setInt64(0, tsMs, Endian.big);
      framed.setRange(8, framed.length, jpegBytes);
      _channel!.sink.add(framed);
      return true;
    } catch (_) {
      return false;
    }
  }

  /// 텍스트 메시지 전송 (필요시 사용)
  bool sendText(String text) {
    if (!isConnected || _channel == null) {
      return false;
    }
    try {
      _channel!.sink.add(text);
      return true;
    } catch (_) {
      return false;
    }
  }

  /// 세션 시작 메타데이터 전송. 첫 binary frame 전에 호출해야 함.
  bool sendSessionStart({
    required String analysisSide,
    required String direction,
  }) {
    return sendText(
      '{"type":"session_start",'
      '"analysis_side":"$analysisSide",'
      '"direction":"$direction"}',
    );
  }

  /// 측정 세션 종료 신호 송신
  ///
  /// 백엔드 명세에 따라 text frame {"type":"stop"} 전송.
  /// AI 서버는 이 신호를 받으면 즉시 누적 분석 결과(analysis_result)를 응답.
  ///
  /// 호출 후 연결을 바로 끊지 말 것 — analysis_result를 받기 위해 잠시 유지 필요.
  /// 연결 종료는 결과를 받거나 타임아웃 후에 disconnect()로 따로 처리.
  bool sendStop() {
    return sendText('{"type":"stop"}');
  }

  /// 연결 종료 (사용자 의도)
  Future<void> disconnect() async {
    _intentionallyClosed = true;
    _reconnectTimer?.cancel();
    _reconnectTimer = null;

    try {
      await _subscription?.cancel();
    } catch (_) {}
    _subscription = null;

    try {
      await _channel?.sink.close(ws_status.normalClosure);
    } catch (_) {}
    _channel = null;

    _setStatus(ConnectionStatus.disconnected);
  }

  /// 서비스 자체를 폐기 (앱 종료 시)
  Future<void> dispose() async {
    await disconnect();
    await _statusController.close();
    await _messageController.close();
  }

  // ─────────── 내부 핸들러 ───────────

  void _handleMessage(dynamic data) {
    // ignore: avoid_print
    print('[WS] message received: type=${data.runtimeType}, length=${data is String ? data.length : data is List ? data.length : "?"}');

    if (data is String) {
      // ignore: avoid_print
      print('[WS] text first 200: ${data.length > 200 ? data.substring(0, 200) : data}');

      final parsed = ServerMessage.tryParse(data);
      if (parsed == null) {
        // ignore: avoid_print
        print('[WS] PARSE FAILED');
      } else {
        // ignore: avoid_print
        print('[WS] parsed type: ${parsed.runtimeType}');
        _messageController.add(parsed);
      }
    } else if (data is List<int>) {
      // 현재 명세상 서버는 text JSON만 보냄. binary 응답은 무시.
      // ignore: avoid_print
      print('[WS] received binary (ignored)');
    }
  }

  void _handleError(Object error) {
    // ignore: avoid_print
    print('[WS] stream error: $error');
    if (_intentionallyClosed) return;
    _setStatus(ConnectionStatus.error);
    _scheduleReconnectIfNeeded();
  }

  void _handleDone() {
    // ignore: avoid_print
    print('[WS] connection closed (intentional=$_intentionallyClosed, code=${_channel?.closeCode}, reason=${_channel?.closeReason})');
    if (_intentionallyClosed) {
      _setStatus(ConnectionStatus.disconnected);
      return;
    }
    _setStatus(ConnectionStatus.disconnected);
    _scheduleReconnectIfNeeded();
  }

  void _scheduleReconnectIfNeeded() {
    if (!autoReconnect || _intentionallyClosed) return;
    if (_reconnectAttempts >= maxReconnectAttempts) return;

    _reconnectAttempts++;

    // 지수 백오프: initial * 2^(attempts-1), 단 maxDelay 상한
    final delayMs = initialReconnectDelay.inMilliseconds *
        (1 << (_reconnectAttempts - 1).clamp(0, 30));
    final delay = Duration(
      milliseconds: delayMs.clamp(
        initialReconnectDelay.inMilliseconds,
        maxReconnectDelay.inMilliseconds,
      ),
    );

    _reconnectTimer?.cancel();
    _reconnectTimer = Timer(delay, () {
      connect();
    });
  }

  void _setStatus(ConnectionStatus next) {
    if (_status == next) return;
    _status = next;
    _statusController.add(next);
  }
}
