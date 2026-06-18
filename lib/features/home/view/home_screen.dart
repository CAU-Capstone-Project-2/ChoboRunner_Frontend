import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/router/app_router.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_typography.dart';
import '../../report/model/report_session.dart';
import '../../report/viewmodel/report_list_viewmodel.dart';

class HomeScreen extends ConsumerStatefulWidget {
  const HomeScreen({super.key});

  @override
  ConsumerState<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends ConsumerState<HomeScreen> {
  @override
  void initState() {
    super.initState();
    ref.listenManual(reportListProvider, (_, __) {});
    Future.microtask(() => ref.invalidate(reportListProvider));
  }

  @override
  Widget build(BuildContext context) {
    final asyncSessions = ref.watch(reportListProvider);

    return Scaffold(
      backgroundColor: AppColors.background,
      body: SafeArea(
        child: SingleChildScrollView(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              const _Header(),
              const SizedBox(height: 16),
              const _HeroSection(),
              const SizedBox(height: 24),
              _AnalysisSection(asyncSessions: asyncSessions),
              const SizedBox(height: 24),
            ],
          ),
        ),
      ),
    );
  }
}

class _Header extends StatelessWidget {
  const _Header();

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 8, 16, 0),
      child: Row(
        children: [
          const SizedBox(width: 40),
          const Expanded(
            child: Text(
              'Chobo Runner',
              textAlign: TextAlign.center,
              style: AppTypography.brandTitle,
            ),
          ),
          SizedBox(
            width: 40,
            child: IconButton(
              icon: const Icon(Icons.settings, color: AppColors.textPrimary),
              onPressed: () => context.push(AppRoutes.settings),
              padding: EdgeInsets.zero,
            ),
          ),
        ],
      ),
    );
  }
}

class _HeroSection extends StatelessWidget {
  const _HeroSection();

  @override
  Widget build(BuildContext context) {
    return Stack(
      clipBehavior: Clip.none,
      children: [
        Container(
          height: 295,
          color: AppColors.heroBanner,
          alignment: Alignment.topCenter,
          child: const Padding(
            padding: EdgeInsets.fromLTRB(24, 32, 24, 0),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              crossAxisAlignment: CrossAxisAlignment.center,
              children: [
                Padding(
                  padding: EdgeInsets.only(top: 24),
                  child: Icon(
                    Icons.directions_run,
                    color: AppColors.primaryAction,
                    size: 128,
                  ),
                ),
                SizedBox(width: 16),
                Padding(
                  padding: EdgeInsets.only(top: 24),
                  child: Text(
                    '지금 바로\n달려 보세요!',
                    textAlign: TextAlign.left,
                    style: AppTypography.heroHeading,
                  ),
                ),
              ],
            ),
          ),
        ),
        Positioned(
          left: 50,
          right: 50,
          bottom: 16,
          child: SizedBox(
            height: 62,
            child: FilledButton(
              style: FilledButton.styleFrom(
                backgroundColor: AppColors.primaryAction,
                foregroundColor: AppColors.primaryActionText,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(30),
                ),
              ),
              onPressed: () => context.go(AppRoutes.captureSetup),
              child: const Text('러닝 시작', style: AppTypography.ctaButton),
            ),
          ),
        ),
      ],
    );
  }
}

class _AnalysisSection extends StatelessWidget {
  const _AnalysisSection({required this.asyncSessions});
  final AsyncValue<List<ReportSession>> asyncSessions;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 10),
      child: Container(
        decoration: BoxDecoration(
          color: AppColors.analysisCard,
          borderRadius: BorderRadius.circular(16),
        ),
        padding: const EdgeInsets.fromLTRB(20, 20, 20, 20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            InkWell(
              onTap: () => context.push(AppRoutes.report),
              borderRadius: BorderRadius.circular(8),
              child: Padding(
                padding: const EdgeInsets.symmetric(vertical: 4),
                child: Row(
                  children: [
                    const Text('러닝 분석', style: AppTypography.cardHeading),
                    const Spacer(),
                    Icon(
                      Icons.chevron_right,
                      size: 24,
                      color: AppColors.analysisText.withValues(alpha: 0.6),
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 16),
            asyncSessions.when(
              loading: () => const Padding(
                padding: EdgeInsets.symmetric(vertical: 24),
                child: Center(
                  child: CircularProgressIndicator(
                    color: AppColors.textPrimary,
                    strokeWidth: 2,
                  ),
                ),
              ),
              error: (_, __) => const Padding(
                padding: EdgeInsets.symmetric(vertical: 24),
                child: Center(
                  child: Text('기록을 불러올 수 없습니다.',
                      style: AppTypography.bodyMuted),
                ),
              ),
              data: (sessions) {
                if (sessions.isEmpty) {
                  return const Padding(
                    padding: EdgeInsets.symmetric(vertical: 24),
                    child: Center(
                      child: Text('아직 러닝 기록이 없습니다.',
                          style: AppTypography.bodyMuted),
                    ),
                  );
                }
                final display = sessions.take(3).toList();
                return Column(
                  children: display
                      .map((s) => Padding(
                            padding: const EdgeInsets.only(bottom: 12),
                            child: _RecordEntry(session: s),
                          ))
                      .toList(),
                );
              },
            ),
          ],
        ),
      ),
    );
  }
}

class _RecordEntry extends StatelessWidget {
  const _RecordEntry({required this.session});
  final ReportSession session;

  @override
  Widget build(BuildContext context) {
    return Container(
      height: 70,
      decoration: BoxDecoration(
        color: AppColors.analysisEntry,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Colors.black, width: 1),
      ),
      padding: const EdgeInsets.symmetric(horizontal: 16),
      child: Row(
        children: [
          Expanded(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(_formatDate(session.date), style: AppTypography.cardBody),
                const SizedBox(height: 4),
                Text(
                  _formatDuration(session.duration),
                  style: AppTypography.cardBody,
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  String _formatDate(DateTime d) {
    final y = d.year.toString().padLeft(4, '0');
    final m = d.month.toString().padLeft(2, '0');
    final day = d.day.toString().padLeft(2, '0');
    final h = d.hour.toString().padLeft(2, '0');
    final min = d.minute.toString().padLeft(2, '0');
    return '$y-$m-$day $h:$min';
  }

  String _formatDuration(int? sec) {
    if (sec == null) return '-';
    final mm = (sec ~/ 60).toString();
    final ss = (sec % 60).toString().padLeft(2, '0');
    return '$mm분 $ss초';
  }
}
