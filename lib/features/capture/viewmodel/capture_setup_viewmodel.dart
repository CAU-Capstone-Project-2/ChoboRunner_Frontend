import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/tts/tts_provider.dart';

/// 촬영 설정 화면의 모드
enum SetupMode {
  /// 가이드 + 인식 상태 + 버튼들 표시
  setup,

  /// 카운트다운 숫자 표시 (3 → 2 → 1)
  countdown,
}

/// 분석 대상자 기준 카메라 위치.
/// 카메라가 왼쪽이면 러너는 화면에서 우→좌 방향으로 달리고,
/// 오른쪽이면 좌→우 방향으로 달린다.
enum CameraPosition { left, right }

/// 촬영 설정 화면 상태
@immutable
class CaptureSetupState {
  final SetupMode mode;
  final int countdownValue; // 3, 2, 1, 0
  final CameraPosition cameraPosition;

  const CaptureSetupState({
    this.mode = SetupMode.setup,
    this.countdownValue = 0,
    this.cameraPosition = CameraPosition.left,
  });

  CaptureSetupState copyWith({
    SetupMode? mode,
    int? countdownValue,
    CameraPosition? cameraPosition,
  }) {
    return CaptureSetupState(
      mode: mode ?? this.mode,
      countdownValue: countdownValue ?? this.countdownValue,
      cameraPosition: cameraPosition ?? this.cameraPosition,
    );
  }
}

/// 촬영 설정 화면 ViewModel.
///
/// 단일 화면에서 setup → countdown 모드 전환을 관리.
/// 카운트다운 종료 시 화면이 onCountdownComplete 콜백으로
/// 측정 화면으로 이동시킴.
class CaptureSetupViewModel extends Notifier<CaptureSetupState> {
  Timer? _countdownTimer;
  VoidCallback? _onCountdownComplete;

  @override
  CaptureSetupState build() {
    ref.onDispose(() {
      _countdownTimer?.cancel();
    });
    return const CaptureSetupState();
  }

  void reset() {
    _countdownTimer?.cancel();
    _countdownTimer = null;
    _onCountdownComplete = null;
    state = CaptureSetupState(cameraPosition: state.cameraPosition);
  }

  void setCameraPosition(CameraPosition position) {
    state = state.copyWith(cameraPosition: position);
  }

  /// 카운트다운 시작.
  ///
  /// [onComplete]는 카운트다운 0 도달 시 호출됨.
  /// 화면이 이 콜백으로 다음 화면으로 이동시킴.
  void startCountdown({required VoidCallback onComplete}) {
    // 이전 카운트다운이 남아있으면 정리
    _countdownTimer?.cancel();

    _onCountdownComplete = onComplete;
    state = state.copyWith(
      mode: SetupMode.countdown,
      countdownValue: 3,
    );
    _speakCountdown(3);

    _countdownTimer = Timer.periodic(const Duration(seconds: 1), (_) {
      final next = state.countdownValue - 1;
      if (next <= 0) {
        _countdownTimer?.cancel();
        _countdownTimer = null;
        state = state.copyWith(countdownValue: 0);
        _speakStart();
        _onCountdownComplete?.call();
      } else {
        state = state.copyWith(countdownValue: next);
        _speakCountdown(next);
      }
    });
  }

  /// 카운트다운 취소 (setup 모드로 복귀).
  void cancelCountdown() {
    _countdownTimer?.cancel();
    _countdownTimer = null;
    _onCountdownComplete = null;
    // 재생 중인 카운트다운 음성도 함께 중단.
    ref.read(ttsServiceProvider).stop();
    state = const CaptureSetupState();
  }

  void _speakCountdown(int value) {
    // 한국어 TTS는 "3"을 "삼"으로 읽음. 우리말 카운트로 들리도록 한글로 직접 전달.
    const map = {3: '셋', 2: '둘', 1: '하나'};
    final text = map[value];
    if (text == null) return;
    ref.read(ttsServiceProvider).speak(text);
  }

  void _speakStart() {
    ref.read(ttsServiceProvider).speak('시작');
  }
}

/// 촬영 설정 ViewModel Provider
final captureSetupViewModelProvider =
    NotifierProvider<CaptureSetupViewModel, CaptureSetupState>(
  CaptureSetupViewModel.new,
);
