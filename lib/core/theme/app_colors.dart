import 'package:flutter/material.dart';

/// ChoboRunner 앱 전용 색상 팔레트.
///
/// 화면 코드에서는 직접 hex 값을 사용하지 말고 이 클래스의 상수를 참조할 것.
class AppColors {
  AppColors._(); // 인스턴스화 금지

  // ─── 배경 / 표면 ───────────────────────────────
  /// 메인 배경 (거의 검정)
  static const Color background = Color(0xFF0F0F0F);

  /// 카드/컨테이너 배경
  static const Color surface = Color(0xFF1A1A1A);

  /// 카메라 영역 placeholder (와이어프레임의 보라)
  static const Color cameraPlaceholder = Color(0xFFA78BFA);

  // ─── 액션 ──────────────────────────────────────
  /// Primary 액션 버튼 (러닝 시작 / 러닝 종료)
  static const Color primaryAction = Color(0xFFD4FF6B);

  /// Primary 버튼 위 텍스트
  static const Color primaryActionText = Color(0xFF0F0F0F);

  /// Secondary 액션 버튼 (홈으로)
  static const Color secondaryAction = Color(0xFF2A2A2A);

  /// Secondary 버튼 위 텍스트
  static const Color secondaryActionText = Color(0xFFFFFFFF);

  // ─── 텍스트 ────────────────────────────────────
  static const Color textPrimary = Color(0xFFFFFFFF);
  static const Color textSecondary = Color(0xB3FFFFFF); // 흰색 70%
  static const Color textTertiary = Color(0x80FFFFFF); // 흰색 50%
  static const Color textMuted = Color(0x66FFFFFF);    // 흰색 40%

  // ─── 인식 상태 ─────────────────────────────────
  /// 인식 중 (노랑)
  static const Color statusPending = Color(0xFFFBBF24);

  /// 인식됨 (초록)
  static const Color statusOk = Color(0xFF10B981);

  /// 인식 안 됨 (빨강)
  static const Color statusError = Color(0xFFEF4444);

  /// 연결 중 (오렌지)
  static const Color statusConnecting = Color(0xFFFB923C);

  // ─── 피드백 카테고리 ────────────────────────────
  /// 자세 경고 (앰버)
  static const Color feedbackWarning = Color(0xFFFBBF24);

  /// 자세 정보 (라이트 블루)
  static const Color feedbackInfo = Color(0xFF60A5FA);

  /// 시스템 안내 (그레이)
  static const Color feedbackSystem = Color(0xB3FFFFFF);

  // ─── 구분선 ────────────────────────────────────
  static const Color divider = Color(0x33FFFFFF); // 흰색 20%
}
