import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:permission_handler/permission_handler.dart';

import '../../../core/router/app_router.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_typography.dart';
import '../model/capture_websocket_service.dart';
import '../model/feedback_item.dart';
import '../viewmodel/camera_viewmodel.dart';
import '../viewmodel/capture_websocket_viewmodel.dart';

class CaptureMeasuringScreen extends ConsumerStatefulWidget {
  const CaptureMeasuringScreen({super.key});

  @override
  ConsumerState<CaptureMeasuringScreen> createState() =>
      _CaptureMeasuringScreenState();
}

class _CaptureMeasuringScreenState
    extends ConsumerState<CaptureMeasuringScreen> {
  bool _showDebug = false;

  /// 측정이 한 번이라도 시작됐는지. true가 되면 WS 끊김에 관계없이
  /// '러닝 종료' 버튼 유지하고 백그라운드에서 자동 재연결.
  bool _measurementStarted = false;

  Timer? _reconnectTimer;

  static const Duration _reconnectDelay = Duration(seconds: 2);

  CaptureWebSocketViewModel? _wsVm;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _wsVm = ref.read(captureWebSocketViewModelProvider.notifier);
      _wsVm!.resetSession();
      ref
          .read(cameraViewModelProvider.notifier)
          .requestPermissionAndInitialize();
    });
  }

  @override
  void dispose() {
    _reconnectTimer?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final cameraState = ref.watch(cameraViewModelProvider);

    // 카메라 준비 완료 → WS 자동 연결 (최초 1회)
    ref.listen<CameraState>(cameraViewModelProvider, (prev, next) {
      final becameReady = prev?.ready != CameraReadyStatus.ready &&
          next.ready == CameraReadyStatus.ready;
      if (becameReady) _ensureConnect();
    });

    // WS 상태 전이: 자동 캡처 시작 + 자동 재연결 + 서버 종료 감지
    ref.listen<CaptureWebSocketState>(captureWebSocketViewModelProvider,
        (prev, next) {
      // 측정 시작 마크 (한 번만)
      if (!_measurementStarted && next.isCapturing) {
        setState(() => _measurementStarted = true);
      }

      // 서버가 analysis_result를 보내면 자동으로 종료 화면 이동
      if (prev?.finalResult == null && next.finalResult != null) {
        _reconnectTimer?.cancel();
        final elapsed = next.elapsedSec;
        if (mounted) {
          context.go('${AppRoutes.captureFinish}?elapsedSec=$elapsed');
        }
        return;
      }

      final prevStatus = prev?.status;
      final nextStatus = next.status;
      if (prevStatus == nextStatus) return;

      if (nextStatus == ConnectionStatus.connected) {
        _reconnectTimer?.cancel();
        if (!next.isCapturing && !_measurementStarted) {
          ref.read(captureWebSocketViewModelProvider.notifier).startCapture();
        }
      } else if (nextStatus == ConnectionStatus.disconnected ||
          nextStatus == ConnectionStatus.error) {
        if (!next.hasFinalResult) {
          _scheduleReconnect();
        }
      }
    });

    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        title: const Text('실시간 피드백', style: AppTypography.screenTitle),
        backgroundColor: AppColors.background,
        elevation: 0,
        centerTitle: true,
      ),
      body: SafeArea(child: _buildBody(cameraState)),
    );
  }

  void _ensureConnect() {
    if (!mounted) return;
    final wsState = ref.read(captureWebSocketViewModelProvider);
    if (wsState.isConnected || wsState.isConnecting) return;
    ref.read(captureWebSocketViewModelProvider.notifier).connect();
  }

  void _scheduleReconnect() {
    if (!mounted) return;
    _reconnectTimer?.cancel();
    _reconnectTimer = Timer(_reconnectDelay, _ensureConnect);
  }

  Widget _buildBody(CameraState cameraState) {
    if (cameraState.ready == CameraReadyStatus.initializing) {
      return const Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            CircularProgressIndicator(color: AppColors.textPrimary),
            SizedBox(height: 16),
            Text('카메라 준비 중...', style: AppTypography.body),
          ],
        ),
      );
    }

    if (cameraState.ready == CameraReadyStatus.error ||
        cameraState.ready == CameraReadyStatus.idle) {
      return const _CameraErrorView();
    }

    return _MainContent(
      showDebug: _showDebug,
      onToggleDebug: () => setState(() => _showDebug = !_showDebug),
      measurementStarted: _measurementStarted,
    );
  }
}

