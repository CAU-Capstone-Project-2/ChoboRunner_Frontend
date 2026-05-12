import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

/// 촬영 설정 화면의 모드
enum SetupMode {
  /// 가이드 + 인식 상태 + 버튼들 표시
  setup,

  /// 카운트다운 숫자 표시 (3 → 2 → 1)
  countdown,
}

/// 촬영 설정 화면 상태
@immutable
class CaptureSetupState {
  final SetupMode mode;
  final int countdownValue; // 3, 2, 1, 0

  const CaptureSetupState({
    this.mode = SetupMode.setup,
    this.countdownValue = 0,
  });

  CaptureSetupState copyWith({
    SetupMode? mode,
    int? countdownValue,
  }) {
    return CaptureSetupState(
      mode: mode ?? this.mode,
      countdownValue: countdownValue ?? this.countdownValue,
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

    _countdownTimer = Timer.periodic(const Duration(seconds: 1), (_) {
      final next = state.countdownValue - 1;
      if (next <= 0) {
        _countdownTimer?.cancel();
        _countdownTimer = null;
        state = state.copyWith(countdownValue: 0);
        _onCountdownComplete?.call();
      } else {
        state = state.copyWith(countdownValue: next);
      }
    });
  }

  /// 카운트다운 취소 (setup 모드로 복귀).
  void cancelCountdown() {
    _countdownTimer?.cancel();
    _countdownTimer = null;
    _onCountdownComplete = null;
    state = const CaptureSetupState();
  }
}

/// 촬영 설정 ViewModel Provider
final captureSetupViewModelProvider =
    NotifierProvider<CaptureSetupViewModel, CaptureSetupState>(
  CaptureSetupViewModel.new,
);
