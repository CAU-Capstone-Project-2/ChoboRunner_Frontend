import 'package:flutter/material.dart';

import '../../../core/theme/app_colors.dart';

/// 세션 복구 중 잠깐 보여주는 화면.
///
/// AuthStatus.unknown 동안만 표시되며, 복구가 끝나면 라우터 redirect로
/// /home 또는 /auth/login 으로 이동한다.
class SplashScreen extends StatelessWidget {
  const SplashScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return const Scaffold(
      backgroundColor: AppColors.background,
      body: Center(
        child: CircularProgressIndicator(color: AppColors.primaryAction),
      ),
    );
  }
}
