import 'package:get/get.dart';

import '../models/app_settings.dart';
import '../services/settings_service.dart';
import '../services/system_resource_service.dart';

class SettingsController extends GetxController {
  SettingsController({
    SettingsService? settingsService,
    SystemResourceService? systemResourceService,
  })  : _settingsService = settingsService ?? SettingsService(),
        _systemResourceService =
            systemResourceService ?? SystemResourceService();

  final SettingsService _settingsService;
  final SystemResourceService _systemResourceService;

  final parallelExecutionEnabled = false.obs;
  final maxParallelJobs = AppSettings.defaultMaxParallelJobs.obs;
  final logicalProcessorCount = 1.obs;
  final effectiveParallelCap = AppSettings.defaultMaxParallelJobs.obs;

  /// True while any tab is running a pipeline with parallel execution enabled.
  final isParallelRunActive = false.obs;

  final isLoading = true.obs;
  final Set<String> _activeParallelRunTabs = {};

  static const String parallelExecutionTooltip =
      'Runs independent pipeline branches at the same time when their '
      'upstream dependencies are satisfied. Nodes that depend on each other '
      'still run in order. Ricochet limits concurrent Docker containers based '
      'on your setting and this machine\'s CPU threads. Works with Docker '
      'Desktop on macOS and Windows.';

  static const String maxParallelJobsTooltip =
      'Maximum Docker containers Ricochet will run at once during a parallel '
      'wave. Default is 2. The limit is automatically reduced if your CPU '
      'cannot safely support more.';

  @override
  void onInit() {
    super.onInit();
    _refreshSystemCapacity();
    _loadSettings();
  }

  void _refreshSystemCapacity() {
    logicalProcessorCount.value = _systemResourceService.logicalProcessorCount;
    _refreshEffectiveCap();
  }

  void _refreshEffectiveCap() {
    effectiveParallelCap.value = _systemResourceService.resolveEffectiveParallelism(
      maxParallelJobs.value,
    );
  }

  int resolveRuntimeParallelLimit() {
    _refreshSystemCapacity();
    return effectiveParallelCap.value;
  }

  AppSettings get _snapshotSettings => AppSettings(
        parallelExecutionEnabled: parallelExecutionEnabled.value,
        maxParallelJobs: maxParallelJobs.value,
      );

  Future<void> _loadSettings() async {
    isLoading.value = true;
    final settings = await _settingsService.load();
    parallelExecutionEnabled.value = settings.parallelExecutionEnabled;
    maxParallelJobs.value = settings.maxParallelJobs;
    _refreshEffectiveCap();
    isLoading.value = false;
  }

  Future<void> setParallelExecutionEnabled(bool enabled) async {
    final previous = parallelExecutionEnabled.value;
    parallelExecutionEnabled.value = enabled;
    try {
      await _settingsService.save(
        _snapshotSettings.copyWith(parallelExecutionEnabled: enabled),
      );
    } catch (_) {
      parallelExecutionEnabled.value = previous;
      rethrow;
    }
  }

  Future<void> setMaxParallelJobs(int value) async {
    final clamped = value.clamp(
      AppSettings.minMaxParallelJobs,
      AppSettings.maxMaxParallelJobs,
    );
    final previous = maxParallelJobs.value;
    maxParallelJobs.value = clamped;
    _refreshEffectiveCap();
    try {
      await _settingsService.save(
        _snapshotSettings.copyWith(maxParallelJobs: clamped),
      );
    } catch (_) {
      maxParallelJobs.value = previous;
      _refreshEffectiveCap();
      rethrow;
    }
  }

  void beginParallelRun(String tabId) {
    _activeParallelRunTabs.add(tabId);
    isParallelRunActive.value = _activeParallelRunTabs.isNotEmpty;
  }

  void endParallelRun(String tabId) {
    _activeParallelRunTabs.remove(tabId);
    isParallelRunActive.value = _activeParallelRunTabs.isNotEmpty;
  }

  int get systemRecommendedCap =>
      _systemResourceService.recommendedParallelCap();
}
