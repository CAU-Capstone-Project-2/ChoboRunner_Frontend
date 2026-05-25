import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../auth/viewmodel/auth_viewmodel.dart';
import '../model/report_api_service.dart';
import '../model/report_session.dart';

final reportListProvider = FutureProvider<List<ReportSession>>((ref) async {
  final userId = ref.read(authViewModelProvider).userId;
  if (userId == null) return [];

  final api = ReportApiService();
  final runs = await api.getRunsByUser(userId);

  final sessions = runs
      .map((json) => ReportSession.fromJson(json))
      .where((s) => s.status == 'DONE')
      .toList()
    ..sort((a, b) => b.date.compareTo(a.date));

  return sessions;
});
