import 'dart:io';
import 'dart:async';
import 'dart:convert';
import 'package:flutter/foundation.dart';
import '../models/docker_info.dart';
import '../models/docker_pull_progress.dart';
import 'process_runner.dart';

/// Service for interacting with Docker CLI
/// Handles platform-specific Docker operations for macOS and Windows
class DockerService {
  // Singleton pattern — kept for backward compatibility with existing controllers.
  // For tests, use [DockerService.withRunner] to obtain an isolated instance.
  static final DockerService _instance = DockerService._internal();
  factory DockerService() => _instance;
  DockerService._internal() : _processRunner = const SystemProcessRunner();

  /// Creates a non-singleton instance with an injected [ProcessRunner].
  ///
  /// Use this in tests to supply a [FakeProcessRunner].
  @visibleForTesting
  DockerService.withRunner(ProcessRunner processRunner)
      : _processRunner = processRunner;

  final ProcessRunner _processRunner;

  PlatformInfo? _platformInfo;
  
  // Track active processes for reliable cleanup
  final Map<String, Process> _activeProcesses = {};

  /// Get platform information (cached)
  Future<PlatformInfo> getPlatformInfo() async {
    _platformInfo ??= await PlatformInfo.detect();
    return _platformInfo!;
  }

  /// Get environment variables for Docker commands.
  ///
  /// - macOS: sandboxed apps need explicit HOME, DOCKER_CONFIG, and DOCKER_HOST
  ///   so they can locate the Docker Desktop socket inside the real home dir.
  /// - Linux: set DOCKER_HOST to the standard system socket so that the app
  ///   can reach the Docker daemon even when the socket path is not in PATH.
  /// - Windows: Docker Desktop with WSL2 exposes a named pipe automatically;
  ///   no extra environment variables are required.
  Map<String, String> get _dockerEnvironment {
    final environment = <String, String>{};

    if (Platform.isMacOS) {
      final home = Platform.environment['HOME'];
      if (home != null) {
        environment['HOME'] = home;

        // Point Docker to the actual config directory (not the sandboxed one).
        // Extract the real home from the sandboxed path.
        final realHome = home.contains('/Library/Containers/')
            ? home.split('/Library/Containers/').first
            : home;

        environment['DOCKER_CONFIG'] = '$realHome/.docker';

        // Directly use the Docker Desktop socket.
        environment['DOCKER_HOST'] = 'unix://$realHome/.docker/run/docker.sock';

        print('🔧 Docker environment (macOS):');
        print('   HOME: $home');
        print('   DOCKER_CONFIG: ${environment['DOCKER_CONFIG']}');
        print('   DOCKER_HOST: ${environment['DOCKER_HOST']}');
      }
    } else if (Platform.isLinux) {
      // Standard Docker daemon socket on Linux.
      // Docker Desktop for Linux may use a different socket under ~/.docker/run/;
      // try the user-scoped one first, then fall back to the system socket.
      final home = Platform.environment['HOME'];
      final userSocket = home != null ? '$home/.docker/run/docker.sock' : null;
      const systemSocket = '/var/run/docker.sock';

      // Prefer the user-scoped Docker Desktop socket if it exists.
      if (userSocket != null && File(userSocket).existsSync()) {
        environment['DOCKER_HOST'] = 'unix://$userSocket';
        print('🔧 Docker environment (Linux): using user-scoped socket');
        print('   DOCKER_HOST: ${environment['DOCKER_HOST']}');
      } else if (File(systemSocket).existsSync()) {
        environment['DOCKER_HOST'] = 'unix://$systemSocket';
        print('🔧 Docker environment (Linux): using system socket');
        print('   DOCKER_HOST: ${environment['DOCKER_HOST']}');
      } else {
        // Neither socket is found — let the docker binary discover it via its
        // own default logic (context / DOCKER_CONTEXT env var).
        print('⚠️ Docker environment (Linux): no socket found, relying on docker binary defaults');
      }
    }
    // Windows: Docker Desktop with WSL2 backend is auto-discovered; no extra vars needed.
    return environment;
  }

