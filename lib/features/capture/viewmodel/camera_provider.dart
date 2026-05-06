import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../model/camera_service.dart';

/// 카메라 서비스 Provider (앱 전역 단일 인스턴스)
final cameraServiceProvider = Provider<CameraService>((ref) {
  final service = CameraService();
  ref.onDispose(() {
    service.dispose();
  });
  return service;
});
