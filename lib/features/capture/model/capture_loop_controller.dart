import 'dart:async';

import 'package:flutter/foundation.dart';

import 'camera_service.dart';
import 'capture_websocket_service.dart';
import 'frame_encoder.dart';

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

/// 카메라 image stream의 최신 프레임을 주기적으로 꺼내 YUV→JPEG 인코딩 후
/// WebSocket으로 송신하는 루프.
///
/// 백프레셔: 이전 tick의 인코딩/송신이 끝나지 않았으면 새 tick은 드롭.
/// (인코딩이 100~200ms 걸릴 수 있어 33ms 타이머가 누적되어 메모리 폭발하는 것 방지.)
///
/// MP4 녹화: startVideoRecording(onAvailable:)으로 녹화와 프레임 수신을 동시에
/// 수행한다. 녹화 실패 시 startImageStream 폴백.
class CaptureLoopController {
  CaptureLoopController({
    required this.camera,
    required this.webSocket,
    this.tickInterval = const Duration(milliseconds: 33), // ~30fps
  });

  /// 카메라 서비스 (image stream + 최신 프레임 캐시)
  final CameraService camera;

  /// WebSocket 서비스 (송신)
  final CaptureWebSocketService webSocket;

  /// 타이머 주기 (기본 33ms = 30fps 목표)
  final Duration tickInterval;

  /// 통계 (UI에서 watch)
  final ValueNotifier<CaptureLoopStats> stats =
      ValueNotifier(const CaptureLoopStats());

  /// 최신 인코딩된 JPEG (미리보기용).
  /// CameraX SurfaceProcessor의 OEM별 회전 차이를 우회하려고
  /// WS 송신용 JPEG를 그대로 화면에 띄운다. JPEG는 네이티브에서
  /// sensorOrientation을 명시 적용해 회전하므로 모든 폰에서 정방향.
  final ValueNotifier<Uint8List?> latestJpeg = ValueNotifier(null);

  Timer? _timer;
  bool _isProcessing = false;

  /// 녹화된 MP4 파일 경로. stop() 후 non-null이면 업로드 대상.
  String? _recordedFilePath;
  String? get recordedFilePath => _recordedFilePath;

  /// 프레임 캡처 시각을 백엔드에 전달할 단조 시계.
  /// start() 시점에 reset+start.
  final Stopwatch _monoClock = Stopwatch();

  /// 최근 전송 시각 큐 (최근 1초 윈도우)
  final List<DateTime> _recentSendTimes = [];

  /// 루프 시작 (녹화 + WS 프레임 전송 동시)
  ///
  /// camera.startRecording()으로 MP4 녹화와 프레임 콜백을 동시에 받는다.
  /// 녹화 시작에 실패하면 startStream() 폴백으로 WS 전송만 유지.
  Future<void> start() async {
    if (_timer != null) return; // 이미 동작 중
    stats.value = const CaptureLoopStats(isRunning: true);
    _recordedFilePath = null;

    _monoClock
      ..reset()
      ..start();

    try {
      await camera.startRecording();
    } catch (e) {
      // 녹화 시작 실패 → 프레임 스트림만이라도 시작
      // ignore: avoid_print
      print('[CaptureLoop] recording failed, falling back to stream: $e');
      try {
        await camera.startStream();
      } catch (_) {}
    }

    _timer = Timer.periodic(tickInterval, (_) => _onTick());
  }

  /// 루프 종료
  ///
  /// 녹화 중이면 stopRecording()으로 MP4 파일 경로 획득.
  /// 스트림만 동작 중이면 stopStream().
  Future<void> stop() async {
    _timer?.cancel();
    _timer = null;
    _isProcessing = false;
    _recentSendTimes.clear();
    _monoClock.stop();
    stats.value = stats.value.copyWith(isRunning: false, sendFps: 0.0);

    if (camera.isRecording) {
      _recordedFilePath = await camera.stopRecording();
    } else {
      await camera.stopStream();
    }
  }

  /// 통계 리셋 (start 전에 호출하면 새 측정 세션처럼 보임)
  void reset() {
    _recentSendTimes.clear();
    _recordedFilePath = null;
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

  Future<void> _onTick() async {
    if (_isProcessing) {
      stats.value = stats.value.copyWith(
        droppedCount: stats.value.droppedCount + 1,
      );
      return;
    }

    final image = camera.takeLatest();
    if (image == null) {
      // 아직 첫 프레임 도착 전 — 에러 아님
      return;
    }

    // YUV420 외 포맷은 현재 미지원 (iOS BGRA8888 등)
    if (image.planes.length < 3) {
      stats.value = stats.value.copyWith(
        errorCount: stats.value.errorCount + 1,
      );
      return;
    }

    final rotation = camera.sensorOrientation ?? 0;
    final tsMs = _monoClock.elapsedMilliseconds;

    _isProcessing = true;
    try {
      // CameraImage planes는 isolate로 못 보내므로 Uint8List로 복사.
      final input = FrameEncoderInput(
        yPlane: Uint8List.fromList(image.planes[0].bytes),
        uPlane: Uint8List.fromList(image.planes[1].bytes),
        vPlane: Uint8List.fromList(image.planes[2].bytes),
        yRowStride: image.planes[0].bytesPerRow,
        uvRowStride: image.planes[1].bytesPerRow,
        uvPixelStride: image.planes[1].bytesPerPixel ?? 1,
        width: image.width,
        height: image.height,
        rotationDegrees: rotation,
      );

      final jpeg = await encodeYuv420ToJpeg(input);
      if (jpeg == null) {
        stats.value = stats.value.copyWith(
          errorCount: stats.value.errorCount + 1,
        );
        return;
      }

      latestJpeg.value = jpeg;

      final ok = webSocket.sendFrame(jpeg, tsMs: tsMs);
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
