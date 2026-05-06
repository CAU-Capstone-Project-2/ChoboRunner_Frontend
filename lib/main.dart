import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'features/capture/view/capture_measuring_screen.dart';

void main() {
  runApp(const ProviderScope(child: ChoboRunnerApp()));
}

class ChoboRunnerApp extends StatelessWidget {
  const ChoboRunnerApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'ChoboRunner',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        colorScheme: ColorScheme.fromSeed(seedColor: Colors.deepPurple),
        useMaterial3: true,
      ),
      // 임시: WebSocket 동작 검증을 위해 측정 화면을 첫 화면으로 설정.
      // 추후 GoRouter 적용 시 정식 라우팅으로 교체할 것.
      home: const CaptureMeasuringScreen(),
    );
  }
}