  /// Get possible Docker executable paths, ordered by most-likely first per platform.
  List<String> get _possibleDockerPaths {
    if (Platform.isMacOS) {
      return [
        '/usr/local/bin/docker',   // Intel Mac (Docker Desktop / Homebrew)
        '/opt/homebrew/bin/docker', // Apple Silicon Homebrew
        'docker',                  // PATH fallback
      ];
    } else if (Platform.isWindows) {
      return [
        r'C:\Program Files\Docker\Docker\resources\bin\docker.exe', // Docker Desktop default
        'docker.exe',              // PATH fallback
      ];
    } else if (Platform.isLinux) {
      return [
        '/usr/bin/docker',         // apt/dnf/zypper system install
        '/usr/local/bin/docker',   // manual / Docker-convenience-script install
        '/snap/bin/docker',        // Snap install (Ubuntu)
        'docker',                  // PATH fallback
      ];
    }
    return ['docker'];
  }

  /// Find the working Docker executable path
  Future<String?> _findDockerExecutable() async {
    for (final path in _possibleDockerPaths) {
      try {
        final result = await _processRunner.run(
          path,
          ['--version'],
          runInShell: false,
        );
        if (result.exitCode == 0) {
          print('✅ Found Docker at: $path');
          return path;
        }
      } catch (e) {
        // Try next path
        continue;
      }
    }
    print('❌ Docker not found in any of these paths: $_possibleDockerPaths');
    return null;
  }

  /// Get the Docker executable name based on platform
  Future<String?> getDockerExecutablePath() async {
    // Cache the working path
    if (_cachedDockerPath != null) {
      return _cachedDockerPath;
    }
    _cachedDockerPath = await _findDockerExecutable();
    return _cachedDockerPath;
  }

  String? _cachedDockerPath;

  /// Get the Docker executable name based on platform
  String get dockerExecutable {
    if (Platform.isWindows) {
      return 'docker.exe';
    }
    return 'docker';
  }

  /// Check if Docker is installed on the system
  Future<bool> isDockerInstalled() async {
    try {
      final dockerPath = await getDockerExecutablePath();
      if (dockerPath == null) {
        print('❌ Docker executable not found');
        return false;
      }
      print('✅ Docker is installed at: $dockerPath');
      return true;
    } catch (e) {
      print('❌ Error checking Docker installation: $e');
      return false;
    }
  }

  /// Check if Docker daemon is running
  Future<bool> isDockerRunning() async {
    try {
      final dockerPath = await getDockerExecutablePath();
      if (dockerPath == null) {
        print('❌ Docker executable not found');
        return false;
      }

      print('🔍 Checking if Docker daemon is running...');

      final result = await _processRunner.run(
        dockerPath,
        ['info'],
        runInShell: false,
        environment: _dockerEnvironment,
      );

      print('Docker info exit code: ${result.exitCode}');
      if (result.exitCode != 0) {
        print('Docker info stderr: ${result.stderr}');
      }

      return result.exitCode == 0;
    } catch (e) {
      print('❌ Error checking Docker daemon: $e');
      return false;
    }
  }

  /// Get detailed Docker information
  Future<DockerInfo?> getDockerInfo() async {
    try {
      final dockerPath = await getDockerExecutablePath();
      if (dockerPath == null) return null;

      final result = await _processRunner.run(
        dockerPath,
        ['info'],
        runInShell: false,
        environment: _dockerEnvironment,
      );

      if (result.exitCode == 0) {
        final output = result.stdout.toString();
        return DockerInfo.fromDockerInfoOutput(output);
      }
      return null;
    } catch (e) {
      print('Error getting Docker info: $e');
      return null;
    }
  }

  /// Get Docker version
  Future<String?> getDockerVersion() async {
    try {
      final dockerPath = await getDockerExecutablePath();
      if (dockerPath == null) return null;

      final result = await _processRunner.run(
        dockerPath,
        ['--version'],
        runInShell: false,
      );

      if (result.exitCode == 0) {
        final output = result.stdout.toString().trim();
        // Parse version from output like "Docker version 24.0.6, build ed223bc"
        final versionMatch = RegExp(r'version\s+([\d.]+)').firstMatch(output);
        return versionMatch?.group(1);
      }
      return null;
    } catch (e) {
      return null;
    }
  }

