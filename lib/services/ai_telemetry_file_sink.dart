import 'dart:convert';
import 'dart:io';

import 'workspace_service.dart';

/// Appends allow-listed telemetry events to a local JSONL file (opt-in only).
class AiTelemetryFileSink {
  AiTelemetryFileSink({WorkspaceService? workspaceService})
      : _workspaceService = workspaceService ?? WorkspaceService();

  final WorkspaceService _workspaceService;

  void record(String event, Map<String, Object?> properties) {
    // Fire-and-forget — telemetry must never block UI.
    _append(event, properties);
  }

  Future<void> _append(String event, Map<String, Object?> properties) async {
    try {
      final dir = await _workspaceService.getWorkspaceDirectory();
      final file = File('$dir/ai_telemetry.jsonl');
      final payload = jsonEncode({
        'event': event,
        'ts': DateTime.now().toUtc().toIso8601String(),
        ...properties,
      });
      await file.writeAsString('$payload\n', mode: FileMode.append, flush: true);
    } catch (_) {
      // Never surface telemetry failures to the user.
    }
  }
}