// ─────────── 카메라 에러/대기 뷰 ───────────

class _CameraErrorView extends ConsumerWidget {
  const _CameraErrorView();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final cameraState = ref.watch(cameraViewModelProvider);
    final cameraVm = ref.read(cameraViewModelProvider.notifier);

    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(
              Icons.videocam_off,
              size: 64,
              color: AppColors.textMuted,
            ),
            const SizedBox(height: 16),
            Text(
              cameraState.errorMessage ?? '카메라가 준비되지 않았습니다',
              textAlign: TextAlign.center,
              style: AppTypography.body,
            ),
            const SizedBox(height: 24),
            if (cameraState.permission ==
                CameraPermissionStatus.permanentlyDenied)
              FilledButton.icon(
                icon: const Icon(Icons.settings),
                label: const Text('설정 열기'),
                style: FilledButton.styleFrom(
                  backgroundColor: AppColors.primaryAction,
                  foregroundColor: AppColors.primaryActionText,
                ),
                onPressed: () async {
                  await openAppSettings();
                },
              )
            else
              FilledButton.icon(
                icon: const Icon(Icons.refresh),
                label: const Text('다시 시도'),
                style: FilledButton.styleFrom(
                  backgroundColor: AppColors.primaryAction,
                  foregroundColor: AppColors.primaryActionText,
                ),
                onPressed: cameraVm.requestPermissionAndInitialize,
              ),
          ],
        ),
      ),
    );
  }
}

// ─────────── 메인 콘텐츠 (정상 흐름) ───────────

class _MainContent extends ConsumerWidget {
  const _MainContent({
    required this.showDebug,
    required this.onToggleDebug,
    required this.measurementStarted,
  });

  final bool showDebug;
  final VoidCallback onToggleDebug;
  final bool measurementStarted;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final wsState = ref.watch(captureWebSocketViewModelProvider);
    final wsVm = ref.read(captureWebSocketViewModelProvider.notifier);
    final cameraVm = ref.read(cameraViewModelProvider.notifier);

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 20),
      child: Column(
        children: [
          // 카메라 영역 (직사각형, 화면 상부 ~55%)
          Expanded(
            flex: 5,
            child: Padding(
              padding: const EdgeInsets.only(top: 8, bottom: 16),
              child: _CameraArea(
                latestJpeg: wsVm.latestJpegNotifier,
              ),
            ),
          ),

          // 사용자 인식 상태 placeholder (단계 B에서 채울 자리)
          _RecognitionStatusRow(wsState: wsState),

          const SizedBox(height: 16),

          // 피드백 메시지 (priority 가장 높은 1개)
          _FeedbackArea(wsState: wsState),

          const SizedBox(height: 20),

          // 러닝 시간 큰 글씨
          _RunningTime(wsState: wsState),

          const SizedBox(height: 20),

          // 메인 액션 버튼 (라임 옐로우)
          _PrimaryAction(
            wsState: wsState,
            wsVm: wsVm,
            cameraVm: cameraVm,
            measurementStarted: measurementStarted,
          ),

          // 디버그 토글
          TextButton.icon(
            icon: Icon(
              showDebug ? Icons.bug_report : Icons.bug_report_outlined,
              size: 14,
              color: AppColors.textMuted,
            ),
            label: Text(
              showDebug ? '디버그 숨기기' : '디버그',
              style: AppTypography.debugLabel,
            ),
            onPressed: onToggleDebug,
          ),

          // 디버그 영역
          if (showDebug)
            _DebugPanel(
              wsState: wsState,
              wsVm: wsVm,
              cameraVm: cameraVm,
            ),

          const SizedBox(height: 8),
        ],
      ),
    );
  }
}

// ─────────── 카메라 영역 ───────────

class _CameraArea extends StatelessWidget {
  const _CameraArea({required this.latestJpeg});
  final ValueListenable<Uint8List?> latestJpeg;

  @override
  Widget build(BuildContext context) {
    // 네이티브 Camera2가 sensorOrientation 적용해 회전한 JPEG를 그대로 띄움.
    // 첫 프레임 도착 전(카메라 open ~ 첫 인코딩까지 ~1초)은 로딩 표시.
    return ClipRRect(
      borderRadius: BorderRadius.circular(16),
      child: ValueListenableBuilder<Uint8List?>(
        valueListenable: latestJpeg,
        builder: (context, jpeg, _) {
          return Stack(
            fit: StackFit.expand,
            children: [
              Container(color: AppColors.cameraPlaceholder),
              if (jpeg != null)
                Image.memory(
                  jpeg,
                  gaplessPlayback: true,
                  fit: BoxFit.cover,
                  width: double.infinity,
                  height: double.infinity,
                )
              else
                const Center(
                  child: CircularProgressIndicator(
                    color: AppColors.textPrimary,
                  ),
                ),
            ],
          );
        },
      ),
    );
  }
}

