import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/background/overlay_upload_task.dart';
import '../../../core/tts/tts_provider.dart';
import '../../../core/tts/tts_service.dart';
import '../../auth/viewmodel/auth_viewmodel.dart';
import '../viewmodel/capture_setup_viewmodel.dart';
import '../model/analysis_progress_message.dart';
import '../model/analysis_result_message.dart';
import '../model/camera_service.dart';
import '../model/capture_loop_controller.dart';
import '../model/capture_websocket_service.dart';
import '../model/feedback_item.dart';
import '../model/run_session.dart';
import '../model/run_session_api_service.dart';
import '../model/server_message.dart';
import 'camera_provider.dart';
import 'capture_websocket_provider.dart';

/// 오버레이 영상 업로드 상태
enum OverlayUploadStatus {
  idle,
  uploading,
  done,
  error,
}

/// 측정 화면이 watch할 WebSocket 상태
class CaptureWebSocketState {
  /// WebSocket 연결 상태
  final ConnectionStatus status;

  /// 측정 중 진행 상태 (가장 최근 analysis_progress)
  final AnalysisProgressMessage? latestProgress;

  /// 최종 누적 결과 (analysis_result)
  /// 측정 종료 후 1회 도착
  final AnalysisResultMessage? finalResult;

  /// 시스템 에러 (가장 최근 error 메시지)
  final ErrorServerMessage? latestError;

  /// analysis_progress 누적 수신 카운트
  final int progressCount;

  /// frame_inference 누적 수신 카운트 (디버그용)
  final int frameInferenceCount;

  /// 캡처 루프 동작 중 여부
  final bool isCapturing;

  /// 전송된 프레임 수
  final int sentCount;

  /// 백프레셔로 드롭된 프레임 수
  final int droppedCount;

  /// 캡처/송신 실패 수
  final int captureErrorCount;

  /// 최근 1초간 전송 fps
  final double sendFps;

  /// 측정 경과 시간(초). analysis_progress.elapsed_sec 의 정수 부분.
  /// 측정 시작 시 0으로 리셋.
  final int elapsedSec;

  /// 현재 측정 세션의 RunSession ID.
  final String? currentRunId;

  /// 최근 frame_inference의 pose_detected 값.
  final bool lastPoseDetected;

  /// 가장 최근 수신된 피드백 항목. 다음 피드백이 올 때까지 유지.
  final FeedbackItem? latestFeedbackItem;

  /// 오버레이 영상 업로드 상태
  final OverlayUploadStatus overlayUploadStatus;

  const CaptureWebSocketState({
    this.status = ConnectionStatus.disconnected,
    this.latestProgress,
    this.finalResult,
    this.latestError,
    this.progressCount = 0,
    this.frameInferenceCount = 0,
    this.isCapturing = false,
    this.sentCount = 0,
    this.droppedCount = 0,
    this.captureErrorCount = 0,
    this.sendFps = 0.0,
    this.elapsedSec = 0,
    this.currentRunId,
    this.lastPoseDetected = false,
    this.latestFeedbackItem,
    this.overlayUploadStatus = OverlayUploadStatus.idle,
  });

  CaptureWebSocketState copyWith({
    ConnectionStatus? status,
    AnalysisProgressMessage? latestProgress,
    AnalysisResultMessage? finalResult,
    ErrorServerMessage? latestError,
    int? progressCount,
    int? frameInferenceCount,
    bool? isCapturing,
    int? sentCount,
    int? droppedCount,
    int? captureErrorCount,
    double? sendFps,
    int? elapsedSec,
    String? currentRunId,
    bool? lastPoseDetected,
    FeedbackItem? latestFeedbackItem,
    OverlayUploadStatus? overlayUploadStatus,
    bool clearError = false,
    bool clearFinalResult = false,
  }) {
    return CaptureWebSocketState(
      status: status ?? this.status,
      latestProgress: latestProgress ?? this.latestProgress,
      finalResult: clearFinalResult ? null : (finalResult ?? this.finalResult),
      latestError: clearError ? null : (latestError ?? this.latestError),
      progressCount: progressCount ?? this.progressCount,
      frameInferenceCount: frameInferenceCount ?? this.frameInferenceCount,
      isCapturing: isCapturing ?? this.isCapturing,
      sentCount: sentCount ?? this.sentCount,
      droppedCount: droppedCount ?? this.droppedCount,
      captureErrorCount: captureErrorCount ?? this.captureErrorCount,
      sendFps: sendFps ?? this.sendFps,
      elapsedSec: elapsedSec ?? this.elapsedSec,
      currentRunId: currentRunId ?? this.currentRunId,
      lastPoseDetected: lastPoseDetected ?? this.lastPoseDetected,
      latestFeedbackItem: latestFeedbackItem ?? this.latestFeedbackItem,
      overlayUploadStatus: overlayUploadStatus ?? this.overlayUploadStatus,
    );
  }

