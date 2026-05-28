import 'dart:convert';
import 'dart:io';

import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';
import 'package:workmanager/workmanager.dart';

import '../api/api_config.dart';

const String kOverlayUploadTaskName = 'overlay_upload';
const String _prefKey = 'pending_overlay_uploads';

class OverlayUploadParams {
  final String runSessionId;
  final String filePath;

  const OverlayUploadParams({
    required this.runSessionId,
    required this.filePath,
  });

  Map<String, dynamic> toJson() => {
        'runSessionId': runSessionId,
        'filePath': filePath,
      };

  factory OverlayUploadParams.fromJson(Map<String, dynamic> json) =>
      OverlayUploadParams(
        runSessionId: json['runSessionId'] as String,
        filePath: json['filePath'] as String,
      );
}

Future<void> enqueueOverlayUpload(OverlayUploadParams params) async {
  final prefs = await SharedPreferences.getInstance();
  final pending = prefs.getStringList(_prefKey) ?? [];
  pending.add(jsonEncode(params.toJson()));
  await prefs.setStringList(_prefKey, pending);

  await Workmanager().registerOneOffTask(
    'overlay_${params.runSessionId}',
    kOverlayUploadTaskName,
    constraints: Constraints(networkType: NetworkType.connected),
    backoffPolicy: BackoffPolicy.exponential,
    existingWorkPolicy: ExistingWorkPolicy.keep,
  );
}

Future<bool> executeOverlayUpload() async {
  final prefs = await SharedPreferences.getInstance();
  final pending = prefs.getStringList(_prefKey) ?? [];
  if (pending.isEmpty) return true;

  final remaining = <String>[];

  for (final entry in pending) {
    final params = OverlayUploadParams.fromJson(
      jsonDecode(entry) as Map<String, dynamic>,
    );

    final file = File(params.filePath);
    if (!file.existsSync()) continue;

    try {
      final uri = Uri.parse('$kApiBaseUrl/api/analyze/overlay').replace(
        queryParameters: {'RunSessionId': params.runSessionId},
      );
      final request = http.MultipartRequest('POST', uri)
        ..headers.addAll(defaultHeaders())
        ..files.add(await http.MultipartFile.fromPath('video', file.path));

      final streamed = await request.send().timeout(
            const Duration(minutes: 5),
          );
      final res = await http.Response.fromStream(streamed);

      if (res.statusCode == 200) {
        // ignore: avoid_print
        print('[Overlay] background upload success for run=${params.runSessionId}');
        try { await file.delete(); } catch (_) {}
      } else {
        // ignore: avoid_print
        print('[Overlay] background upload failed (${res.statusCode}): ${res.body}');
        remaining.add(entry);
      }
    } catch (e) {
      // ignore: avoid_print
      print('[Overlay] background upload error: $e');
      remaining.add(entry);
    }
  }

  await prefs.setStringList(_prefKey, remaining);
  return remaining.isEmpty;
}
