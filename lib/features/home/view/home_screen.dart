import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../../core/router/app_router.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_typography.dart';

/// Mock 러닝 이력 데이터. 실제 데이터 연동은 추후 ViewModel 단계에서.
class _RunningRecord {
  final String date;
  final String duration;
  final int score;
  const _RunningRecord({
    required this.date,
    required this.duration,
    required this.score,
  });
}

const List<_RunningRecord> _mockRecords = [
  _RunningRecord(date: '2026-03-07', duration: '40:00', score: 70),
  _RunningRecord(date: '2026-03-05', duration: '40:00', score: 79),
  _RunningRecord(date: '2026-03-01', duration: '40:00', score: 50),
];

class HomeScreen extends StatelessWidget {
  const HomeScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      body: SafeArea(
        child: SingleChildScrollView(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: const [
              _Header(),
              SizedBox(height: 16),
              _HeroSection(),
              SizedBox(height: 24),
              _AnalysisSection(records: _mockRecords),
              SizedBox(height: 24),
            ],
          ),
        ),
      ),
    );
  }
}

// ─────────── 헤더 (로고 + 브랜드명) ───────────

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

// ─────────── 히어로 영역 (보라 배너 + CTA) ───────────

class _HeroSection extends StatelessWidget {
  const _HeroSection();

  @override
  Widget build(BuildContext context) {
    return Stack(
      clipBehavior: Clip.none,
      children: [
        // 보라 배너
        Container(
          height: 295,
          margin: const EdgeInsets.symmetric(horizontal: 0),
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
        // CTA 버튼 (배너 하단에 걸침)
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

// ─────────── 러닝 분석 섹션 (흰 카드 + 이력 리스트) ───────────

class _AnalysisSection extends StatelessWidget {
  const _AnalysisSection({required this.records});
  final List<_RunningRecord> records;

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
            // 헤더: '러닝 분석' + 진입 화살표 (탭 시 리포트 선택 화면으로)
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
            ...records.map((r) => Padding(
                  padding: const EdgeInsets.only(bottom: 12),
                  child: _RecordEntry(record: r),
                )),
          ],
        ),
      ),
    );
  }
}

class _RecordEntry extends StatelessWidget {
  const _RecordEntry({required this.record});
  final _RunningRecord record;

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
          // 날짜 + 시간 (좌측 2줄)
          Expanded(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(record.date, style: AppTypography.cardBody),
                const SizedBox(height: 4),
                Text(record.duration, style: AppTypography.cardBody),
              ],
            ),
          ),
          // 점수 (우측, 점수에 따른 색상의 원형 테두리)
          _ScoreBadge(score: record.score, color: _scoreColor(record.score)),
        ],
      ),
    );
  }

  Color _scoreColor(int score) {
    if (score >= 75) return AppColors.scoreHigh;
    if (score >= 60) return AppColors.scoreMid;
    return AppColors.scoreLow;
  }
}

class _ScoreBadge extends StatelessWidget {
  const _ScoreBadge({required this.score, required this.color});
  final int score;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 44,
      height: 44,
      alignment: Alignment.center,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        border: Border.all(color: color, width: 2),
      ),
      child: Text(
        '$score',
        textAlign: TextAlign.center,
        style: TextStyle(
          color: color,
          fontSize: 16,
          fontWeight: FontWeight.w700,
        ),
      ),
    );
  }
}
