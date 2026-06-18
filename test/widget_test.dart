import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:chobo_runner_frontend/main.dart';

void main() {
  testWidgets('ChoboRunnerApp builds without errors', (WidgetTester tester) async {
    await tester.pumpWidget(const ProviderScope(child: ChoboRunnerApp()));
  });
}