// ─────────── 사용자 인식 상태 (단계 B에서 채움) ───────────

class _RecognitionStatusRow extends StatelessWidget {
  const _RecognitionStatusRow({required this.wsState});
  final CaptureWebSocketState wsState;

  @override
  Widget build(BuildContext context) {
    final (color, label) = _resolveStatus(wsState);

    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        Container(
          width: 10,
          height: 10,
          decoration: BoxDecoration(
            color: color,
            shape: BoxShape.circle,
          ),
        ),
        const SizedBox(width: 8),
        Text(label, style: AppTypography.label),
      ],
    );
  }

  (Color, String) _resolveStatus(CaptureWebSocketState s) {
    if (!s.isConnected) {
      return (AppColors.statusConnecting, '서버에 연결하는 중입니다');
    }
    if (!s.isCapturing) {
      return (AppColors.statusPending, '캡처 준비 중입니다');
    }
    if (s.lastPoseDetected) {
      return (AppColors.statusOk, '사용자가 인식되었습니다');
    }
    return (AppColors.statusError, '사용자가 인식되지 않았습니다');
  }
}

// ─────────── 피드백 메시지 영역 ───────────

class _FeedbackArea extends StatelessWidget {
  const _FeedbackArea({required this.wsState});
  final CaptureWebSocketState wsState;

  @override
  Widget build(BuildContext context) {
    final item = wsState.latestFeedbackItem;

    if (item == null) {
      return SizedBox(
        height: 40,
        child: Center(
          child: Text(
            wsState.isCapturing
                ? '피드백 메시지 대기 중...'
                : '러닝을 시작하면 피드백이 표시됩니다',
            style: AppTypography.bodyMuted,
          ),
        ),
      );
    }

    return _FeedbackText(item: item);
  }
}

class _FeedbackText extends StatelessWidget {
  const _FeedbackText({required this.item});
  final FeedbackItem item;

  @override
  Widget build(BuildContext context) {
    final color = _colorForCategory(item.category);
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Icon(_iconForCategory(item.category), color: color, size: 16),
        const SizedBox(width: 8),
        Expanded(
          child: Text(
            item.displayTextWithPrefix,
            style: AppTypography.body,
            textAlign: TextAlign.center,
          ),
        ),
      ],
    );
  }

  Color _colorForCategory(FeedbackCategory category) {
    switch (category) {
      case FeedbackCategory.postureWarning:
        return AppColors.feedbackWarning;
      case FeedbackCategory.postureInfo:
        return AppColors.feedbackInfo;
      case FeedbackCategory.systemInfo:
      case FeedbackCategory.unknown:
        return AppColors.feedbackSystem;
    }
  }

  IconData _iconForCategory(FeedbackCategory category) {
    switch (category) {
      case FeedbackCategory.postureWarning:
        return Icons.warning_amber_rounded;
      case FeedbackCategory.postureInfo:
        return Icons.info_outline;
      case FeedbackCategory.systemInfo:
      case FeedbackCategory.unknown:
        return Icons.notifications_none;
    }
  }
}

// ─────────── 러닝 시간 ───────────

class _RunningTime extends StatelessWidget {
  const _RunningTime({required this.wsState});
  final CaptureWebSocketState wsState;

  @override
  Widget build(BuildContext context) {
    final sec = wsState.elapsedSec;
    final mm = (sec ~/ 60).toString().padLeft(2, '0');
    final ss = (sec % 60).toString().padLeft(2, '0');

    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      crossAxisAlignment: CrossAxisAlignment.baseline,
      textBaseline: TextBaseline.alphabetic,
      children: [
        const Text('러닝 시간', style: AppTypography.displayMedium),
        const SizedBox(width: 12),
        Text('$mm:$ss', style: AppTypography.displayLarge),
      ],
    );
  }
}

// ─────────── 메인 액션 버튼 ───────────

class _PrimaryAction extends StatelessWidget {
  const _PrimaryAction({
    required this.wsState,
    required this.wsVm,
    required this.cameraVm,
    required this.measurementStarted,
  });

