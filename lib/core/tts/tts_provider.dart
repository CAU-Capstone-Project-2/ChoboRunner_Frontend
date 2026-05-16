import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'tts_service.dart';

/// 앱 전역 TTS 서비스 Provider
///
/// 사용 예시:
///   final tts = ref.read(ttsServiceProvider);
///   await tts.speak('5초 후 측정을 시작합니다');
///
/// 초기화는 [ttsInitProvider]를 watch하거나, 앱 시작 시 1회 service.init() 호출.
final ttsServiceProvider = Provider<TtsService>((ref) {
  final service = TtsService();

  ref.onDispose(() {
    service.dispose();
  });

  return service;
});

/// TTS 초기화 결과 Provider
///
/// 위젯 트리에서 한 번이라도 watch되면 초기화가 트리거됨.
/// 보통 앱 루트에서 watch하거나, main()에서 직접 init() 호출.
final ttsInitProvider = FutureProvider<void>((ref) async {
  final service = ref.watch(ttsServiceProvider);
  await service.init();
});
