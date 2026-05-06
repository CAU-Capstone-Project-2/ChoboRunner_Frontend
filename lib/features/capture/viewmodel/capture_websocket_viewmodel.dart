import 'dart:async';
import 'dart:typed_data';

import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../model/capture_websocket_service.dart';
import '../model/feedback_message.dart';
import 'capture_websocket_provider.dart';

/// 측정 화면이 watch할 WebSocket 상태
class CaptureWebSocketState {
  final ConnectionStatus status;
  final FeedbackMessage? latestMessage;
  final int receivedCount;
  final int errorCount;
  final String? lastError;

  const CaptureWebSocketState({
    this.status = ConnectionStatus.disconnected,
    this.latestMessage,
    this.receivedCount = 0,
    this.errorCount = 0,
    this.lastError,
  });

  CaptureWebSocketState copyWith({
    ConnectionStatus? status,
    FeedbackMessage? latestMessage,
    int? receivedCount,
    int? errorCount,
    String? lastError,
    bool clearLastError = false,
  }) {
    return CaptureWebSocketState(
      status: status ?? this.status,
      latestMessage: latestMessage ?? this.latestMessage,
      receivedCount: receivedCount ?? this.receivedCount,
      errorCount: errorCount ?? this.errorCount,
      lastError: clearLastError ? null : (lastError ?? this.lastError),
    );
  }

  bool get isConnected => status == ConnectionStatus.connected;
  bool get isConnecting => status == ConnectionStatus.connecting;
}

/// 측정 화면용 WebSocket ViewModel
class CaptureWebSocketViewModel extends Notifier<CaptureWebSocketState> {
  late final CaptureWebSocketService _service;
  StreamSubscription<ConnectionStatus>? _statusSub;
  StreamSubscription<FeedbackMessage>? _messageSub;

  @override
  CaptureWebSocketState build() {
    _service = ref.read(captureWebSocketServiceProvider);

    // 서비스 스트림 구독
    _statusSub = _service.statusStream.listen(_onStatusChanged);
    _messageSub = _service.messageStream.listen(_onMessageReceived);

    // ViewModel 폐기 시 구독 해제 (서비스 자체는 Provider가 관리)
    ref.onDispose(() {
      _statusSub?.cancel();
      _messageSub?.cancel();
    });

    // 초기 상태는 서비스의 현재 상태로
    return CaptureWebSocketState(status: _service.status);
  }

  // ─────────── 화면이 호출할 액션 ───────────

  /// WebSocket 연결 시작
  Future<void> connect() async {
    state = state.copyWith(clearLastError: true);
    await _service.connect();
  }

  /// 연결 종료 (사용자 의도)
  Future<void> disconnect() async {
    await _service.disconnect();
  }

  /// 카메라 프레임 전송
  ///
  /// 호출 측은 이미 압축된 JPEG bytes를 전달해야 함.
  bool sendFrame(Uint8List frame) {
    return _service.sendFrame(frame);
  }

  // ─────────── 내부 상태 업데이트 ───────────

  void _onStatusChanged(ConnectionStatus status) {
    state = state.copyWith(status: status);
  }

  void _onMessageReceived(FeedbackMessage message) {
    if (message.isOk) {
      state = state.copyWith(
        latestMessage: message,
        receivedCount: state.receivedCount + 1,
        clearLastError: true,
      );
    } else if (message.isError) {
      state = state.copyWith(
        latestMessage: message,
        errorCount: state.errorCount + 1,
        lastError: message.error,
      );
    } else {
      // unknown status: 일단 카운트만 증가
      state = state.copyWith(
        receivedCount: state.receivedCount + 1,
      );
    }
  }
}

/// 측정 WebSocket ViewModel Provider
final captureWebSocketViewModelProvider = NotifierProvider<
    CaptureWebSocketViewModel, CaptureWebSocketState>(
  CaptureWebSocketViewModel.new,
);