  /// Get comprehensive Docker status
  Future<DockerStatus> getDockerStatus() async {
    try {
      // First check if Docker is installed
      final isInstalled = await isDockerInstalled();
      if (!isInstalled) {
        return DockerStatus.notInstalled;
      }

      // Then check if daemon is running
      final isRunning = await isDockerRunning();
      if (!isRunning) {
        return DockerStatus.stopped;
      }

      return DockerStatus.running;
    } catch (e) {
      print('Error checking Docker status: $e');
      return DockerStatus.error;
    }
  }

  /// Check if a Docker image exists locally
  Future<bool> imageExists(String imageName) async {
    try {
      final dockerPath = await getDockerExecutablePath();
      if (dockerPath == null) return false;

      final result = await _processRunner.run(
        dockerPath,
        ['images', '-q', imageName],
        runInShell: false,
      );

      if (result.exitCode == 0) {
        final output = result.stdout.toString().trim();
        return output.isNotEmpty;
      }
      return false;
    } catch (e) {
      print('Error checking image existence: $e');
      return false;
    }
  }

  /// Get list of local Docker images
  Future<List<String>> listLocalImages() async {
    try {
      final dockerPath = await getDockerExecutablePath();
      if (dockerPath == null) return [];

      final result = await _processRunner.run(
        dockerPath,
        ['images', '--format', '{{.Repository}}:{{.Tag}}'],
        runInShell: false,
      );

      if (result.exitCode == 0) {
        final output = result.stdout.toString();
        return output
            .split('\n')
            .where((line) => line.trim().isNotEmpty)
            .toList();
      }
      return [];
    } catch (e) {
      print('Error listing images: $e');
      return [];
    }
  }

  /// Pull a Docker image with progress streaming
  /// Returns a stream of progress updates
  Stream<DockerPullProgress> pullImage(String imageName) async* {
    print('📥 Starting pull for image: $imageName');

    yield DockerPullProgress.starting(imageName);

    try {
      final dockerPath = await getDockerExecutablePath();
      if (dockerPath == null) {
        yield DockerPullProgress.error(
            imageName, 'Docker executable not found');
        return;
      }

      // Start the pull process
      final process = await _processRunner.start(
        dockerPath,
        ['pull', imageName],
        runInShell: false,
        environment: _dockerEnvironment,
      );

      // Register process for cancellation
      _activeProcesses['pull:$imageName'] = process;

      // Track layers for overall progress
      final Map<String, double> layerProgress = {};
      final Set<String> knownLayers = {};

      // Listen to stdout with line buffering
      await for (final line in process.stdout
          .transform(utf8.decoder)
          .transform(const LineSplitter())) {
        // Parse the line and yield progress
        final progress =
            _parseDockerPullLine(imageName, line, layerProgress, knownLayers);
        if (progress != null) {
          yield progress;
        }
      }

      // Cleanup
      _activeProcesses.remove('pull:$imageName');

      // Wait for process to complete
      final exitCode = await process.exitCode;
      print('📥 Pull completed with exit code: $exitCode');

      if (exitCode == 0) {
        yield DockerPullProgress.complete(imageName);
      } else {
        // Read stderr for error message
        final stderr = await process.stderr.transform(utf8.decoder).join();
        yield DockerPullProgress.error(imageName, stderr);
      }
    } catch (e) {
      print('❌ Error pulling image: $e');
      yield DockerPullProgress.error(imageName, e.toString());
    }
  }