  bool get isConnected => status == ConnectionStatus.connected;
  bool get isConnecting => status == ConnectionStatus.connecting;

  /// 최종 결과가 도착했는지
  bool get hasFinalResult => finalResult != null;
}

/// 측정 화면용 WebSocket ViewModel
class CaptureWebSocketViewModel extends Notifier<CaptureWebSocketState> {
  late final CaptureWebSocketService _service;
  late final CaptureLoopController _loop;
  late final TtsService _tts;
  late final RunSessionApiService _runApi;
  StreamSubscription<ConnectionStatus>? _statusSub;
  StreamSubscription<ServerMessage>? _messageSub;
  Stopwatch? _stopwatch;
  Timer? _elapsedTimer;
  bool _stopped = false;

  /// updateRunSession 완료를 외부에서 await 할 수 있는 Completer.
  Completer<void>? _runSessionUpdateCompleter;

  /// updateRunSession이 완료될 때까지 대기.
  Future<void> waitForRunSessionUpdate() =>
      _runSessionUpdateCompleter?.future ?? Future.value();

  /// 같은 metric 재발화 최소 간격 (cooldown).
  static const Duration _ttsRepeatCooldown = Duration(seconds: 4);

  /// metric별 마지막 발화 시각
  final Map<String, DateTime> _lastSpokenAt = {};

  @override
  CaptureWebSocketState build() {
    _service = ref.read(captureWebSocketServiceProvider);
    _tts = ref.read(ttsServiceProvider);
    _runApi = RunSessionApiService();
    final CameraService cameraService = ref.read(cameraServiceProvider);

    _loop = CaptureLoopController(
      camera: cameraService,
      webSocket: _service,
    );
    _loop.stats.addListener(_onLoopStatsChanged);

    _statusSub = _service.statusStream.listen(_onStatusChanged);
    _messageSub = _service.messageStream.listen(_onMessageReceived);

    ref.onDispose(() {
      _statusSub?.cancel();
      _messageSub?.cancel();
      _loop.stats.removeListener(_onLoopStatsChanged);
      _loop.dispose();
      _elapsedTimer?.cancel();
      _stopwatch?.stop();
    });

    return CaptureWebSocketState(status: _service.status);
  }

  // ─────────── 화면이 호출할 액션 ───────────

  /// WebSocket 연결 시작.
  /// 첫 연결 시 RunSession을 서버에 생성하고 반환된 id를 WS URL에 전달.
  /// 재연결 시에는 기존 runId를 재사용.
  Future<void> connect() async {
    state = state.copyWith(clearError: true);

    if (state.currentRunId == null) {
      final userId = ref.read(authViewModelProvider).userId;
      if (userId == null) {
        state = state.copyWith(status: ConnectionStatus.error);
        return;
      }
      try {
        final created = await _runApi.createRun(RunSession(
          id: '0',
          userId: userId,
          status: 'RUNNING',
          mode: 'normal',
        ));
        state = state.copyWith(currentRunId: created.id);
        // ignore: avoid_print
        print('[RunSession] created: id=${created.id}');
      } catch (e) {
        // ignore: avoid_print
        print('[RunSession] creation failed: $e');
        state = state.copyWith(status: ConnectionStatus.error);
        return;
      }
    }

    await _service.connect(runId: state.currentRunId);
  }

  /// 새 측정 세션을 위해 상태 초기화. 화면 진입 시 호출.
  void resetSession() {
    _stopped = false;
    _loop.reset();
    _service.disconnect();
    state = const CaptureWebSocketState();
  }

  /// 연결 종료 (사용자 의도)
  Future<void> disconnect() async {
    await _service.disconnect();
  }

  /// 카메라 프레임 전송 (디버그용 직접 호출).
  ///
  /// production 송신은 [CaptureLoopController]를 통해 자동으로 일어남.
  /// tsMs는 호출 측이 단조시계 기준 ms로 채워줘야 한다.
  bool sendFrame(Uint8List frame, {required int tsMs}) {
    return _service.sendFrame(frame, tsMs: tsMs);
  }

  /// 측정 화면 미리보기용 최신 JPEG.
  ValueListenable<Uint8List?> get latestJpegNotifier => _loop.latestJpeg;

