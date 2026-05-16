import 'dart:async';

import 'package:flutter_tts/flutter_tts.dart';

/// TTS 재생 상태
enum TtsStatus {
  idle,
  speaking,
  paused,
  error,
}

/// 앱 전역 TTS 서비스
///
/// - OS 내장 TTS(flutter_tts) 래퍼
/// - 한국어 기본 설정
/// - speak 호출 시 이전 발화가 있으면 중단하고 새로 재생 (queue 안 함)
/// - 상태 스트림 노출
class TtsService {
  TtsService({
    this.defaultLanguage = 'ko-KR',
    this.defaultRate = 0.5,
    this.defaultPitch = 1.0,
    this.defaultVolume = 1.0,
  });

  final String defaultLanguage;
  final double defaultRate;
  final double defaultPitch;
  final double defaultVolume;

  final FlutterTts _tts = FlutterTts();
  final _statusController = StreamController<TtsStatus>.broadcast();

  TtsStatus _status = TtsStatus.idle;
  bool _initialized = false;

  Stream<TtsStatus> get statusStream => _statusController.stream;
  TtsStatus get status => _status;
  bool get isSpeaking => _status == TtsStatus.speaking;

  /// 1회만 호출되는 초기화. main()이나 앱 시작 시 호출.
  Future<void> init() async {
    if (_initialized) return;
    _initialized = true;

    await _tts.setLanguage(defaultLanguage);
    await _tts.setSpeechRate(defaultRate);
    await _tts.setPitch(defaultPitch);
    await _tts.setVolume(defaultVolume);

    // iOS: 다른 오디오와 동시 재생 허용 (러닝 중 음악 같이 듣는 시나리오)
    await _tts.setSharedInstance(true);
    await _tts.setIosAudioCategory(
      IosTextToSpeechAudioCategory.playback,
      [
        IosTextToSpeechAudioCategoryOptions.mixWithOthers,
        IosTextToSpeechAudioCategoryOptions.duckOthers,
      ],
      IosTextToSpeechAudioMode.voicePrompt,
    );

    // Android: speak 호출 시 이전 발화 중단
    await _tts.awaitSpeakCompletion(true);

    _tts.setStartHandler(() => _setStatus(TtsStatus.speaking));
    _tts.setCompletionHandler(() => _setStatus(TtsStatus.idle));
    _tts.setCancelHandler(() => _setStatus(TtsStatus.idle));
    _tts.setPauseHandler(() => _setStatus(TtsStatus.paused));
    _tts.setContinueHandler(() => _setStatus(TtsStatus.speaking));
    _tts.setErrorHandler((msg) {
      // ignore: avoid_print
      print('[TTS] error: $msg');
      _setStatus(TtsStatus.error);
    });
  }

  /// 문장 읽기. 이미 재생 중이면 중단하고 새로 재생.
  Future<void> speak(String text) async {
    if (text.trim().isEmpty) return;
    if (!_initialized) await init();

    if (isSpeaking) {
      await _tts.stop();
    }
    await _tts.speak(text);
  }

  /// 큐에 쌓아 순차 재생 (현재 재생 끝나면 이어서). 짧은 안내 연속 출력용.
  Future<void> enqueue(String text) async {
    if (text.trim().isEmpty) return;
    if (!_initialized) await init();
    await _tts.speak(text);
  }

  Future<void> stop() => _tts.stop();
  Future<void> pause() => _tts.pause();

  Future<void> setLanguage(String code) => _tts.setLanguage(code);
  Future<void> setRate(double rate) => _tts.setSpeechRate(rate);
  Future<void> setPitch(double pitch) => _tts.setPitch(pitch);
  Future<void> setVolume(double volume) => _tts.setVolume(volume);

  /// 사용 가능한 언어 코드 목록 조회 (디버깅용)
  Future<List<String>> getLanguages() async {
    final list = await _tts.getLanguages;
    return list is List ? list.cast<String>() : <String>[];
  }

  Future<void> dispose() async {
    await _tts.stop();
    await _statusController.close();
  }

  void _setStatus(TtsStatus next) {
    if (_status == next) return;
    _status = next;
    _statusController.add(next);
  }
}
