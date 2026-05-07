import 'dart:typed_data';

import 'package:camera/camera.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:permission_handler/permission_handler.dart';

import '../model/analysis_result_message.dart';
import '../model/capture_websocket_service.dart';
import '../model/feedback_item.dart';
import '../model/server_message.dart';
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

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      ref
          .read(cameraViewModelProvider.notifier)
          .requestPermissionAndInitialize();
    });
  }

  @override
  void dispose() {
    ref.read(captureWebSocketViewModelProvider.notifier).disconnect();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final cameraState = ref.watch(cameraViewModelProvider);

    return Scaffold(
      backgroundColor: Colors.black,
      appBar: AppBar(
        title: const Text('측정'),
        backgroundColor: Colors.black,
        foregroundColor: Colors.white,
      ),
      body: SafeArea(child: _buildBody(cameraState)),
    );
  }

  Widget _buildBody(CameraState cameraState) {
    if (cameraState.ready == CameraReadyStatus.initializing) {
      return const Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            CircularProgressIndicator(color: Colors.white),
            SizedBox(height: 16),
            Text('카메라 준비 중...', style: TextStyle(color: Colors.white)),
          ],
        ),
      );
    }

    if (cameraState.ready == CameraReadyStatus.error ||
        cameraState.ready == CameraReadyStatus.idle) {
      return const _CameraErrorView();
    }

    return _CameraOverlayView(
      showDebug: _showDebug,
      onToggleDebug: () => setState(() => _showDebug = !_showDebug),
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
            const Icon(Icons.videocam_off, size: 64, color: Colors.white54),
            const SizedBox(height: 16),
            Text(
              cameraState.errorMessage ?? '카메라가 준비되지 않았습니다',
              textAlign: TextAlign.center,
              style: const TextStyle(color: Colors.white, fontSize: 16),
            ),
            const SizedBox(height: 24),
            if (cameraState.permission ==
                CameraPermissionStatus.permanentlyDenied)
              FilledButton.icon(
                icon: const Icon(Icons.settings),
                label: const Text('설정 열기'),
                onPressed: () async {
                  await openAppSettings();
                },
              )
            else
              FilledButton.icon(
                icon: const Icon(Icons.refresh),
                label: const Text('다시 시도'),
                onPressed: cameraVm.requestPermissionAndInitialize,
              ),
          ],
        ),
      ),
    );
  }
}

// ─────────── 카메라 프리뷰 + 정보 오버레이 ───────────

class _CameraOverlayView extends ConsumerWidget {
  const _CameraOverlayView({
    required this.showDebug,
    required this.onToggleDebug,
  });

  final bool showDebug;
  final VoidCallback onToggleDebug;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final wsState = ref.watch(captureWebSocketViewModelProvider);
    final wsVm = ref.read(captureWebSocketViewModelProvider.notifier);
    final cameraVm = ref.read(cameraViewModelProvider.notifier);
    final controller = cameraVm.service.controller;

    if (controller == null || !controller.value.isInitialized) {
      return const Center(
        child: CircularProgressIndicator(color: Colors.white),
      );
    }

