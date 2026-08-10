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

  static const String parallelExecutionSummary =
      'Run independent branches at the same time when their dependencies '
      'are satisfied. Nodes that depend on each other still run in order.';

  static String parallelExecutionPlatformNote(String platform) =>
      'Requires Docker Desktop on $platform. Concurrent containers are '
      'capped by your max-jobs setting and CPU threads.';

  static const String maxParallelJobsSummary =
      'Maximum Docker containers Ricochet runs at once during a parallel '
      'wave. Automatically reduced if your CPU cannot safely support more.';

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

  Future<void> _saveParallelSettings(AppSettings Function(AppSettings) merge) async {
    final current = await _settingsService.load();
    await _settingsService.save(merge(current));
  }

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
      await _saveParallelSettings(
        (current) => current.copyWith(parallelExecutionEnabled: enabled),
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
      await _saveParallelSettings(
        (current) => current.copyWith(maxParallelJobs: clamped),
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