  /// Parse a single line of Docker pull output
  DockerPullProgress? _parseDockerPullLine(
    String imageName,
    String line,
    Map<String, double> layerProgress,
    Set<String> knownLayers,
  ) {
    // Regex patterns
    final layerIdPattern = RegExp(r'^([a-f0-9]{12}|[a-f0-9]+):');
    final downloadPattern =
        RegExp(r'Downloading\s+\[([=>\s]+)\]\s+(\d+\.?\d*\w+)/(\d+\.?\d*\w+)');
    final extractPattern =
        RegExp(r'Extracting\s+\[([=>\s]+)\]\s+(\d+\.?\d*\w+)/(\d+\.?\d*\w+)');
    final statusPattern = RegExp(r'^Status:\s+(.+)');

    // Check for layer ID at start of line
    final layerMatch = layerIdPattern.firstMatch(line);
    if (layerMatch != null) {
      final layerId = layerMatch.group(1)!;
      knownLayers.add(layerId);

      // Handle different states
      if (line.contains('Pulling fs layer') || line.contains('Waiting')) {
        layerProgress[layerId] = 0.0;
        return DockerPullProgress.downloading(
          imageName: imageName,
          layerId: layerId,
          percentage:
              _calculateOverallProgress(layerProgress, knownLayers.length),
        );
      }

      if (line.contains('Verifying Checksum') ||
          line.contains('Download complete')) {
        layerProgress[layerId] = 1.0; // Download complete
        return DockerPullProgress.downloading(
          imageName: imageName,
          layerId: layerId,
          percentage:
              _calculateOverallProgress(layerProgress, knownLayers.length),
        );
      }

      if (line.contains('Pull complete')) {
        layerProgress[layerId] = 1.0; // Extract complete
        return DockerPullProgress.extracting(
          imageName: imageName,
          layerId: layerId,
          percentage:
              _calculateOverallProgress(layerProgress, knownLayers.length),
        );
      }

      // Handle Downloading progress bar
      final downloadMatch = downloadPattern.firstMatch(line);
      if (downloadMatch != null) {
        final progressBar = downloadMatch.group(1)!;
        final current = downloadMatch.group(2)!;
        final total = downloadMatch.group(3)!;

        final percentage = _calculateProgressFromBar(progressBar);
        layerProgress[layerId] = percentage;

        return DockerPullProgress.downloading(
          imageName: imageName,
          layerId: layerId,
          currentBytes: _parseBytes(current),
          totalBytes: _parseBytes(total),
          percentage:
              _calculateOverallProgress(layerProgress, knownLayers.length),
        );
      }

      // Handle Extracting progress bar
      final extractMatch = extractPattern.firstMatch(line);
      if (extractMatch != null) {
        // Extracting is the second phase — treat as 100% downloaded
        layerProgress[layerId] = 1.0;

        return DockerPullProgress.extracting(
          imageName: imageName,
          layerId: layerId,
          percentage:
              _calculateOverallProgress(layerProgress, knownLayers.length),
        );
      }
    }

    // Handle Status messages
    final statusMatch = statusPattern.firstMatch(line);
    if (statusMatch != null) {
      final status = statusMatch.group(1)!;
      if (status.contains('Downloaded newer image') ||
          status.contains('Image is up to date')) {
        return DockerPullProgress.complete(imageName);
      }
    }

    return null;
  }

  /// Calculate progress percentage from Docker's progress bar
  /// Example: "[==>     ]" -> 0.25
  double _calculateProgressFromBar(String bar) {
    final filled = bar.split('').where((c) => c == '=' || c == '>').length;
    final total = bar.length;
    return total > 0 ? filled / total : 0.0;
  }

  /// Run a Docker container
  /// Returns a Process object to control the container
  Future<Process> runContainer({
    required String image,
    String? containerName,
    String? platform,
    List<String> command = const [],
    List<String> volumes = const [],
    List<String> environment = const [],
    List<String> ports = const [],
  }) async {
    final dockerPath = await getDockerExecutablePath();
    if (dockerPath == null) {
      throw Exception('Docker executable not found');
    }

    // Do NOT pass -i (--interactive) — it keeps stdin open and causes tools
    // that read stdin (like fastqc with no file arg) to hang indefinitely.
    // Bioinformatics tools operating on mounted files never need stdin.
    final args = ['run', '--rm'];

    // Add platform flag if needed (fix #1.1)
    if (platform != null && platform.isNotEmpty) {
      args.addAll(['--platform', platform]);
    }

    // Add container name
    if (containerName != null) {
      args.addAll(['--name', containerName]);
    }

    // Add volumes

    // Add volumes
    for (final volume in volumes) {
      args.addAll(['-v', volume]);
    }

    // Add environment variables
    for (final env in environment) {
      args.addAll(['-e', env]);
    }

    // Add ports
    for (final port in ports) {
      args.addAll(['-p', port]);
    }

    // Add image
    args.add(image);

    // Add command
    if (command.isNotEmpty) {
      args.addAll(command);
    }

    print('🚀 Running container: $dockerPath ${args.join(' ')}');

    final process = await _processRunner.start(
      dockerPath,
      args,
      runInShell: false,
      environment: _dockerEnvironment,
    );

    // Register process for cancellation
    if (containerName != null) {
      _activeProcesses['run:$containerName'] = process;
      // Cleanup when process ends
      process.exitCode.then((_) => _activeProcesses.remove('run:$containerName'));
    }

    return process;
  }

