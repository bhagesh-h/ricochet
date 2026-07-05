import 'dart:io';

/// Docker system information
class DockerInfo {
  final String version;
  final String serverVersion;
  final String operatingSystem;
  final String architecture;
  final bool isRunning;
  final int containers;
  final int images;
  final DateTime checkedAt;

  DockerInfo({
    required this.version,
    required this.serverVersion,
    required this.operatingSystem,
    required this.architecture,
    required this.isRunning,
    required this.containers,
    required this.images,
    required this.checkedAt,
  });

  factory DockerInfo.fromDockerInfoOutput(String output) {
    // Parse docker info output
    final lines = output.split('\n');
    String version = 'Unknown';
    String serverVersion = 'Unknown';
    String os = 'Unknown';
    String arch = 'Unknown';
    int containers = 0;
    int images = 0;

    for (var line in lines) {
      if (line.contains('Server Version:')) {
        serverVersion = line.split(':').last.trim();
      } else if (line.contains('Operating System:')) {
        os = line.split(':').last.trim();
      } else if (line.contains('Architecture:')) {
        arch = line.split(':').last.trim();
      } else if (line.contains('Containers:')) {
        containers = int.tryParse(line.split(':').last.trim()) ?? 0;
      } else if (line.contains('Images:')) {
        images = int.tryParse(line.split(':').last.trim()) ?? 0;
      }
    }

    return DockerInfo(
      version: version,
      serverVersion: serverVersion,
      operatingSystem: os,
      architecture: arch,
      isRunning: true,
      containers: containers,
      images: images,
      checkedAt: DateTime.now(),
    );
  }

  String get statusMessage {
    if (!isRunning) return 'Docker is not running';
    return 'Docker $serverVersion is running';
  }

  String get detailsMessage {
    return '$containers containers, $images images';
  }
}

/// Platform-specific information
class PlatformInfo {
  final bool isMacOS;
  final bool isWindows;
  final bool isLinux;
  final bool isAppleSilicon;
  final String architecture;
  final String osVersion;

  PlatformInfo({
    required this.isMacOS,
    required this.isWindows,
    required this.isLinux,
    required this.isAppleSilicon,
    required this.architecture,
    required this.osVersion,
  });

  static Future<PlatformInfo> detect() async {
    final isMacOS = Platform.isMacOS;
    final isWindows = Platform.isWindows;
    final isLinux = Platform.isLinux;

    String arch = 'unknown';
    bool isAppleSilicon = false;

    if (isMacOS || isLinux) {
      try {
        final result = await Process.run('uname', ['-m']);
        if (result.exitCode == 0) {
          arch = normalizeArchitecture(result.stdout.toString().trim());
          isAppleSilicon =
              isMacOS && isArmArchitecture(arch);
        }
      } catch (_) {
        arch = 'unknown';
      }
    } else if (isWindows) {
      arch = detectWindowsArchitecture(Platform.environment);
    }

    return PlatformInfo(
      isMacOS: isMacOS,
      isWindows: isWindows,
      isLinux: isLinux,
      isAppleSilicon: isAppleSilicon,
      architecture: arch,
      osVersion: Platform.operatingSystemVersion,
    );
  }

  /// Normalizes architecture strings from `uname`, Docker, or Windows env vars.
  static String normalizeArchitecture(String raw) {
    final value = raw.trim().toLowerCase();
    if (value == 'amd64' || value == 'x86_64') return 'x86_64';
    if (value == 'aarch64' || value == 'arm64') return 'arm64';
    return value.isEmpty ? 'unknown' : value;
  }

  static bool isArmArchitecture(String architecture) {
    final normalized = normalizeArchitecture(architecture);
    return normalized == 'arm64';
  }

  /// Reads Windows env vars so Intel/AMD and ARM64 hosts are detected correctly.
  static String detectWindowsArchitecture(Map<String, String> environment) {
    final arch = environment['PROCESSOR_ARCHITECTURE']?.toUpperCase();
    final wow64 = environment['PROCESSOR_ARCHITEW6432']?.toUpperCase();

    if (arch == 'ARM64') return 'arm64';
    if (arch == 'AMD64' || wow64 == 'AMD64') return 'x86_64';
    if (arch == 'X86') return 'x86';
    return normalizeArchitecture(arch ?? 'unknown');
  }

  String get platformName {
    if (isMacOS) return 'macOS';
    if (isWindows) return 'Windows';
    if (isLinux) return 'Linux';
    return 'Unknown';
  }

  String get architectureDisplay {
    if (isAppleSilicon) return 'Apple Silicon (ARM64)';
    if (isWindowsArm) return 'Windows on ARM (ARM64)';
    if (isArmArchitecture(architecture)) return 'ARM64';
    if (architecture == 'x86_64') return 'x86_64';
    return architecture;
  }

  bool get isWindowsArm => isWindows && isArmArchitecture(architecture);

  /// Whether we need to pass an explicit --platform flag to Docker.
  /// - Apple Silicon and Windows on ARM: most bioinformatics images are amd64-only,
  ///   so we request linux/amd64 and Docker emulates it.
  /// - ARM64 Linux (e.g. Raspberry Pi, AWS Graviton): native arm64 images
  ///   exist for many tools; we request linux/arm64 to avoid emulation.
  /// - x86_64 on macOS, Windows, or Linux: no emulation needed — native amd64 containers.
  bool get needsPlatformEmulation =>
      isAppleSilicon || isWindowsArm || _isArmLinux;

  bool get _isArmLinux =>
      isLinux && isArmArchitecture(architecture);

  /// Platform flag sent to Docker via --platform.
  String get dockerPlatformFlag {
    if (isAppleSilicon || isWindowsArm) {
      // Request amd64 images so the broadest set of bioinformatics tools works
      // (emulated by Docker Desktop on Apple Silicon or Windows on ARM).
      return 'linux/amd64';
    }
    if (_isArmLinux) {
      // Native ARM64 Linux: prefer arm64 images to avoid emulation penalties.
      return 'linux/arm64';
    }
    // Default: x86_64 on macOS, Windows, Linux.
    return 'linux/amd64';
  }
}

/// Docker health status
enum DockerStatus {
  running, // Docker daemon is running
  stopped, // Docker is installed but daemon is stopped
  notInstalled, // Docker is not installed
  checking, // Currently checking status
  error, // Error occurred during check
}

extension DockerStatusExtension on DockerStatus {
  String get displayName {
    switch (this) {
      case DockerStatus.running:
        return 'Running';
      case DockerStatus.stopped:
        return 'Stopped';
      case DockerStatus.notInstalled:
        return 'Not Installed';
      case DockerStatus.checking:
        return 'Checking...';
      case DockerStatus.error:
        return 'Error';
    }
  }

  String get userMessage {
    switch (this) {
      case DockerStatus.running:
        return 'Docker is running and ready';
      case DockerStatus.stopped:
        return 'Docker is installed but not running. Please start Docker Desktop.';
      case DockerStatus.notInstalled:
        return 'Docker is not installed. Please install Docker Desktop to execute pipelines.';
      case DockerStatus.checking:
        return 'Checking Docker status...';
      case DockerStatus.error:
        return 'Failed to check Docker status. Please ensure Docker is properly installed.';
    }
  }
}
