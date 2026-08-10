import 'package:flutter_test/flutter_test.dart';
import 'package:get/get.dart';

import 'package:Ricochet/controllers/settings_controller.dart';
import 'package:Ricochet/models/app_settings.dart';
import 'package:Ricochet/services/settings_service.dart';
import 'package:Ricochet/services/system_resource_service.dart';

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
    fakeService.stored = const AppSettings(
      parallelExecutionEnabled: true,
      maxParallelJobs: 4,
    );
    controller.onInit();
    await Future<void>.delayed(Duration.zero);
    expect(controller.parallelExecutionEnabled.value, isTrue);
    expect(controller.maxParallelJobs.value, 4);
  });

  test('setMaxParallelJobs persists and updates effective cap', () async {
    fakeService.stored = const AppSettings(parallelExecutionEnabled: true);
    final controllerWithCap = SettingsController(
      settingsService: fakeService,
      systemResourceService: SystemResourceService(logicalProcessorOverride: 4),
    );
    controllerWithCap.parallelExecutionEnabled.value = true;
    await controllerWithCap.setMaxParallelJobs(8);
    expect(controllerWithCap.maxParallelJobs.value, 8);
    expect(fakeService.stored.maxParallelJobs, 8);
    expect(fakeService.stored.parallelExecutionEnabled, isTrue);
    expect(controllerWithCap.effectiveParallelCap.value, 3);
  });

  test('resolveRuntimeParallelLimit refreshes from system capacity', () {
    final controllerWithCap = SettingsController(
      settingsService: fakeService,
      systemResourceService: SystemResourceService(logicalProcessorOverride: 6),
    );
    controllerWithCap.maxParallelJobs.value = 5;
    expect(controllerWithCap.resolveRuntimeParallelLimit(), 5);
  });

  test('setParallelExecutionEnabled persists and updates observable', () async {
    await controller.setParallelExecutionEnabled(true);
    expect(controller.parallelExecutionEnabled.value, isTrue);
    expect(fakeService.stored.parallelExecutionEnabled, isTrue);
  });

  test('beginParallelRun tracks active parallel runs per tab', () {
    controller.beginParallelRun('tab-a');
    expect(controller.isParallelRunActive.value, isTrue);
    controller.beginParallelRun('tab-b');
    expect(controller.isParallelRunActive.value, isTrue);
    controller.endParallelRun('tab-a');
    expect(controller.isParallelRunActive.value, isTrue);
    controller.endParallelRun('tab-b');
    expect(controller.isParallelRunActive.value, isFalse);
  });
}