  /// 측정 시작 — session_start 전송 후 캡처 루프 가동
  void startCapture() {
    final camPos = ref.read(captureSetupViewModelProvider).cameraPosition;
    final analysisSide = camPos == CameraPosition.left ? 'left' : 'right';
    final direction = camPos == CameraPosition.left
        ? 'right_to_left'
        : 'left_to_right';
    _service.sendSessionStart(
      analysisSide: analysisSide,
      direction: direction,
    );

    _loop.reset();
    _loop.start();

    _lastSpokenAt.clear();

    // 러닝 시간 측정 시작 (클라이언트 자체)
    _stopwatch = Stopwatch()..start();
    state = state.copyWith(elapsedSec: 0);

    _elapsedTimer?.cancel();
    _elapsedTimer = Timer.periodic(const Duration(seconds: 1), (_) {
      final sw = _stopwatch;
      if (sw != null && sw.isRunning) {
        state = state.copyWith(elapsedSec: sw.elapsed.inSeconds);
      }
    });
  }

  /// 측정 정지 — 캡처 루프 멈춤 + 녹화 종료 (stop 메시지는 별도).
  ///
  /// 오버레이 업로드는 여기서 시작하지 않는다.
  /// analysis_result 수신 후 status가 failed가 아닌 경우에만 트리거된다.
  /// (실패 시 업로드 → 서버가 이미 정리된/존재하지 않는 RunSession을 update해
  ///  StaleStateException이 발생하는 문제 회피)
  Future<void> stopCapture() async {
    await _loop.stop();

    _tts.stop();

    _elapsedTimer?.cancel();
    _elapsedTimer = null;
    _stopwatch?.stop();
  }

  /// 녹화된 MP4를 WorkManager 백그라운드 태스크로 업로드 예약.
  /// 앱이 종료되어도 OS가 업로드 완료를 보장한다.
  Future<void> _uploadOverlayVideo() async {
    final filePath = _loop.recordedFilePath;
    final runId = state.currentRunId;
    if (filePath == null || runId == null) return;

    state = state.copyWith(
      overlayUploadStatus: OverlayUploadStatus.uploading,
    );

    try {
      await enqueueOverlayUpload(OverlayUploadParams(
        runSessionId: runId,
        filePath: filePath,
      ));
      // ignore: avoid_print
      print('[Overlay] upload enqueued for run=$runId');
    } catch (e) {
      state = state.copyWith(
        overlayUploadStatus: OverlayUploadStatus.error,
      );
      // ignore: avoid_print
      print('[Overlay] enqueue failed: $e');
    }
  }

  /// 카메라 하드웨어 완전 해제. 캡처 흐름 완전히 빠져나갈 때 호출.
  Future<void> releaseCamera() async {
    await ref.read(cameraServiceProvider).dispose();
  }

  /// 측정 종료 신호 송신 (백엔드가 analysis_result 응답 트리거)
  ///
  /// 호출 후에도 WebSocket 연결은 유지해야 analysis_result를 받을 수 있음.
  /// 결과 받은 후 disconnect()는 화면이 별도로 호출.
  bool sendStop() {
    _stopped = true;
    _tts.speak('러닝을 종료합니다.');
    // analysis_result가 안 와도 측정 시간이 DB에 남도록 즉시 PUT.
    // status는 보내지 않으므로 RUNNING 유지(@DynamicUpdate 보존).
    _persistDurationEarly();
    return _service.sendStop();
  }

  /// stop 시점의 elapsedSec만 PUT으로 먼저 저장.
  ///
  /// analysis_result 수신 후 [updateRunSession]이 status='DONE'으로 다시
  /// update하므로 중복 호출이지만, 분석 결과를 못 받는 경로(앱 강종/네트워크
  /// 단절/PUT 실패)에서도 duration은 보존된다.
  Future<void> _persistDurationEarly() async {
    final runId = state.currentRunId;
    final userId = ref.read(authViewModelProvider).userId;
    if (runId == null || userId == null) return;
    try {
      await _runApi.updateRun(RunSession(
        id: runId,
        userId: userId,
        duration: state.elapsedSec,
      ));
      // ignore: avoid_print
      print('[RunSession] duration persisted on stop: id=$runId, '
          'duration=${state.elapsedSec}s');
    } catch (e) {
      // ignore: avoid_print
      print('[RunSession] early duration persist failed: $e');
    }
  }

  /// 러닝 종료 후 RunSession 상태를 DONE으로 업데이트.
  Future<void> updateRunSession() async {
    final runId = state.currentRunId;
    final userId = ref.read(authViewModelProvider).userId;
    if (runId == null || userId == null) return;

    _runSessionUpdateCompleter = Completer<void>();
    try {
      await _runApi.updateRun(RunSession(
        id: runId,
        userId: userId,
        status: 'DONE',
        duration: state.elapsedSec,
      ));
      // ignore: avoid_print
      print('[RunSession] updated to DONE: id=$runId, duration=${state.elapsedSec}s');
    } catch (e) {
      // ignore: avoid_print
      print('[RunSession] update failed: $e');
    } finally {
      _runSessionUpdateCompleter?.complete();
    }
  }