    return Stack(
      fit: StackFit.expand,
      children: [
        // 배경: 카메라 프리뷰
        Center(
          child: AspectRatio(
            aspectRatio: controller.value.aspectRatio,
            child: CameraPreview(controller),
          ),
        ),

        // 상단 좌측: 작은 연결 배지
        Positioned(
          top: 12,
          left: 12,
          child: _ConnectionStatusBadge(status: wsState.status),
        ),

        // 시스템 에러 배너 (있을 때만)
        if (wsState.latestError != null)
          Positioned(
            top: 56,
            left: 12,
            right: 12,
            child: _SystemErrorBanner(error: wsState.latestError!),
          ),

        // 중앙: 피드백 카드 (priority 가장 높은 1개만)
        if (wsState.latestProgress?.topPriorityItem != null)
          Positioned(
            left: 16,
            right: 16,
            top: 100,
            child: _FeedbackCard(item: wsState.latestProgress!.topPriorityItem!),
          ),

        // 최종 결과 도착 시 간단한 알림 (정식 화면은 추후)
        if (wsState.hasFinalResult)
          Align(
            alignment: Alignment.center,
            child: _FinalResultPlaceholder(result: wsState.finalResult!),
          ),

        // 하단: 액션 버튼 + 디버그 토글
        Positioned(
          left: 12,
          right: 12,
          bottom: 12,
          child: _BottomActionPanel(
            isConnected: wsState.isConnected,
            isConnecting: wsState.isConnecting,
            isCapturing: wsState.isCapturing,
            onConnect: wsVm.connect,
            onDisconnect: wsVm.disconnect,
            onStartCapture: wsVm.startCapture,
            onStopCapture: () {
              wsVm.stopCapture();
              wsVm.sendStop();
            },
            onCaptureAndSend: () async {
              final bytes = await cameraVm.captureFrame();
              if (bytes != null) {
                wsVm.sendFrame(bytes);
              }
            },
            showDebug: showDebug,
            onToggleDebug: onToggleDebug,
            progressCount: wsState.progressCount,
            frameInferenceCount: wsState.frameInferenceCount,
            sentCount: wsState.sentCount,
            droppedCount: wsState.droppedCount,
            captureErrorCount: wsState.captureErrorCount,
            sendFps: wsState.sendFps,
            onSendDummy: () {
              final dummy = Uint8List.fromList(List.filled(64, 0));
              wsVm.sendFrame(dummy);
            },
          ),
        ),
      ],
    );
  }
}

// ─────────── 연결 상태 작은 배지 ───────────

class _ConnectionStatusBadge extends StatelessWidget {
  const _ConnectionStatusBadge({required this.status});
  final ConnectionStatus status;

  @override
  Widget build(BuildContext context) {
    final (label, color) = switch (status) {
      ConnectionStatus.connected => ('연결됨', Colors.greenAccent),
      ConnectionStatus.connecting => ('연결 중...', Colors.orangeAccent),
      ConnectionStatus.disconnected => ('연결 끊김', Colors.white70),
      ConnectionStatus.error => ('오류', Colors.redAccent),
    };

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: Colors.black.withValues(alpha: 0.55),
        borderRadius: BorderRadius.circular(20),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(Icons.circle, color: color, size: 8),
          const SizedBox(width: 6),
          Text(
            label,
            style: TextStyle(color: color, fontSize: 12, fontWeight: FontWeight.w600),
          ),
        ],
      ),
    );
  }
}

// ─────────── 시스템 에러 배너 ───────────

class _SystemErrorBanner extends StatelessWidget {
  const _SystemErrorBanner({required this.error});
  final ErrorServerMessage error;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.red.withValues(alpha: 0.85),
        borderRadius: BorderRadius.circular(10),
      ),
      child: Row(
        children: [
          const Icon(Icons.error_outline, color: Colors.white),
          const SizedBox(width: 8),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  '시스템 오류',
                  style: const TextStyle(
                    color: Colors.white,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                Text(
                  error.errorDetail ?? error.errorCode,
                  style: const TextStyle(color: Colors.white, fontSize: 12),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

// ─────────── 피드백 카드 ───────────

class _FeedbackCard extends StatelessWidget {
  const _FeedbackCard({required this.item});
  final FeedbackItem item;

  @override
  Widget build(BuildContext context) {
    final (color, icon) = _styleForCategory(item.category);

    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.black.withValues(alpha: 0.6),
        borderRadius: BorderRadius.circular(10),
        border: Border(left: BorderSide(color: color, width: 4)),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, color: color, size: 18),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              item.displayTextWithPrefix,
              style: const TextStyle(
                color: Colors.white,
                fontSize: 13,
                height: 1.4,
              ),
            ),
          ),
        ],
      ),
    );
  }

  (Color, IconData) _styleForCategory(FeedbackCategory category) {
    switch (category) {
      case FeedbackCategory.postureWarning:
        return (Colors.amberAccent, Icons.warning_amber_rounded);
      case FeedbackCategory.postureInfo:
        return (Colors.lightBlueAccent, Icons.info_outline);
      case FeedbackCategory.systemInfo:
        return (Colors.white70, Icons.notifications_none);
      case FeedbackCategory.unknown:
        return (Colors.white70, Icons.help_outline);
    }
  }
}

