import 'dart:convert';
import 'dart:io';

import 'package:path/path.dart' as path;

import '../models/app_settings.dart';
import 'workspace_service.dart';

/// Persists app-wide preferences under the Ricochet workspace directory.
class SettingsService {
  static const String _settingsFileName = 'settings.json';

  final WorkspaceService _workspaceService;

  SettingsService({WorkspaceService? workspaceService})
      : _workspaceService = workspaceService ?? WorkspaceService();

  Future<File> _settingsFile() async {
    final workspace = await _workspaceService.getWorkspaceDirectory();
    return File(path.join(workspace.path, _settingsFileName));
  }

  Future<AppSettings> load() async {
    try {
      final file = await _settingsFile();
      if (!await file.exists()) return const AppSettings();

      final raw = await file.readAsString();
      if (raw.trim().isEmpty) return const AppSettings();

      final json = jsonDecode(raw);
      if (json is! Map<String, dynamic>) return const AppSettings();
      return AppSettings.fromJson(json);
    } catch (_) {
      return const AppSettings();
    }
  }

  Future<void> save(AppSettings settings) async {
    final file = await _settingsFile();
    await file.writeAsString(
      const JsonEncoder.withIndent('  ').convert(settings.toJson()),
    );
  }
}
