import 'package:camera/camera.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:permission_handler/permission_handler.dart';

import '../../../core/router/app_router.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_typography.dart';
import '../viewmodel/camera_viewmodel.dart';
import '../viewmodel/capture_setup_viewmodel.dart';
import '../viewmodel/capture_websocket_viewmodel.dart';

class CaptureSetupScreen extends ConsumerStatefulWidget {
  const CaptureSetupScreen({super.key});

  @override
  ConsumerState<CaptureSetupScreen> createState() => _CaptureSetupScreenState();
}

class _CaptureSetupScreenState extends ConsumerState<CaptureSetupScreen> {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      ref.read(captureSetupViewModelProvider.notifier).reset();
      ref
          .read(cameraViewModelProvider.notifier)
          .requestPermissionAndInitialize();
    });
  }

  @override
  Widget build(BuildContext context) {
    final cameraState = ref.watch(cameraViewModelProvider);

    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        title: const Text('촬영 준비', style: AppTypography.screenTitle),
        backgroundColor: AppColors.background,
        elevation: 0,
        centerTitle: true,
        actions: [
          IconButton(
            icon: const Icon(
              Icons.help_outline,
              color: AppColors.textPrimary,
            ),
            tooltip: '촬영 가이드',
            onPressed: () => _showGuideSheet(context),
          ),
        ],
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

    return const _MainContent();
  }

  void _showGuideSheet(BuildContext context) {
    showModalBottomSheet<void>(
      context: context,
      backgroundColor: AppColors.surface,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (_) => const _GuideSheet(),
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

// ─────────── 메인 콘텐츠 (모드 분기) ───────────

class _MainContent extends ConsumerWidget {
  const _MainContent();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final setupState = ref.watch(captureSetupViewModelProvider);
    final cameraVm = ref.read(cameraViewModelProvider.notifier);
    final controller = cameraVm.service.controller;

    if (controller == null || !controller.value.isInitialized) {
      return const Center(
        child: CircularProgressIndicator(color: AppColors.textPrimary),
      );
    }

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 20),
      child: Column(
        children: [
          // 카메라 영역 (모드 무관 공통)
          Expanded(
            flex: 5,
            child: Padding(
              padding: const EdgeInsets.only(top: 8, bottom: 16),
              child: _CameraArea(controller: controller),
            ),
          ),

          const SizedBox(height: 16),

          // 모드별 분기 영역
          Expanded(
            flex: 3,
            child: setupState.mode == SetupMode.setup
                ? const _SetupContent()
                : _CountdownContent(value: setupState.countdownValue),
          ),

          const SizedBox(height: 8),
        ],
      ),
    );
  }
}

// ─────────── 카메라 영역 ───────────

class _CameraArea extends StatelessWidget {
  const _CameraArea({required this.controller});
  final CameraController controller;

  @override
  Widget build(BuildContext context) {
    return ClipRRect(
      borderRadius: BorderRadius.circular(16),
      child: Stack(
        fit: StackFit.expand,
        children: [
          Container(color: AppColors.cameraPlaceholder),
          FittedBox(
            fit: BoxFit.cover,
            child: SizedBox(
              width: controller.value.previewSize?.height ?? 1,
              height: controller.value.previewSize?.width ?? 1,
              child: CameraPreview(controller),
            ),
          ),
        ],
      ),
    );
  }
}

// ─────────── setup 모드 콘텐츠 ───────────

class _SetupContent extends ConsumerWidget {
  const _SetupContent();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final setupState = ref.watch(captureSetupViewModelProvider);
    final setupVm = ref.read(captureSetupViewModelProvider.notifier);

    return Column(
      mainAxisAlignment: MainAxisAlignment.end,
      children: [
        const Spacer(),
        // 카메라 위치 선택
        const Text(
          '카메라 위치 (분석 대상자 기준)',
          style: AppTypography.label,
        ),
        const SizedBox(height: 10),
        _CameraPositionSelector(
          selected: setupState.cameraPosition,
          onChanged: setupVm.setCameraPosition,
        ),
        const Spacer(),
        // 홈으로 (secondary)
        SizedBox(
          width: double.infinity,
          height: 48,
          child: FilledButton(
            style: FilledButton.styleFrom(
              backgroundColor: AppColors.secondaryAction,
              foregroundColor: AppColors.secondaryActionText,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(24),
              ),
            ),
            onPressed: () {
              ref.read(captureWebSocketViewModelProvider.notifier).releaseCamera();
              context.go(AppRoutes.home);
            },
            child: const Text('홈으로', style: AppTypography.secondaryButton),
          ),
        ),
        const SizedBox(height: 10),
        // 러닝 시작 (primary)
        SizedBox(
          width: double.infinity,
          height: 52,
          child: FilledButton(
            style: FilledButton.styleFrom(
              backgroundColor: AppColors.primaryAction,
              foregroundColor: AppColors.primaryActionText,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(26),
              ),
            ),
            onPressed: () {
              // 카운트다운이 시작되면 _SetupContent가 트리에서 제거되어
              // context가 unmount되므로, 안정적인 router 참조를 미리 캡처.
              final router = ref.read(routerProvider);
              setupVm.startCountdown(
                onComplete: () {
                  router.go(AppRoutes.capture);
                },
              );
            },
            child: const Text('러닝 시작', style: AppTypography.primaryButton),
          ),
        ),
      ],
    );
  }
}

