import 'package:flutter_test/flutter_test.dart';
import 'package:get/get.dart';

import 'package:Ricochet/controllers/settings_controller.dart';
import 'package:Ricochet/models/app_settings.dart';
import 'package:Ricochet/services/settings_service.dart';

class _FakeSettingsService extends SettingsService {
  AppSettings stored = const AppSettings();

  _FakeSettingsService() : super();

  @override
  Future<AppSettings> load() async => stored;

  @override
  Future<void> save(AppSettings settings) async {
    stored = settings;
  }
}

void main() {
  late _FakeSettingsService fakeService;
  late SettingsController controller;

  setUp(() {
    Get.testMode = true;
    fakeService = _FakeSettingsService();
    controller = SettingsController(settingsService: fakeService);
  });

  tearDown(() => Get.deleteAll(force: true));

  test('loads persisted parallel execution setting on init', () async {
    fakeService.stored = const AppSettings(parallelExecutionEnabled: true);
    controller.onInit();
    await Future<void>.delayed(Duration.zero);
    expect(controller.parallelExecutionEnabled.value, isTrue);
  });

  test('setParallelExecutionEnabled persists and updates observable', () async {
    await controller.setParallelExecutionEnabled(true);
    expect(controller.parallelExecutionEnabled.value, isTrue);
    expect(fakeService.stored.parallelExecutionEnabled, isTrue);
  });

  test('setParallelRunActive tracks active parallel runs', () {
    controller.setParallelRunActive(true);
    expect(controller.isParallelRunActive.value, isTrue);
    controller.setParallelRunActive(false);
    expect(controller.isParallelRunActive.value, isFalse);
  });
}