  final CaptureWebSocketState wsState;
  final CaptureWebSocketViewModel wsVm;
  final CameraViewModel cameraVm;
  final bool measurementStarted;

  @override
  Widget build(BuildContext context) {
    // 측정이 한 번이라도 시작된 이후엔 WS 끊김에 무관하게 '러닝 종료' 유지.
    // 끊김 처리는 화면 상위에서 자동 재연결로 처리 — UI는 영향 받지 않음.
    if (measurementStarted) {
      return _wideButton(
        label: '러닝 종료',
        onPressed: () async {
          final elapsed = wsState.elapsedSec;
          await wsVm.stopCapture();
          wsVm.sendStop();
          if (context.mounted) {
            context.go('${AppRoutes.captureFinish}?elapsedSec=$elapsed');
          }
        },
      );
    }

    // 최초 진입: 연결/캡처 시작 대기 중.
    return _wideButton(label: '준비 중...', onPressed: null);
  }

  Widget _wideButton({required String label, VoidCallback? onPressed}) {
    return SizedBox(
      width: double.infinity,
      height: 52,
      child: FilledButton(
        style: FilledButton.styleFrom(
          backgroundColor: AppColors.primaryAction,
          foregroundColor: AppColors.primaryActionText,
          disabledBackgroundColor: AppColors.surface,
          disabledForegroundColor: AppColors.textMuted,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(26),
          ),
        ),
        onPressed: onPressed,
        child: Text(label, style: AppTypography.primaryButton),
      ),
    );
  }
}

// ─────────── 디버그 패널 ───────────

class _DebugPanel extends StatelessWidget {
  const _DebugPanel({
    required this.wsState,
    required this.wsVm,
    required this.cameraVm,
  });

  final CaptureWebSocketState wsState;
  final CaptureWebSocketViewModel wsVm;
  final CameraViewModel cameraVm;

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(top: 4),
      padding: const EdgeInsets.all(10),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(8),
      ),
      child: Column(
        children: [
          // 연결 상태
          Row(
            children: [
              const Text('연결: ', style: AppTypography.debugLabel),
              Text(
                _connText(wsState.status),
                style: AppTypography.debugValue.copyWith(fontSize: 12),
              ),
              if (wsState.latestError != null) ...[
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    'err: ${wsState.latestError!.errorCode}',
                    style: AppTypography.debugLabel.copyWith(
                      color: AppColors.statusError,
                    ),
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
              ],
            ],
          ),
          const SizedBox(height: 8),
          // 통계
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceAround,
            children: [
              _DebugStat(label: 'progress', value: wsState.progressCount.toString()),
              _DebugStat(label: 'frame_inf', value: wsState.frameInferenceCount.toString()),
              _DebugStat(label: 'sent', value: wsState.sentCount.toString()),
              _DebugStat(label: 'dropped', value: wsState.droppedCount.toString()),
            ],
          ),
          const SizedBox(height: 6),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceAround,
            children: [
              _DebugStat(
                label: 'fps',
                value: wsState.sendFps.toStringAsFixed(1),
              ),
              _DebugStat(
                label: 'errors',
                value: wsState.captureErrorCount.toString(),
              ),
            ],
          ),
          const SizedBox(height: 8),
          // 디버그 액션
          Row(
            children: [
              Expanded(
                child: OutlinedButton(
                  onPressed: wsState.isConnected
                      ? () {
                          final dummy = Uint8List.fromList(List.filled(64, 0));
                          wsVm.sendFrame(dummy, tsMs: 0);
                        }
                      : null,
                  child: const Text(
                    '더미 전송',
                    style: AppTypography.debugLabel,
                  ),
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: OutlinedButton(
                  onPressed: wsVm.disconnect,
                  child: const Text(
                    '연결 종료',
                    style: AppTypography.debugLabel,
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  String _connText(ConnectionStatus s) {
    switch (s) {
      case ConnectionStatus.connected:
        return '연결됨';
      case ConnectionStatus.connecting:
        return '연결 중';
      case ConnectionStatus.disconnected:
        return '끊김';
      case ConnectionStatus.error:
        return '오류';
    }
  }
}

class _DebugStat extends StatelessWidget {
  const _DebugStat({required this.label, required this.value});
  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Text(label, style: AppTypography.debugLabel),
        Text(value, style: AppTypography.debugValue),
      ],
    );
  }
}