  /// 분석 실패 시 관련 데이터 정리 후 RunSession 삭제.
  ///
  /// DELETE 자체는 백엔드에서 허용되지만, 이후 오버레이 업로드가 실행되면
  /// 삭제된 RunSession을 update하려다 StaleStateException(500)이 발생한다.
  /// 따라서 이 메서드 호출 경로에서는 절대 _uploadOverlayVideo()를 트리거하지 말 것.
  Future<void> _deleteRunSession() async {
    final runId = state.currentRunId;
    if (runId == null) return;

    try {
      await _runApi.deleteHighlightsByRun(runId);
    } catch (e) {
      // ignore: avoid_print
      print('[RunSession] highlight cleanup failed: $e');
    }

    try {
      await _runApi.deleteFeedbacksByRun(runId);
    } catch (e) {
      // ignore: avoid_print
      print('[RunSession] feedback cleanup failed: $e');
    }

    try {
      await _runApi.deleteRun(runId);
      // ignore: avoid_print
      print('[RunSession] deleted (analysis failed): id=$runId');
    } catch (e) {
      // ignore: avoid_print
      print('[RunSession] delete failed: $e');
    }
  }

  // ─────────── 내부 상태 업데이트 ───────────

  void _onStatusChanged(ConnectionStatus status) {
    state = state.copyWith(status: status);
    if (status == ConnectionStatus.disconnected ||
        status == ConnectionStatus.error) {
      _loop.stop();
      if (_stopped) {
        _service.disconnect();
      }
    }
  }

  void _onLoopStatsChanged() {
    final s = _loop.stats.value;
    state = state.copyWith(
      isCapturing: s.isRunning,
      sentCount: s.sentCount,
      droppedCount: s.droppedCount,
      captureErrorCount: s.errorCount,
      sendFps: s.sendFps,
    );
  }

  void _onMessageReceived(ServerMessage msg) {
    if (_stopped) {
      if (msg is AnalysisResultServerMessage) {
        state = state.copyWith(finalResult: msg.data, clearError: true);
        if (msg.data.status == AnalysisStatus.failed) {
          _deleteRunSession();
        } else {
          updateRunSession();
          if (_loop.recordedFilePath != null) {
            _uploadOverlayVideo();
          }
        }
      }
      return;
    }

    switch (msg) {
      case FrameInferenceServerMessage(:final data):
        state = state.copyWith(
          frameInferenceCount: state.frameInferenceCount + 1,
          lastPoseDetected: data.result.poseDetected,
        );

      case AnalysisProgressServerMessage(:final data):
        final feedback = data.topPriorityItem;
        state = state.copyWith(
          latestProgress: data,
          progressCount: state.progressCount + 1,
          clearError: true,
          latestFeedbackItem: feedback,
        );
        _maybeSpeakFeedback(data.ttsItem);

      case AnalysisResultServerMessage(:final data):
        _stopped = true;
        state = state.copyWith(
          finalResult: data,
          clearError: true,
        );
        if (data.status == AnalysisStatus.failed) {
          _tts.speak('분석에 실패했습니다. 다시 촬영해 주세요.');
          _deleteRunSession();
        } else {
          _tts.speak('분석이 완료되었습니다. 러닝을 종료합니다.');
          updateRunSession();
        }
        stopCapture().then((_) {
          if (data.status != AnalysisStatus.failed &&
              _loop.recordedFilePath != null) {
            _uploadOverlayVideo();
          }
        });

      case ErrorServerMessage():
        state = state.copyWith(latestError: msg);

      case UnknownServerMessage():
        break;
    }
  }

  /// 자세 경고 항목을 TTS로 발화.
  /// 서버가 이미 빈도 제한을 적용하므로 클라는 metric 쿨다운만 유지.
  void _maybeSpeakFeedback(FeedbackItem? item) {
    if (item == null) return;

    final text = item.ttsText?.trim();
    if (text == null || text.isEmpty) return;

    final metric = item.metric;
    if (metric != null) {
      final lastAt = _lastSpokenAt[metric];
      if (lastAt != null &&
          DateTime.now().difference(lastAt) < _ttsRepeatCooldown) {
        return;
      }
      _lastSpokenAt[metric] = DateTime.now();
    }
    _tts.speak(text);
  }
}

/// 측정 WebSocket ViewModel Provider
final captureWebSocketViewModelProvider = NotifierProvider<
    CaptureWebSocketViewModel, CaptureWebSocketState>(
  CaptureWebSocketViewModel.new,
);
