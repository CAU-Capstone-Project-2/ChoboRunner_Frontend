import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'core/router/app_router.dart';
import 'core/theme/app_colors.dart';

void main() {
  runApp(const ProviderScope(child: ChoboRunnerApp()));
}

class ChoboRunnerApp extends ConsumerWidget {
  const ChoboRunnerApp({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final router = ref.watch(routerProvider);

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