// ─────────── 최종 결과 도착 알림 (임시) ───────────

class _FinalResultPlaceholder extends StatelessWidget {
  const _FinalResultPlaceholder({required this.result});
  final AnalysisResultMessage result;

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.all(20),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.green.withValues(alpha: 0.85),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Row(
            children: [
              Icon(Icons.check_circle, color: Colors.white),
              SizedBox(width: 8),
              Text(
                '최종 분석 결과 도착',
                style: TextStyle(
                  color: Colors.white,
                  fontWeight: FontWeight.bold,
                  fontSize: 16,
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Text(
            'status: ${result.status.name}',
            style: const TextStyle(color: Colors.white),
          ),
          if (result.message != null) ...[
            const SizedBox(height: 4),
            Text(
              result.message!,
              style: const TextStyle(color: Colors.white, fontSize: 13),
            ),
          ],
          const SizedBox(height: 8),
          const Text(
            '※ 정식 분석 리포트 화면은 추후 별도 구현 예정',
            style: TextStyle(color: Colors.white70, fontSize: 11),
          ),
        ],
      ),
    );
  }
}

// ─────────── 하단 액션 패널 ───────────

class _BottomActionPanel extends StatelessWidget {
  const _BottomActionPanel({
    required this.isConnected,
    required this.isConnecting,
    required this.isCapturing,
    required this.onConnect,
    required this.onDisconnect,
    required this.onStartCapture,
    required this.onStopCapture,
    required this.onCaptureAndSend,
    required this.showDebug,
    required this.onToggleDebug,
    required this.progressCount,
    required this.frameInferenceCount,
    required this.sentCount,
    required this.droppedCount,
    required this.captureErrorCount,
    required this.sendFps,
    required this.onSendDummy,
  });

