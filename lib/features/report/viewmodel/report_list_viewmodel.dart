import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../auth/viewmodel/auth_viewmodel.dart';
import '../model/report_api_service.dart';
import '../model/report_session.dart';

final reportListProvider = FutureProvider<List<ReportSession>>((ref) async {
  final userId = ref.read(authViewModelProvider).userId;
  if (userId == null) return [];

  final api = ReportApiService();
  final runs = await api.getRunsByUser(userId);

  // status 대신 "분석 리포트가 실제로 존재하는지"로 필터링.
  // updateRunSession PUT 실패로 RUNNING으로 남은 run이라도 reports가 있으면
  // 리스트에 노출, 반대로 status가 DONE이어도 reports가 없으면 숨김.
  // beta 규모(러닝 10건 내외)라 run마다 병렬 GET 1회로 충분.
  final candidates = runs.map(ReportSession.fromJson).toList();
  final hasReport = await Future.wait(
    candidates.map((s) async {
      try {
        final reports = await api.getReportsByRun(s.id);
        return reports.isNotEmpty;
      } catch (_) {
        return false;
      }
    }),
  );

  final sessions = [
    for (var i = 0; i < candidates.length; i++)
      if (hasReport[i]) candidates[i],
  ]..sort((a, b) => b.date.compareTo(a.date));

  return sessions;
});
