import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:workmanager/workmanager.dart';

import 'core/background/overlay_upload_task.dart';
import 'core/router/app_router.dart';
import 'core/theme/app_colors.dart';
import 'core/tts/tts_provider.dart';

@pragma('vm:entry-point')
void callbackDispatcher() {
  Workmanager().executeTask((taskName, inputData) async {
    if (taskName == kOverlayUploadTaskName) {
      return await executeOverlayUpload();
    }
    return true;
  });
}

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await SystemChrome.setPreferredOrientations([DeviceOrientation.portraitUp]);
  Workmanager().initialize(callbackDispatcher);
  runApp(const ProviderScope(child: ChoboRunnerApp()));
}

class ChoboRunnerApp extends ConsumerWidget {
  const ChoboRunnerApp({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final router = ref.watch(routerProvider);
    // 앱 시작 시 TTS 초기화 트리거 (결과는 무시 — 실패해도 앱은 동작)
    ref.watch(ttsInitProvider);

    return MaterialApp.router(
      title: 'ChoboRunner',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        useMaterial3: true,
        brightness: Brightness.dark,
        scaffoldBackgroundColor: AppColors.background,
        colorScheme: ColorScheme.fromSeed(
          seedColor: AppColors.primaryAction,
          brightness: Brightness.dark,
        ),
      ),
      routerConfig: router,
    );
  }
}
