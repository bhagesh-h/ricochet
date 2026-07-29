import 'dart:io';
import 'dart:math';

import '../models/app_settings.dart';

/// Reads host CPU capacity and resolves safe parallel job limits.
///
/// Uses [Platform.numberOfProcessors], which is supported on macOS, Windows,
/// and Linux — no platform-specific shell commands required.
class SystemResourceService {
  SystemResourceService({int? logicalProcessorOverride})
      : _logicalProcessorOverride = logicalProcessorOverride;

  final int? _logicalProcessorOverride;

  /// Logical processors (threads) reported by the OS (macOS, Windows, Linux).
  int get logicalProcessorCount =>
      _logicalProcessorOverride ?? Platform.numberOfProcessors;

  /// Leave one core for the OS, Docker daemon, and Ricochet UI.
  int recommendedParallelCap({int reserveCores = 1}) {
    final cores = logicalProcessorCount;
    if (cores <= 1) return 1;
    return max(1, cores - reserveCores);
  }

  /// Applies the user's setting and never exceeds what the machine can handle.
  int resolveEffectiveParallelism(int userRequested, {int reserveCores = 1}) {
    final clampedUser = userRequested.clamp(
      AppSettings.minMaxParallelJobs,
      AppSettings.maxMaxParallelJobs,
    );
    final systemCap = recommendedParallelCap(reserveCores: reserveCores);
    return min(clampedUser, systemCap);
  }
}