// ─────────── countdown 모드 콘텐츠 ───────────

class _CountdownContent extends StatelessWidget {
  const _CountdownContent({required this.value});
  final int value;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Container(
        width: 120,
        height: 120,
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          border: Border.all(
            color: AppColors.cameraPlaceholder,
            width: 3,
          ),
        ),
        alignment: Alignment.center,
        child: Text(
          '$value',
          style: const TextStyle(
            color: AppColors.textPrimary,
            fontSize: 56,
            fontWeight: FontWeight.w700,
          ),
        ),
      ),
    );
  }
}

// ─────────── 카메라 위치 선택 ───────────

class _CameraPositionSelector extends StatelessWidget {
  const _CameraPositionSelector({
    required this.selected,
    required this.onChanged,
  });

  final CameraPosition selected;
  final ValueChanged<CameraPosition> onChanged;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Expanded(
          child: _PositionButton(
            label: '좌측',
            icon: Icons.chevron_left,
            isSelected: selected == CameraPosition.left,
            onTap: () => onChanged(CameraPosition.left),
          ),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: _PositionButton(
            label: '우측',
            icon: Icons.chevron_right,
            isSelected: selected == CameraPosition.right,
            onTap: () => onChanged(CameraPosition.right),
          ),
        ),
      ],
    );
  }
}

class _PositionButton extends StatelessWidget {
  const _PositionButton({
    required this.label,
    required this.icon,
    required this.isSelected,
    required this.onTap,
  });

  final String label;
  final IconData icon;
  final bool isSelected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        height: 48,
        decoration: BoxDecoration(
          color: isSelected ? AppColors.primaryAction : AppColors.surface,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
            color: isSelected ? AppColors.primaryAction : AppColors.divider,
            width: 1.5,
          ),
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              icon,
              size: 20,
              color: isSelected
                  ? AppColors.primaryActionText
                  : AppColors.textSecondary,
            ),
            const SizedBox(width: 4),
            Text(
              label,
              style: TextStyle(
                color: isSelected
                    ? AppColors.primaryActionText
                    : AppColors.textSecondary,
                fontSize: 15,
                fontWeight: isSelected ? FontWeight.w700 : FontWeight.w500,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ─────────── 가이드 Bottom Sheet ───────────

class _GuideSheet extends StatelessWidget {
  const _GuideSheet();

  static const List<String> _guides = [
    '러닝머신 측면에서 카메라를 고정하고 촬영해주세요.',
    '분석 대상자가 화면 중앙에 가장 크게 보이도록 촬영해주세요.',
    '머리부터 발끝까지 전신이 화면에 들어오도록 촬영해주세요.',
    '발끝과 뒤꿈치가 화면 아래에서 잘리지 않도록 카메라를 조금 멀리 두세요.',
    '몸의 옆면이 보이도록 카메라를 배치해주세요.',
    '촬영 중 카메라가 흔들리지 않도록 고정해주세요.',
    '최소 10초 이상 연속으로 달려주세요.',
  ];

  @override
  Widget build(BuildContext context) {
    final maxHeight = MediaQuery.of(context).size.height * 0.85;
    return SafeArea(
      child: ConstrainedBox(
        constraints: BoxConstraints(maxHeight: maxHeight),
        child: SingleChildScrollView(
          padding: const EdgeInsets.fromLTRB(20, 16, 20, 20),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // 핸들바
              Center(
                child: Container(
                  width: 40,
                  height: 4,
                  decoration: BoxDecoration(
                    color: AppColors.divider,
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
              ),
              const SizedBox(height: 16),
              const Text('촬영 가이드', style: AppTypography.displayMedium),
              const SizedBox(height: 16),
              ..._guides.asMap().entries.map((entry) {
                final index = entry.key + 1;
                final text = entry.value;
                return Padding(
                  padding: const EdgeInsets.symmetric(vertical: 8),
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      SizedBox(
                        width: 24,
                        child: Text(
                          '$index.',
                          style: AppTypography.body.copyWith(
                            color: AppColors.primaryAction,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                      ),
                      Expanded(child: Text(text, style: AppTypography.body)),
                    ],
                  ),
                );
              }),
              const SizedBox(height: 8),
            ],
          ),
        ),
      ),
    );
  }
}