  /// Calculate overall progress from all layers
  double _calculateOverallProgress(
      Map<String, double> layerProgress, int totalLayers) {
    if (totalLayers == 0) return 0.0;

    // Sum of progress of all known layers
    double sum = 0.0;
    for (final progress in layerProgress.values) {
      sum += progress;
    }

    return sum / totalLayers;
  }

  /// Stop a running container and its local process handle
  Future<void> stopContainer(String containerName) async {
    final dockerPath = await getDockerExecutablePath();
    
    // 1. Kill the local process handle if tracked
    final runKey = 'run:$containerName';
    if (_activeProcesses.containsKey(runKey)) {
      print('🪓 Killing local process handle for: $containerName');
      _activeProcesses[runKey]!.kill(ProcessSignal.sigkill);
      _activeProcesses.remove(runKey);
    }

    // 2. Kill the Docker container itself via CLI
    if (dockerPath != null) {
      print('🛑 Stopping Docker container via CLI: $containerName');
      await _processRunner.run(
        dockerPath,
        ['kill', containerName],
        runInShell: false,
        environment: _dockerEnvironment,
      );
    }
  }

  /// Stop an ongoing image pull
  Future<void> stopPull(String imageName) async {
    final key = 'pull:$imageName';
    if (_activeProcesses.containsKey(key)) {
      print('🛑 Cancelling image pull: $imageName');
      _activeProcesses[key]!.kill(ProcessSignal.sigkill);
      _activeProcesses.remove(key);
    }
  }

  /// Kill ALL managed processes (useful on app exit or emergency stop)
  void killAllProcesses() {
    print('🚨 Emergency Stop: Killing all ${_activeProcesses.length} processes');
    for (final process in _activeProcesses.values) {
      process.kill(ProcessSignal.sigkill);
    }
    _activeProcesses.clear();
  }

  /// Parse byte string to integer
  /// Examples: "10MB" -> 10485760, "1.5GB" -> 1610612736
  int? _parseBytes(String sizeStr) {
    final pattern = RegExp(r'(\d+\.?\d*)\s*(\w+)');
    final match = pattern.firstMatch(sizeStr);
    if (match == null) return null;

    final value = double.tryParse(match.group(1)!);
    final unit = match.group(2)!.toUpperCase();

    if (value == null) return null;

    switch (unit) {
      case 'B':
        return value.toInt();
      case 'KB':
        return (value * 1024).toInt();
      case 'MB':
        return (value * 1024 * 1024).toInt();
      case 'GB':
        return (value * 1024 * 1024 * 1024).toInt();
      default:
        return null;
    }
  }

  /// Get host architecture for Docker
  Future<String> getHostArchitecture() async {
    final platformInfo = await getPlatformInfo();
    return platformInfo.architecture;
  }

  /// Check if we need platform emulation (for Apple Silicon)
  Future<bool> needsPlatformEmulation() async {
    final platformInfo = await getPlatformInfo();
    return platformInfo.needsPlatformEmulation;
  }

  /// Get platform flag for Docker commands if needed
  Future<List<String>> getPlatformFlags() async {
    final needsEmulation = await needsPlatformEmulation();
    if (needsEmulation) {
      final platformInfo = await getPlatformInfo();
      return ['--platform', platformInfo.dockerPlatformFlag];
    }
    return [];
  }

