import 'dart:async';

import 'package:flutter/foundation.dart';

import 'camera_service.dart';
import 'capture_websocket_service.dart';

/// 캡처 루프 통계
@immutable
class CaptureLoopStats {
  final int sentCount;       // WebSocket으로 성공 전송한 프레임 수
  final int droppedCount;    // 백프레셔로 드롭한 프레임 수 (현재 사용 안 함)
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

/// 네이티브 Camera2가 푸시하는 JPEG를 받아 WebSocket으로 송신하는 루프.
///
/// 기존엔 Flutter camera 플러그인의 image stream을 33ms 폴링했으나, 일부 OEM에서
/// 3-surface 강제로 ImageAnalysis가 드롭되는 문제 때문에 네이티브 Camera2의
/// 2-surface(ImageReader + MediaRecorder)로 전환. 인코딩과 throttling은 네이티브가
/// 담당하고, 여기서는 푸시되는 JPEG를 WS로 흘리고 통계만 갱신.
class CaptureLoopController {
  CaptureLoopController({
    required this.camera,
    required this.webSocket,
  });

  /// 카메라 서비스 (Camera2 네이티브 진입점)
  final CameraService camera;

  /// WebSocket 서비스 (송신)
  final CaptureWebSocketService webSocket;

  /// 통계 (UI에서 watch)
  final ValueNotifier<CaptureLoopStats> stats =
      ValueNotifier(const CaptureLoopStats());

  /// 최신 인코딩된 JPEG (미리보기용).
  /// 측정 화면이 [Image.memory]로 직접 표시한다.
  final ValueNotifier<Uint8List?> latestJpeg = ValueNotifier(null);

  /// 녹화된 MP4 파일 경로. stop() 후 non-null이면 업로드 대상.
  String? _recordedFilePath;
  String? get recordedFilePath => _recordedFilePath;

  /// 프레임 캡처 시각을 백엔드에 전달할 단조 시계.
  final Stopwatch _monoClock = Stopwatch();

  /// 최근 전송 시각 큐 (최근 1초 윈도우)
  final List<DateTime> _recentSendTimes = [];

  StreamSubscription<Uint8List>? _frameSub;
  bool _running = false;

  /// 루프 시작 (네이티브 Camera2 녹화 + JPEG 수신 + WS 전송)
  Future<void> start() async {
    if (_running) return;
    _running = true;
    _recordedFilePath = null;

    stats.value = const CaptureLoopStats(isRunning: true);
    _monoClock
      ..reset()
      ..start();

    final ok = await camera.startCamera2Recording();
    if (!ok) {
      // ignore: avoid_print
      print('[CaptureLoop] Camera2 start failed');
      _running = false;
      stats.value = stats.value.copyWith(
        isRunning: false,
        errorCount: stats.value.errorCount + 1,
      );
      return;
    }

    _frameSub = camera.camera2.frames.listen(
      _onJpegFrame,
      onError: (Object e) {
        // ignore: avoid_print
        print('[CaptureLoop] frame stream error: $e');
        stats.value = stats.value.copyWith(
          errorCount: stats.value.errorCount + 1,
        );
      },
    );
  }

  /// 루프 종료. Camera2 정지 후 mp4 파일 경로 저장.
  Future<void> stop() async {
    if (!_running) return;
    _running = false;

    await _frameSub?.cancel();
    _frameSub = null;
    _recentSendTimes.clear();
    _monoClock.stop();
    stats.value = stats.value.copyWith(isRunning: false, sendFps: 0.0);

    _recordedFilePath = await camera.stopCamera2Recording();
  }

  /// 통계 리셋 (start 전에 호출하면 새 측정 세션처럼 보임)
  void reset() {
    _recentSendTimes.clear();
    _recordedFilePath = null;
    _debugFrameCount = 0;
    stats.value = const CaptureLoopStats();
    latestJpeg.value = null;
  }

  /// 컨트롤러 폐기
  void dispose() {
    stop();
    stats.dispose();
    latestJpeg.dispose();
  }

  // ─────────── 내부 ───────────

  int _debugFrameCount = 0;

  void _onJpegFrame(Uint8List jpeg) {
    latestJpeg.value = jpeg;
    _debugFrameCount++;

    final tsMs = _monoClock.elapsedMilliseconds;
    final ok = webSocket.sendFrame(jpeg, tsMs: tsMs);

    if (_debugFrameCount <= 3 || _debugFrameCount % 30 == 0) {
      // ignore: avoid_print
      print('[CaptureLoop] frame#$_debugFrameCount jpegSize=${jpeg.length} tsMs=$tsMs sent=$ok');
    }

    if (ok) {
      _recordSendAndUpdateFps();
    } else {
      stats.value = stats.value.copyWith(
        errorCount: stats.value.errorCount + 1,
      );
    }
  }

  /// 송신 시각 기록 + 최근 1초 fps 계산
  void _recordSendAndUpdateFps() {
    final now = DateTime.now();
    _recentSendTimes.add(now);

    final cutoff = now.subtract(const Duration(seconds: 1));
    _recentSendTimes.removeWhere((t) => t.isBefore(cutoff));

    final fps = _recentSendTimes.length.toDouble();

    stats.value = stats.value.copyWith(
      sentCount: stats.value.sentCount + 1,
      sendFps: fps,
    );
  }
}
