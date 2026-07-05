import 'package:get/get.dart';

import '../models/app_settings.dart';
import '../services/settings_service.dart';

class SettingsController extends GetxController {
  SettingsController({SettingsService? settingsService})
      : _settingsService = settingsService ?? SettingsService();

  final SettingsService _settingsService;

  final parallelExecutionEnabled = false.obs;

  /// True only while a pipeline run is actively using parallel mode.
  final isParallelRunActive = false.obs;

  final isLoading = true.obs;

  static const String parallelExecutionTooltip =
      'Runs independent pipeline branches at the same time when their '
      'upstream dependencies are satisfied. Nodes that depend on each other '
      'still run in order. Uses your local Docker daemon — great for fan-out '
      'workflows like running the same tool on multiple inputs.';

  @override
  void onInit() {
    super.onInit();
    _loadSettings();
  }

  Future<void> _loadSettings() async {
    isLoading.value = true;
    final settings = await _settingsService.load();
    parallelExecutionEnabled.value = settings.parallelExecutionEnabled;
    isLoading.value = false;
  }

  Future<void> setParallelExecutionEnabled(bool enabled) async {
    final previous = parallelExecutionEnabled.value;
    parallelExecutionEnabled.value = enabled;
    try {
      final current = await _settingsService.load();
      await _settingsService.save(
        current.copyWith(parallelExecutionEnabled: enabled),
      );
    } catch (_) {
      parallelExecutionEnabled.value = previous;
      rethrow;
    }
  }

  void setParallelRunActive(bool active) {
    isParallelRunActive.value = active;
  }
}
