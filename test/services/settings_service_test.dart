import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:path/path.dart' as path;

import 'package:Ricochet/models/app_settings.dart';
import 'package:Ricochet/services/settings_service.dart';
import 'package:Ricochet/services/workspace_service.dart';
import '../helpers/test_workspace_factory.dart';

void main() {
  late Directory tempDir;
  late SettingsService service;

  setUp(() async {
    tempDir = await TestWorkspaceFactory.create();
    service = SettingsService(
      workspaceService: WorkspaceService.withPath(tempDir.path),
    );
  });

  tearDown(() async {
    if (await tempDir.exists()) {
      await tempDir.delete(recursive: true);
    }
  });

  test('load returns defaults when settings file is missing', () async {
    final settings = await service.load();
    expect(settings.parallelExecutionEnabled, isFalse);
  });

  test('save and load round-trip parallel execution flag', () async {
    await service.save(const AppSettings(parallelExecutionEnabled: true));
    final loaded = await service.load();
    expect(loaded.parallelExecutionEnabled, isTrue);
  });

  test('settings file is stored under Ricochet workspace', () async {
    await service.save(const AppSettings(parallelExecutionEnabled: true));
    final file = File(path.join(tempDir.path, 'Ricochet', 'settings.json'));
    expect(await file.exists(), isTrue);
  });
}
