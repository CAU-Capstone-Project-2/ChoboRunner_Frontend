import 'dart:async';

import 'package:flutter/foundation.dart';

import 'camera_service.dart';
import 'capture_websocket_service.dart';

/// 캡처 루프 통계
@immutable
class CaptureLoopStats {
  final int sentCount;       // WebSocket으로 성공 전송한 프레임 수
  final int droppedCount;    // 백프레셔로 드롭한 프레임 수
  final int errorCount;      // 캡처 또는 송신 실패 수
  final bool isRunning;      // 루프 동작 중 여부
  final double sendFps;      // 최근 1초간 전송 fps

  const CaptureLoopStats({
    this.sentCount = 0,
    this.droppedCount = 0,
    this.errorCount = 0,
    this.isRunning = false,
    this.sendFps = 0.0,
  });

  CaptureLoopStats copyWith({
    int? sentCount,
    int? droppedCount,
    int? errorCount,
    bool? isRunning,
    double? sendFps,
  }) {
    return CaptureLoopStats(
      sentCount: sentCount ?? this.sentCount,
      droppedCount: droppedCount ?? this.droppedCount,
      errorCount: errorCount ?? this.errorCount,
      isRunning: isRunning ?? this.isRunning,
      sendFps: sendFps ?? this.sendFps,
    );
  }
}

/// 카메라 프레임을 주기적으로 캡처해서 WebSocket으로 송신하는 루프 컨트롤러.
///
/// 백프레셔: 이전 캡처/송신이 진행 중이면 새 tick은 드롭.
/// 이는 takePicture + 압축이 100~300ms 걸릴 수 있어,
/// 짧은 주기 타이머가 누적되어 메모리 폭발하는 것을 방지하기 위함.
class CaptureLoopController {
  CaptureLoopController({
    required this.camera,
    required this.webSocket,
    this.tickInterval = const Duration(milliseconds: 100),
  });

  /// 카메라 서비스 (프레임 캡처)
  final CameraService camera;

  /// WebSocket 서비스 (송신)
  final CaptureWebSocketService webSocket;

  /// 타이머 주기 (기본 100ms = 10fps 목표)
  final Duration tickInterval;

  /// 통계 (UI에서 watch)
  final ValueNotifier<CaptureLoopStats> stats =
      ValueNotifier(const CaptureLoopStats());

  Timer? _timer;
  bool _isProcessing = false;

  /// 최근 전송 시각 큐 (최근 1초 윈도우)
  final List<DateTime> _recentSendTimes = [];

  /// 루프 시작
  ///
  /// WebSocket이 연결되지 않은 상태에서도 호출 가능 (송신은 자동 false 반환).
  /// 카메라가 초기화되지 않은 상태에서도 호출 가능 (캡처가 null 반환).
  void start() {
    if (_timer != null) return; // 이미 동작 중
    stats.value = const CaptureLoopStats(isRunning: true);
    _timer = Timer.periodic(tickInterval, (_) => _onTick());
  }

  /// 루프 종료
  ///
  /// 진행 중인 캡처/송신이 끝날 때까지는 기다리지 않음 (즉시 타이머 취소).
  void stop() {
    _timer?.cancel();
    _timer = null;
    _isProcessing = false;
    _recentSendTimes.clear();
    stats.value = stats.value.copyWith(isRunning: false, sendFps: 0.0);
  }

  /// 통계 리셋 (start 전에 호출하면 새 측정 세션처럼 보임)
  void reset() {
    _recentSendTimes.clear();
    stats.value = const CaptureLoopStats();
  }

  /// 컨트롤러 폐기
  void dispose() {
    stop();
    stats.dispose();
  }

  // ─────────── 내부 ───────────

  Future<void> _onTick() async {
    // 백프레셔: 이전 작업 진행 중이면 드롭
    if (_isProcessing) {
      stats.value = stats.value.copyWith(
        droppedCount: stats.value.droppedCount + 1,
      );
      return;
    }

    _isProcessing = true;
    try {
      final bytes = await camera.captureFrameBytes();
      if (bytes == null) {
        stats.value = stats.value.copyWith(
          errorCount: stats.value.errorCount + 1,
        );
        return;
      }

      final ok = webSocket.sendFrame(bytes);
      if (ok) {
        _recordSendAndUpdateFps();
      } else {
        stats.value = stats.value.copyWith(
          errorCount: stats.value.errorCount + 1,
        );
      }
    } catch (_) {
      stats.value = stats.value.copyWith(
        errorCount: stats.value.errorCount + 1,
      );
    } finally {
      _isProcessing = false;
    }
  }

  /// 송신 시각 기록 + 최근 1초 fps 계산
  void _recordSendAndUpdateFps() {
    final now = DateTime.now();
    _recentSendTimes.add(now);

    // 1초 이전 항목 제거
    final cutoff = now.subtract(const Duration(seconds: 1));
    _recentSendTimes.removeWhere((t) => t.isBefore(cutoff));

    // 최근 1초 내 송신 개수 = 현재 fps
    final fps = _recentSendTimes.length.toDouble();

    stats.value = stats.value.copyWith(
      sentCount: stats.value.sentCount + 1,
      sendFps: fps,
    );
  }
}