  final bool isConnected;
  final bool isConnecting;
  final bool isCapturing;
  final VoidCallback onConnect;
  final VoidCallback onDisconnect;
  final VoidCallback onStartCapture;
  final VoidCallback onStopCapture;
  final VoidCallback onCaptureAndSend;
  final bool showDebug;
  final VoidCallback onToggleDebug;
  final int progressCount;
  final int frameInferenceCount;
  final int sentCount;
  final int droppedCount;
  final int captureErrorCount;
  final double sendFps;
  final VoidCallback onSendDummy;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.black.withValues(alpha: 0.7),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          // 메인 액션 버튼
          if (!isConnected)
            SizedBox(
              width: double.infinity,
              child: FilledButton.icon(
                icon: const Icon(Icons.link),
                label: Text(isConnecting ? '연결 중...' : '연결 시작'),
                onPressed: isConnecting ? null : onConnect,
              ),
            )
          else if (!isCapturing) ...[
            SizedBox(
              width: double.infinity,
              child: FilledButton.icon(
                icon: const Icon(Icons.directions_run),
                label: const Text('러닝 시작'),
                style: FilledButton.styleFrom(
                  backgroundColor: Colors.green,
                ),
                onPressed: onStartCapture,
              ),
            ),
            const SizedBox(height: 8),
            SizedBox(
              width: double.infinity,
              child: OutlinedButton.icon(
                icon: const Icon(Icons.link_off, color: Colors.white70),
                label: const Text(
                  '연결 종료',
                  style: TextStyle(color: Colors.white70),
                ),
                onPressed: onDisconnect,
              ),
            ),
          ] else ...[
            // 측정 중: 캡처 통계 미니 표시 + 정지 버튼
            Padding(
              padding: const EdgeInsets.only(bottom: 8),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceAround,
                children: [
                  _MiniStat(label: '전송', value: sentCount.toString()),
                  _MiniStat(label: 'FPS', value: sendFps.toStringAsFixed(1)),
                  _MiniStat(label: '드롭', value: droppedCount.toString()),
                  _MiniStat(
                    label: '오류',
                    value: captureErrorCount.toString(),
                  ),
                ],
              ),
            ),
            SizedBox(
              width: double.infinity,
              child: FilledButton.icon(
                icon: const Icon(Icons.stop),
                label: const Text('러닝 정지'),
                style: FilledButton.styleFrom(
                  backgroundColor: Colors.red,
                ),
                onPressed: onStopCapture,
              ),
            ),
          ],

          // 디버그 토글
          const SizedBox(height: 4),
          TextButton.icon(
            icon: Icon(
              showDebug ? Icons.bug_report : Icons.bug_report_outlined,
              size: 16,
              color: Colors.white54,
            ),
            label: Text(
              showDebug ? '디버그 숨기기' : '디버그 보기',
              style: const TextStyle(color: Colors.white54, fontSize: 12),
            ),
            onPressed: onToggleDebug,
          ),

          // 디버그 영역
          if (showDebug) ...[
            const Divider(color: Colors.white24),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 4),
              child: Column(
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceAround,
                    children: [
                      _DebugStat(
                        label: 'progress',
                        value: progressCount.toString(),
                      ),
                      _DebugStat(
                        label: 'frame_inf',
                        value: frameInferenceCount.toString(),
                      ),
                      _DebugStat(label: 'sent', value: sentCount.toString()),
                      _DebugStat(
                        label: 'dropped',
                        value: droppedCount.toString(),
                      ),
                    ],
                  ),
                  const SizedBox(height: 6),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceAround,
                    children: [
                      _DebugStat(label: 'fps', value: sendFps.toStringAsFixed(1)),
                      _DebugStat(
                        label: 'errors',
                        value: captureErrorCount.toString(),
                      ),
                    ],
                  ),
                ],
              ),
            ),
            const SizedBox(height: 4),
            // 수동 캡처 (진단용)
            SizedBox(
              width: double.infinity,
              child: TextButton.icon(
                icon: const Icon(
                  Icons.camera,
                  size: 16,
                  color: Colors.white54,
                ),
                label: const Text(
                  '수동 캡처 1회 (진단용)',
                  style: TextStyle(color: Colors.white54, fontSize: 12),
                ),
                onPressed: isConnected ? onCaptureAndSend : null,
              ),
            ),
            SizedBox(
              width: double.infinity,
              child: TextButton.icon(
                icon: const Icon(Icons.send, size: 16, color: Colors.white54),
                label: const Text(
                  '더미 프레임 전송 (테스트)',
                  style: TextStyle(color: Colors.white54, fontSize: 12),
                ),
                onPressed: isConnected ? onSendDummy : null,
              ),
            ),
          ],
        ],
      ),
    );
  }
}

class _MiniStat extends StatelessWidget {
  const _MiniStat({required this.label, required this.value});
  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Text(
          label,
          style: const TextStyle(color: Colors.white54, fontSize: 11),
        ),
        Text(
          value,
          style: const TextStyle(
            color: Colors.white,
            fontSize: 16,
            fontWeight: FontWeight.bold,
          ),
        ),
      ],
    );
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
        Text(
          label,
          style: const TextStyle(color: Colors.white38, fontSize: 10),
        ),
        Text(
          value,
          style: const TextStyle(
            color: Colors.white,
            fontSize: 14,
            fontWeight: FontWeight.bold,
          ),
        ),
      ],
    );
  }
}
