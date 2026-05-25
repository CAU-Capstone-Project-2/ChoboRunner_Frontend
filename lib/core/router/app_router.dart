import 'package:flutter/widgets.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../features/auth/view/login_screen.dart';
import '../../features/auth/view/signup_screen.dart';
import '../../features/auth/view/splash_screen.dart';
import '../../features/auth/view/start_screen.dart';
import '../../features/auth/viewmodel/auth_viewmodel.dart';
import '../../features/capture/view/capture_finish_screen.dart';
import '../../features/settings/view/settings_screen.dart';
import '../../features/capture/view/capture_measuring_screen.dart';
import '../../features/capture/view/capture_setup_screen.dart';
import '../../features/home/view/home_screen.dart';
import '../../features/report/model/report_metric.dart';
import '../../features/report/view/analysis_report_screen.dart';
import '../../features/report/view/highlight_feedback_screen.dart';
import '../../features/report/view/metric_detail_screen.dart';
import '../../features/report/view/report_list_screen.dart';

/// 앱 라우팅 경로 상수
///
/// 화면 이동 시 직접 path를 쓰지 말고 이 상수를 사용할 것.
class AppRoutes {
  AppRoutes._();

  static const String splash = '/';
  static const String authStart = '/auth';
  static const String login = '/auth/login';
  static const String signup = '/auth/signup';
  static const String home = '/home';
  static const String captureSetup = '/capture/setup';
  static const String capture = '/capture';
  static const String captureFinish = '/capture/finish';
  static const String settings = '/settings';
  static const String report = '/report';

  /// 분석 리포트 화면 경로 빌더 (`/report/:sessionId/analysis`).
  static String analysisReport(String sessionId) =>
      '/report/$sessionId/analysis';

  /// 세부 지표 화면 경로 빌더 (`/report/:sessionId/metric/:metricType`).
  static String metricDetail(String sessionId, String metricType) =>
      '/report/$sessionId/metric/$metricType';

  /// 하이라이트 피드백 화면 경로 빌더 (`/report/:sessionId/highlight`).
  static String highlightFeedback(String sessionId) =>
      '/report/$sessionId/highlight';
}

/// GoRouter 인스턴스 Provider.
///
/// ViewModel에서 ref.read(routerProvider)로 접근하여 화면 이동 가능.
/// 세션 상태에 따라 자동으로 splash/login/home 분기.
final routerProvider = Provider<GoRouter>((ref) {
  final authNotifier = _AuthChangeNotifier(ref);
  ref.onDispose(authNotifier.dispose);

  return GoRouter(
    initialLocation: AppRoutes.splash,
    refreshListenable: authNotifier,
    redirect: (context, state) {
      final auth = ref.read(authViewModelProvider);
      final loc = state.matchedLocation;
      final isAuthRoute = loc == AppRoutes.authStart ||
          loc == AppRoutes.login ||
          loc == AppRoutes.signup;
      final isSplash = loc == AppRoutes.splash;

      switch (auth.status) {
        case AuthStatus.unknown:
          return isSplash ? null : AppRoutes.splash;
        case AuthStatus.signedOut:
          return isAuthRoute ? null : AppRoutes.authStart;
        case AuthStatus.signedIn:
          if (isSplash || isAuthRoute) return AppRoutes.home;
          return null;
      }
    },
    routes: [
      GoRoute(
        path: AppRoutes.splash,
        name: 'splash',
        builder: (context, state) => const SplashScreen(),
      ),
      GoRoute(
        path: AppRoutes.authStart,
        name: 'authStart',
        builder: (context, state) => const StartScreen(),
      ),
      GoRoute(
        path: AppRoutes.login,
        name: 'login',
        builder: (context, state) => const LoginScreen(),
      ),
      GoRoute(
        path: AppRoutes.signup,
        name: 'signup',
        builder: (context, state) => const SignupScreen(),
      ),
      GoRoute(
        path: AppRoutes.home,
        name: 'home',
        builder: (context, state) => const HomeScreen(),
      ),
      GoRoute(
        path: AppRoutes.settings,
        name: 'settings',
        builder: (context, state) => const SettingsScreen(),
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
      GoRoute(
        path: '/report/:sessionId/analysis',
        name: 'analysisReport',
        builder: (context, state) {
          final sessionId = state.pathParameters['sessionId']!;
          return AnalysisReportScreen(sessionId: sessionId);
        },
      ),
      GoRoute(
        path: '/report/:sessionId/metric/:metricType',
        name: 'metricDetail',
        builder: (context, state) {
          final sessionId = state.pathParameters['sessionId']!;
          final metricName = state.pathParameters['metricType']!;
          final metricType = MetricType.values.byName(metricName);
          return MetricDetailScreen(
            sessionId: sessionId,
            metricType: metricType,
          );
        },
      ),
      GoRoute(
        path: '/report/:sessionId/highlight',
        name: 'highlightFeedback',
        builder: (context, state) {
          final sessionId = state.pathParameters['sessionId']!;
          return HighlightFeedbackScreen(sessionId: sessionId);
        },
      ),
    ],
  );
});

/// AuthState 변화를 go_router에 알리기 위한 어댑터.
class _AuthChangeNotifier extends ChangeNotifier {
  _AuthChangeNotifier(this._ref) {
    _sub = _ref.listen<AuthState>(
      authViewModelProvider,
      (_, __) => notifyListeners(),
    );
  }

  final Ref _ref;
  late final ProviderSubscription<AuthState> _sub;

  @override
  void dispose() {
    _sub.close();
    super.dispose();
  }
}
