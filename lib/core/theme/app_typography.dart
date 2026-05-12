import 'package:flutter/material.dart';

import 'app_colors.dart';

/// ChoboRunner 앱 전용 텍스트 스타일 팔레트.
///
/// 와이어프레임의 텍스트 위계를 코드에서 일관되게 사용하기 위함.
class AppTypography {
  AppTypography._();

  /// 화면 제목 (AppBar)
  static const TextStyle screenTitle = TextStyle(
    color: AppColors.textPrimary,
    fontSize: 18,
    fontWeight: FontWeight.w700,
    letterSpacing: -0.2,
  );

  /// 큰 강조 (러닝 시간 표시 등)
  static const TextStyle displayLarge = TextStyle(
    color: AppColors.textPrimary,
    fontSize: 32,
    fontWeight: FontWeight.w700,
    letterSpacing: -0.5,
  );

  /// 중간 강조 (러닝 시간 라벨 등)
  static const TextStyle displayMedium = TextStyle(
    color: AppColors.textPrimary,
    fontSize: 20,
    fontWeight: FontWeight.w600,
  );

  /// 본문 (피드백 메시지)
  static const TextStyle body = TextStyle(
    color: AppColors.textPrimary,
    fontSize: 14,
    fontWeight: FontWeight.w500,
    height: 1.4,
  );

  /// 보조 본문 (가이드 메시지 등)
  static const TextStyle bodyMuted = TextStyle(
    color: AppColors.textSecondary,
    fontSize: 13,
    fontWeight: FontWeight.w400,
    height: 1.4,
  );

  /// Primary 버튼 라벨
  static const TextStyle primaryButton = TextStyle(
    color: AppColors.primaryActionText,
    fontSize: 16,
    fontWeight: FontWeight.w700,
  );

  /// Secondary 버튼 라벨
  static const TextStyle secondaryButton = TextStyle(
    color: AppColors.secondaryActionText,
    fontSize: 14,
    fontWeight: FontWeight.w500,
  );

  /// 작은 라벨 (인식 상태 텍스트 등)
  static const TextStyle label = TextStyle(
    color: AppColors.textPrimary,
    fontSize: 14,
    fontWeight: FontWeight.w500,
  );

  /// 디버그 영역 라벨
  static const TextStyle debugLabel = TextStyle(
    color: AppColors.textMuted,
    fontSize: 10,
    fontWeight: FontWeight.w400,
  );

  /// 디버그 영역 값
  static const TextStyle debugValue = TextStyle(
    color: AppColors.textPrimary,
    fontSize: 14,
    fontWeight: FontWeight.w700,
  );

  // ─── 홈 화면 ───────────────────────────────────

  /// 'Chobo Runner' 브랜드 타이틀
  static const TextStyle brandTitle = TextStyle(
    color: AppColors.primaryAction,
    fontSize: 32,
    fontWeight: FontWeight.w500,
    letterSpacing: -0.5,
  );

  /// 히어로 헤딩 ('지금 바로 달려 보세요!')
  static const TextStyle heroHeading = TextStyle(
    color: AppColors.primaryAction,
    fontSize: 32,
    fontWeight: FontWeight.w500,
    height: 1.4,
  );

  /// 큰 CTA 버튼 라벨 ('러닝 시작')
  static const TextStyle ctaButton = TextStyle(
    color: AppColors.primaryActionText,
    fontSize: 24,
    fontWeight: FontWeight.w500,
  );

  /// 카드 헤딩 ('러닝 분석')
  static const TextStyle cardHeading = TextStyle(
    color: AppColors.analysisText,
    fontSize: 16,
    fontWeight: FontWeight.w500,
    height: 1.25,
  );

  /// 카드 본문 텍스트 (날짜/시간)
  static const TextStyle cardBody = TextStyle(
    color: AppColors.analysisText,
    fontSize: 16,
    fontWeight: FontWeight.w500,
    height: 1.25,
  );
}
