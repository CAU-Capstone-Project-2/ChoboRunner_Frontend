import 'package:camera/camera.dart';
import 'package:flutter/services.dart';

import 'camera2_recording_service.dart';

/// 카메라 하드웨어를 감싸는 서비스.
///
/// - 설정 화면 미리보기: Flutter `camera` 플러그인 사용 (`controller`)
/// - 측정 중 녹화 + 분석 프레임: 네이티브 Camera2 사용 (`camera2`)
///   → 일부 OEM(S24 등)에서 3-surface 강제로 ImageAnalysis가 드롭되는 문제를
///     우회하기 위해 2-surface(ImageReader + MediaRecorder)로 직접 운영
class CameraService {
  CameraController? _controller;
  List<CameraDescription> _availableCameras = const [];
  CameraDescription? _selectedCamera;

  final Camera2RecordingService _camera2 = Camera2RecordingService();

  /// 설정 화면이 사용할 컨트롤러 (초기화 후 non-null).
  /// 측정 시작 시 [startCamera2Recording] 호출과 함께 dispose된다.
  CameraController? get controller => _controller;

  /// 측정 중 사용할 네이티브 Camera2 서비스.
  Camera2RecordingService get camera2 => _camera2;

  bool get isInitialized => _controller?.value.isInitialized ?? false;

  /// 선택된 카메라의 sensor orientation (degrees). 회전 보정 시 사용.
  int? get sensorOrientation => _selectedCamera?.sensorOrientation;

  /// 사용 가능한 카메라 목록 로드
  Future<List<CameraDescription>> loadAvailableCameras() async {
    _availableCameras = await availableCameras();
    return _availableCameras;
  }

  /// 후면 카메라 선택 (없으면 첫 번째 카메라)
  CameraDescription? _pickBackCamera() {
    if (_availableCameras.isEmpty) return null;
    return _availableCameras.firstWhere(
      (c) => c.lensDirection == CameraLensDirection.back,
      orElse: () => _availableCameras.first,
    );
  }

  /// Flutter 카메라 플러그인 controller 초기화 (설정 화면 미리보기용).
  /// 권한이 이미 허용된 상태에서 호출되어야 함.
  Future<void> initialize() async {
    if (_availableCameras.isEmpty) {
      await loadAvailableCameras();
    }

    final camera = _pickBackCamera();
    if (camera == null) {
      throw StateError('사용 가능한 카메라가 없습니다');
    }
    _selectedCamera = camera;

    // 이미 살아있으면 그대로 사용
    if (_controller != null && _controller!.value.isInitialized) return;

    await _controller?.dispose();

    _controller = CameraController(
      camera,
      ResolutionPreset.high, // 1280x720
      enableAudio: false,
      imageFormatGroup: ImageFormatGroup.yuv420,
    );

    await _controller!.initialize();
    await _controller!.lockCaptureOrientation(DeviceOrientation.portraitUp);
  }

  /// 측정 시작 — Flutter 플러그인 controller dispose + Camera2 네이티브 시작.
  ///
  /// 호출 후 [controller]는 null이 되므로 UI는 [camera2.frames]에서 들어오는
  /// JPEG로 미리보기를 구성해야 한다.
  ///
  /// @return 카메라 open 성공 여부
  Future<bool> startCamera2Recording() async {
    // Flutter camera plugin이 카메라를 잡고 있으면 Camera2에서 open 실패하므로
    // 먼저 plugin controller를 dispose해 HW를 해제한다.
    try {
      await _controller?.dispose();
    } catch (_) {}
    _controller = null;

    return _camera2.start();
  }

  /// 측정 종료 — Camera2 정지하고 저장된 mp4 경로 반환.
  Future<String?> stopCamera2Recording() async {
    return _camera2.stop();
  }

  bool get isCamera2Running => _camera2.isRunning;

  /// 리소스 정리.
  ///
  /// 주의: 이 메서드는 측정 종료 후 `releaseCamera()`에서도 호출되므로 Camera2
  /// 서비스는 stop만 하고 완전 dispose하지 않는다 (`_framesController`가 닫히면
  /// 다음 측정에서 add 실패). 진짜 종료는 [shutdownAll]로 별도 호출.
  Future<void> dispose() async {
    if (_camera2.isRunning) {
      await _camera2.stop();
    }
    await _controller?.dispose();
    _controller = null;
    _selectedCamera = null;
  }

  /// 앱 종료 시 호출. Camera2 서비스까지 완전히 폐기.
  Future<void> shutdownAll() async {
    await dispose();
    await _camera2.dispose();
  }
}