  /// Get user ID and group ID for running containers as current user
  /// This prevents root-owned files in mounted volumes
  Future<List<String>> getUserFlags() async {
    if (Platform.isWindows) {
      // Windows handles this automatically with WSL2
      return [];
    }

    try {
      // Get current user ID
      final uidResult = await _processRunner.run('id', ['-u'], runInShell: true);
      final gidResult = await _processRunner.run('id', ['-g'], runInShell: true);

      if (uidResult.exitCode == 0 && gidResult.exitCode == 0) {
        final uid = uidResult.stdout.toString().trim();
        final gid = gidResult.stdout.toString().trim();
        return ['-u', '$uid:$gid'];
      }
    } catch (e) {
      print('Error getting user ID: $e');
    }

    return [];
  }

  /// Test Docker connection with a simple command
  Future<bool> testConnection() async {
    try {
      final dockerPath = await getDockerExecutablePath();
      if (dockerPath == null) return false;

      final result = await _processRunner.run(
        dockerPath,
        ['ps'],
        runInShell: false,
      );
      return result.exitCode == 0;
    } catch (e) {
      return false;
    }
  }

  /// Get Docker download URL based on platform.
  /// macOS and Windows → Docker Desktop installer.
  /// Linux → Docker Engine installation guide (no single binary installer).
  String getDockerDesktopDownloadUrl() {
    final platformInfo = _platformInfo;

    if (platformInfo?.isMacOS == true) {
      if (platformInfo?.isAppleSilicon == true) {
        return 'https://desktop.docker.com/mac/main/arm64/Docker.dmg';
      }
      return 'https://desktop.docker.com/mac/main/amd64/Docker.dmg';
    } else if (platformInfo?.isWindows == true) {
      return 'https://desktop.docker.com/win/main/amd64/Docker%20Desktop%20Installer.exe';
    } else if (platformInfo?.isLinux == true) {
      // Docker Desktop for Linux (requires distro-specific setup).
      // The generic install guide covers Ubuntu, Debian, Fedora, and Arch.
      return 'https://docs.docker.com/desktop/install/linux-install/';
    }

    return 'https://www.docker.com/products/docker-desktop';
  }

  /// Get platform-specific help message for Docker installation.
  String getInstallationHelpMessage() {
    final platformInfo = _platformInfo;

    if (platformInfo?.isMacOS == true) {
      return 'Download Docker Desktop for Mac and install it. '
          'After installation, start Docker Desktop from Applications.';
    } else if (platformInfo?.isWindows == true) {
      return 'Download Docker Desktop for Windows and install it. '
          'Make sure to enable the WSL2 backend during installation. '
          'After installation, start Docker Desktop from the Start menu.';
    } else if (platformInfo?.isLinux == true) {
      return 'Install Docker Engine using your distro package manager, e.g.:\n'
          '  Ubuntu/Debian : sudo apt-get install docker.io\n'
          '  Fedora/RHEL   : sudo dnf install docker-ce\n'
          '  Arch Linux    : sudo pacman -S docker\n\n'
          'Then add yourself to the docker group so you can run Docker without sudo:\n'
          '  sudo usermod -aG docker \$USER\n'
          '  (log out and back in for the group change to take effect)\n\n'
          'Alternatively, install Docker Desktop for Linux from the link above.';
    }

    return 'Please install Docker for your platform.';
  }

  /// Get platform-specific help message when Docker is installed but not running.
  String getStartDockerHelpMessage() {
    final platformInfo = _platformInfo;

    if (platformInfo?.isMacOS == true) {
      return 'Open Docker Desktop from Applications or Spotlight search.';
    } else if (platformInfo?.isWindows == true) {
      return 'Open Docker Desktop from the Start menu or system tray.';
    } else if (platformInfo?.isLinux == true) {
      return 'Start the Docker daemon with one of these commands:\n'
          '  systemd  : sudo systemctl start docker\n'
          '  SysV     : sudo service docker start\n\n'
          'To start Docker Desktop for Linux, open it from your application launcher.\n\n'
          'Tip: enable Docker to start automatically on boot:\n'
          '  sudo systemctl enable docker';
    }

    return 'Please start the Docker daemon.';
  }
}
