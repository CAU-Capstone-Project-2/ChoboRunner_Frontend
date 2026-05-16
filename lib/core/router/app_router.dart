import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../features/capture/view/capture_finish_screen.dart';
import '../../features/capture/view/capture_measuring_screen.dart';
import '../../features/capture/view/capture_setup_screen.dart';
import '../../features/home/view/home_screen.dart';
import '../../features/report/view/report_list_screen.dart';

/// 앱 라우팅 경로 상수
///
/// 화면 이동 시 직접 path를 쓰지 말고 이 상수를 사용할 것.
class AppRoutes {
  AppRoutes._();

  static const String home = '/home';
  static const String captureSetup = '/capture/setup';
  static const String capture = '/capture';
  static const String captureFinish = '/capture/finish';
  static const String report = '/report';

  // 미래 추가 예정
  // static const String login = '/auth/login';
  // static const String signup = '/auth/signup';
  // static const String settings = '/settings';
}

/// GoRouter 인스턴스 Provider.
///
/// ViewModel에서 ref.read(routerProvider)로 접근하여 화면 이동 가능.
final routerProvider = Provider<GoRouter>((ref) {
  return GoRouter(
    initialLocation: AppRoutes.home,
    routes: [
      GoRoute(
        path: AppRoutes.home,
        name: 'home',
        builder: (context, state) => const HomeScreen(),
      ),
      GoRoute(
        path: AppRoutes.captureSetup,
        name: 'captureSetup',
        builder: (context, state) => const CaptureSetupScreen(),
      ),
      GoRoute(
        path: AppRoutes.capture,
        name: 'capture',
        builder: (context, state) => const CaptureMeasuringScreen(),
      ),
      GoRoute(
        path: AppRoutes.captureFinish,
        name: 'captureFinish',
        builder: (context, state) {
          // URL 쿼리 파라미터 ?elapsedSec=145 형태로 전달받음
          final raw = state.uri.queryParameters['elapsedSec'];
          final elapsedSec = int.tryParse(raw ?? '') ?? 0;
          return CaptureFinishScreen(elapsedSec: elapsedSec);
        },
      ),
      GoRoute(
        path: AppRoutes.report,
        name: 'report',
        builder: (context, state) => const ReportListScreen(),
      ),
    ],
  );
});
