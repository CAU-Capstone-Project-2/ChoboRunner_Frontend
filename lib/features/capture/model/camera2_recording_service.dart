import 'dart:async';
import 'dart:io';

import 'package:flutter/services.dart';

/// 네이티브 Camera2 캡처 세션을 제어하는 Dart 래퍼.
///
/// Flutter `camera` 플러그인이 Preview + VideoCapture + ImageAnalysis 3-surface를
/// 강제해 일부 OEM(S24 등)에서 ImageAnalysis가 드롭되는 문제 우회용.
///
/// 측정 화면 미리보기는 Method D(JPEG `Image.memory`)로 처리하므로 Preview surface가
/// 필요 없고, 여기서 2-surface(ImageReader + MediaRecorder)만 운영.
class Camera2RecordingService {
  static const MethodChannel _methodChannel =
      MethodChannel('chobo_runner/camera2_recording');
  static const EventChannel _eventChannel =
      EventChannel('chobo_runner/camera2_frames');

  StreamSubscription<dynamic>? _frameSub;

  /// 매 프레임 JPEG 바이트를 푸시하는 스트림.
  /// [start] 호출 후 구독 시작; [stop] 호출 시 자동 해제됨.
  final StreamController<Uint8List> _framesController =
      StreamController<Uint8List>.broadcast();

  Stream<Uint8List> get frames => _framesController.stream;

  bool _running = false;
  bool get isRunning => _running;

  /// 녹화 + 프레임 캡처 시작.
  ///
  /// 출력 mp4 경로는 네이티브가 cacheDir에 자동 생성. [stop]에서 경로 회수.
  /// 반환값은 카메라 open + 세션 구성 성공 여부.
  Future<bool> start() async {
    if (_running) return false;

    _frameSub?.cancel();
    _frameSub = _eventChannel.receiveBroadcastStream().listen(
      (event) {
        if (_framesController.isClosed) return;
        if (event is Uint8List) {
          _framesController.add(event);
        } else if (event is List<int>) {
          _framesController.add(Uint8List.fromList(event));
        }
      },
      onError: (Object e) {
        // ignore: avoid_print
        print('[Camera2] frame stream error: $e');
      },
    );

    try {
      final ok =
          await _methodChannel.invokeMethod<bool>('start') ?? false;
      if (ok) {
        _running = true;
      } else {
        await _frameSub?.cancel();
        _frameSub = null;
      }
      return ok;
    } on PlatformException catch (e) {
      // ignore: avoid_print
      print('[Camera2] start failed: ${e.code} ${e.message}');
      await _frameSub?.cancel();
      _frameSub = null;
      return false;
    }
  }

  /// 녹화 + 캡처 중지. 저장된 mp4 경로 반환 (실패/빈 파일이면 null).
  Future<String?> stop() async {
    if (!_running) return null;
    _running = false;

    String? returned;
    try {
      returned = await _methodChannel.invokeMethod<String?>('stop');
    } on PlatformException catch (e) {
      // ignore: avoid_print
      print('[Camera2] stop failed: ${e.code} ${e.message}');
    }

    await _frameSub?.cancel();
    _frameSub = null;

    if (returned == null) return null;
    final file = File(returned);
    if (!await file.exists()) return null;
    final size = await file.length();
    if (size <= 0) {
      await file.delete().catchError((_) => file);
      return null;
    }
    return returned;
  }

  Future<void> dispose() async {
    if (_running) {
      await stop();
    }
    await _frameSub?.cancel();
    _frameSub = null;
    await _framesController.close();
  }
}
