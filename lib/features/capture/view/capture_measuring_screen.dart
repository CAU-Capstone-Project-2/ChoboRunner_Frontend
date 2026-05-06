import 'dart:typed_data';

import 'package:camera/camera.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:permission_handler/permission_handler.dart';

import '../model/capture_websocket_service.dart';
import '../model/feedback_message.dart';
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
  @override
  void initState() {
    super.initState();
    // 첫 프레임 그려진 후 카메라 권한 요청/초기화 시작
    WidgetsBinding.instance.addPostFrameCallback((_) {
      ref
          .read(cameraViewModelProvider.notifier)
          .requestPermissionAndInitialize();
    });
  }

  @override
  void dispose() {
    // 화면 이탈 시 WebSocket 연결 정리
    // (카메라 서비스는 Provider가 전역 관리하므로 여기서 dispose 안 함)
    ref.read(captureWebSocketViewModelProvider.notifier).disconnect();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final cameraState = ref.watch(cameraViewModelProvider);

    return Scaffold(
      backgroundColor: Colors.black,
      appBar: AppBar(
        title: const Text('측정 (WebSocket + Camera)'),
        backgroundColor: Colors.black,
        foregroundColor: Colors.white,
      ),
      body: SafeArea(child: _buildBody(cameraState)),
    );
  }

  Widget _buildBody(CameraState cameraState) {
    // 카메라가 준비되기 전에는 상태별 분기 표시
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
      return _CameraErrorView(state: cameraState);
    }

    // 준비 완료: 카메라 프리뷰 + 정보 오버레이
    return _CameraOverlayView();
  }
}

// ─────────── 카메라 에러/대기 뷰 ───────────

class _CameraErrorView extends ConsumerWidget {
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
            const Icon(Icons.videocam_off,
                size: 64, color: Colors.white54),
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

  const _CameraErrorView({required CameraState state});
}

// ─────────── 카메라 프리뷰 + 정보 오버레이 ───────────

class _CameraOverlayView extends ConsumerWidget {
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

        // 상단: 연결 상태 + 통계
        Positioned(
          top: 12,
          left: 12,
          right: 12,
          child: Column(
            children: [
              _OverlayBox(
                child: _ConnectionStatusBadge(status: wsState.status),
              ),
              const SizedBox(height: 8),
              _OverlayBox(
                child: Row(
                  children: [
                    Expanded(
                      child: _statTile('수신', wsState.receivedCount.toString()),
                    ),
                    Expanded(
                      child: _statTile('에러', wsState.errorCount.toString()),
                    ),
                  ],
                ),
              ),
              if (wsState.lastError != null) ...[
                const SizedBox(height: 8),
                _OverlayBox(
                  background: Colors.red.withValues(alpha: 0.7),
                  child: Row(
                    children: [
                      const Icon(Icons.error_outline, color: Colors.white),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          wsState.lastError!,
                          style: const TextStyle(color: Colors.white),
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ],
          ),
        ),

        // 중간: 최근 분석 결과 (있을 때만)
        if (wsState.latestMessage?.result != null)
          Align(
            alignment: Alignment.center,
            child: _OverlayBox(
              child: _LatestMetricsContent(message: wsState.latestMessage!),
            ),
          ),

        // 하단: 액션 버튼들
        Positioned(
          left: 12,
          right: 12,
          bottom: 12,
          child: _OverlayBox(
            child: Column(
              children: [
                SizedBox(
                  width: double.infinity,
                  child: FilledButton.icon(
                    icon: const Icon(Icons.link),
                    label: Text(
                      wsState.isConnecting ? '연결 중...' : '연결 시작',
                    ),
                    onPressed: wsState.isConnected || wsState.isConnecting
                        ? null
                        : wsVm.connect,
                  ),
                ),
                const SizedBox(height: 8),
                SizedBox(
                  width: double.infinity,
                  child: FilledButton.icon(
                    icon: const Icon(Icons.camera),
                    label: const Text('카메라 캡처 + 전송'),
                    onPressed: wsState.isConnected
                        ? () async {
                            final bytes = await cameraVm.captureFrame();
                            if (bytes != null) {
                              wsVm.sendFrame(bytes);
                            }
                          }
                        : null,
                  ),
                ),
                const SizedBox(height: 8),
                SizedBox(
                  width: double.infinity,
                  child: OutlinedButton.icon(
                    icon: const Icon(Icons.send),
                    label: const Text('더미 프레임 전송 (테스트용)'),
                    onPressed: wsState.isConnected
                        ? () {
                            final dummy =
                                Uint8List.fromList(List.filled(64, 0));
                            wsVm.sendFrame(dummy);
                          }
                        : null,
                  ),
                ),
                const SizedBox(height: 8),
                SizedBox(
                  width: double.infinity,
                  child: TextButton.icon(
                    icon: const Icon(Icons.link_off, color: Colors.white70),
                    label: const Text(
                      '연결 종료',
                      style: TextStyle(color: Colors.white70),
                    ),
                    onPressed:
                        wsState.isConnected ? wsVm.disconnect : null,
                  ),
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }

  Widget _statTile(String label, String value) {
    return Column(
      children: [
        Text(label, style: const TextStyle(color: Colors.white70)),
        const SizedBox(height: 2),
        Text(
          value,
          style: const TextStyle(
            fontSize: 20,
            fontWeight: FontWeight.bold,
            color: Colors.white,
          ),
        ),
      ],
    );
  }
}

// ─────────── 공용 위젯 ───────────

class _OverlayBox extends StatelessWidget {
  const _OverlayBox({required this.child, this.background});
  final Widget child;
  final Color? background;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: background ?? Colors.black.withValues(alpha: 0.6),
        borderRadius: BorderRadius.circular(12),
      ),
      child: child,
    );
  }
}

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

    return Row(
      children: [
        Icon(Icons.circle, color: color, size: 12),
        const SizedBox(width: 8),
        Text(
          'WebSocket: $label',
          style: TextStyle(color: color, fontWeight: FontWeight.bold),
        ),
      ],
    );
  }
}

class _LatestMetricsContent extends StatelessWidget {
  const _LatestMetricsContent({required this.message});
  final FeedbackMessage message;

  @override
  Widget build(BuildContext context) {
    final result = message.result;
    if (result == null) return const SizedBox.shrink();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: [
        const Text(
          '최근 분석 결과',
          style: TextStyle(
            fontSize: 14,
            fontWeight: FontWeight.bold,
            color: Colors.white70,
          ),
        ),
        const SizedBox(height: 6),
        _row('자세 인식', result.poseDetected ? '성공' : '실패'),
        _row('측면', result.stanceSide ?? '-'),
        _row('관절', '${result.visibleLandmarks ?? 0}개'),
        const SizedBox(height: 4),
        _row('상체 기울기', _fmtDeg(result.metrics.trunkLeanDeg)),
        _row('무릎 (좌)', _fmtDeg(result.metrics.initialKneeFlexionLeftDeg)),
        _row('무릎 (우)', _fmtDeg(result.metrics.initialKneeFlexionRightDeg)),
      ],
    );
  }

  Widget _row(String label, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 1),
      child: Row(
        children: [
          SizedBox(
            width: 90,
            child: Text(
              label,
              style: const TextStyle(color: Colors.white70, fontSize: 13),
            ),
          ),
          Text(
            value,
            style: const TextStyle(
              color: Colors.white,
              fontSize: 13,
              fontWeight: FontWeight.w600,
            ),
          ),
        ],
      ),
    );
  }

  String _fmtDeg(double? v) {
    if (v == null) return '-';
    return '${v.toStringAsFixed(2)}°';
  }
}
