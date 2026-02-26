import 'dart:async';
import 'package:get/get.dart';
import '../models/docker_info.dart';
import '../services/docker_service.dart';

/// Controller for managing Docker state and health checks
class DockerController extends GetxController {
  final DockerService _dockerService = DockerService();

  // Observable state
  var status = DockerStatus.checking.obs;
  var dockerInfo = Rxn<DockerInfo>();
  var platformInfo = Rxn<PlatformInfo>();
  var errorMessage = ''.obs;
  var lastCheckTime = Rxn<DateTime>();
  var isChecking = false.obs;

  // Periodic check timer
  Timer? _healthCheckTimer;
  static const Duration _checkInterval = Duration(seconds: 30);

  @override
  void onInit() {
    super.onInit();
    // Initial check on startup
    checkDockerStatus();
    // Start periodic health checks
    startPeriodicHealthCheck();
    // Load platform info
    _loadPlatformInfo();
  }

  @override
  void onClose() {
    _healthCheckTimer?.cancel();
    super.onClose();
  }

  /// Load platform information
  Future<void> _loadPlatformInfo() async {
    try {
      final info = await _dockerService.getPlatformInfo();
      platformInfo.value = info;
    } catch (e) {
      print('Error loading platform info: $e');
    }
  }

  /// Check Docker status
  Future<void> checkDockerStatus() async {
    if (isChecking.value) return; // Prevent concurrent checks

    isChecking.value = true;
    errorMessage.value = '';

    try {
      // Get Docker status
      final dockerStatus = await _dockerService.getDockerStatus();
      print(dockerStatus);
      status.value = dockerStatus;
      lastCheckTime.value = DateTime.now();

      // If Docker is running, get detailed info
      if (dockerStatus == DockerStatus.running) {
        final info = await _dockerService.getDockerInfo();
        dockerInfo.value = info;
      } else {
        dockerInfo.value = null;
      }
    } catch (e) {
      status.value = DockerStatus.error;
      errorMessage.value = 'Failed to check Docker: ${e.toString()}';
      print('Error checking Docker status: $e');
    } finally {
      isChecking.value = false;
    }
  }

  /// Start periodic health checks
  void startPeriodicHealthCheck() {
    _healthCheckTimer?.cancel();
    _healthCheckTimer = Timer.periodic(_checkInterval, (_) {
      checkDockerStatus();
    });
  }

  /// Stop periodic health checks
  void stopPeriodicHealthCheck() {
    _healthCheckTimer?.cancel();
  }

  /// Manually retry Docker connection
  Future<void> retryConnection() async {
    await checkDockerStatus();
  }

  /// Get user-friendly status message
  String get statusMessage {
    if (dockerInfo.value != null) {
      return dockerInfo.value!.statusMessage;
    }
    return status.value.userMessage;
  }

  /// Get detailed status message
  String get detailsMessage {
    if (dockerInfo.value != null) {
      return dockerInfo.value!.detailsMessage;
    }
    return '';
  }

  /// Check if Docker is ready for execution
  bool get isReady => status.value == DockerStatus.running;

  /// Get platform-specific help message
  String get helpMessage {
    switch (status.value) {
      case DockerStatus.notInstalled:
        return _dockerService.getInstallationHelpMessage();
      case DockerStatus.stopped:
        return _dockerService.getStartDockerHelpMessage();
      case DockerStatus.error:
        return 'Please check your Docker installation and try again.';
      default:
        return '';
    }
  }

  /// Get Docker Desktop download URL
  String get downloadUrl => _dockerService.getDockerDesktopDownloadUrl();

  /// Check if running on Apple Silicon
  bool get isAppleSilicon => platformInfo.value?.isAppleSilicon ?? false;

  /// Get platform display name
  String get platformName => platformInfo.value?.platformName ?? 'Unknown';

  /// Get architecture display name
  String get architectureName =>
      platformInfo.value?.architectureDisplay ?? 'Unknown';

  /// Show Apple Silicon notice
  bool get shouldShowAppleSiliconNotice =>
      isAppleSilicon && status.value == DockerStatus.running;

  /// Get Apple Silicon notice message
  String get appleSiliconNotice =>
      'Running on Apple Silicon. x86-only Docker images will use Rosetta 2 emulation.';
}
