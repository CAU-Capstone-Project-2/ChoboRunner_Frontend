import 'dart:typed_data';

import 'package:camera/camera.dart';

/// 카메라 하드웨어를 감싸는 서비스.
///
/// - 카메라 목록 조회 및 후면 카메라 선택
/// - CameraController 초기화/dispose
/// - 단일 프레임 캡처 (JPEG bytes)
class CameraService {
  CameraController? _controller;
  List<CameraDescription> _availableCameras = const [];

  /// 외부에서 프리뷰 위젯이 사용할 컨트롤러 (초기화 후 non-null)
  CameraController? get controller => _controller;

  bool get isInitialized => _controller?.value.isInitialized ?? false;

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

  /// 카메라 초기화
  ///
  /// 권한이 이미 허용된 상태에서 호출되어야 함.
  /// 권한 처리는 ViewModel 책임.
  Future<void> initialize() async {
    if (_availableCameras.isEmpty) {
      await loadAvailableCameras();
    }

    final camera = _pickBackCamera();
    if (camera == null) {
      throw StateError('사용 가능한 카메라가 없습니다');
    }

    // 기존 컨트롤러 정리
    await _controller?.dispose();

    _controller = CameraController(
      camera,
      ResolutionPreset.medium, // 640x480 정도
      enableAudio: false,
      imageFormatGroup: ImageFormatGroup.jpeg,
    );

    await _controller!.initialize();
  }

  /// 단일 프레임 캡처 -> JPEG bytes 반환
  Future<Uint8List?> captureFrameBytes() async {
    final controller = _controller;
    if (controller == null || !controller.value.isInitialized) {
      return null;
    }
    if (controller.value.isTakingPicture) {
      return null;
    }
    try {
      final XFile file = await controller.takePicture();
      return await file.readAsBytes();
    } catch (_) {
      return null;
    }
  }

  /// 리소스 정리
  Future<void> dispose() async {
    await _controller?.dispose();
    _controller = null;
  }
}
