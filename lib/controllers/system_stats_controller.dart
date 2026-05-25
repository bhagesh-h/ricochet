import 'dart:async';
import 'dart:io';
import 'package:get/get.dart';
import '../services/workspace_service.dart';

class SystemStatsController extends GetxController {
  final cpuStat = ''.obs;
  final gpuStat = ''.obs;
  final storageStat = ''.obs;

  Timer? _pollingTimer;

  // Track if polling is currently active to avoid overlaps if command runs slow
  bool _isPolling = false;

  // Cache NVIDIA SMI availability to avoid constant failing process execution
  bool _nvidiaSmiAvailable = true;

  // Linux CPU calculation ticks cache
  List<int>? _lastCpuTicks;

  @override
  void onInit() {
    super.onInit();
  }

  @override
  void onClose() {
    stopPolling();
    super.onClose();
  }

  void startPolling() {
    if (_pollingTimer != null) return;
    _pollStats(); // initial poll
    _pollingTimer = Timer.periodic(const Duration(seconds: 4), (_) => _pollStats());
  }

  void stopPolling() {
    _pollingTimer?.cancel();
    _pollingTimer = null;
    cpuStat.value = '';
    gpuStat.value = '';
    storageStat.value = '';
    _lastCpuTicks = null;
  }

  Future<void> _pollStats() async {
    if (_isPolling) return;
    _isPolling = true;

    try {
      if (Platform.isWindows) {
        await _pollWindowsStats();
      } else if (Platform.isMacOS) {
        await _pollMacOSStats();
      } else if (Platform.isLinux) {
        await _pollLinuxStats();
      }
    } catch (e) {
      // Silently fail if unable to fetch host stats
    } finally {
      _isPolling = false;
    }
  }

  Future<void> _pollWindowsStats() async {
    // ---- 1. CPU & Storage (Combined in a single PowerShell process call) ----
    try {
      final wsService = WorkspaceService();
      final wsDir = await wsService.getWorkspaceDirectory();
      final wsPath = wsDir.path;
      String driveLetter = 'C';
      if (wsPath.length >= 2 && wsPath[1] == ':') {
        driveLetter = wsPath[0];
      }

      // Query CPU load percentage and storage free space in one command to halve PowerShell startup overhead
      final command = r'$cpu = Get-CimInstance Win32_Processor | Select-Object -ExpandProperty LoadPercentage; '
                      r'$disk = (Get-PSDrive ' + driveLetter + r').Free; '
                      r'Write-Output "$cpu|$disk"';

      final res = await Process.run('powershell', ['-Command', command]);

      if (res.exitCode == 0) {
        final output = res.stdout.toString().trim();
        final parts = output.split('|');
        if (parts.length >= 2) {
          final cpuVal = parts[0].trim();
          final diskVal = parts[1].trim();

          if (cpuVal.isNotEmpty) {
            cpuStat.value = '$cpuVal%';
          }

          final bytes = int.tryParse(diskVal);
          if (bytes != null) {
            storageStat.value = _formatBytesToGB(bytes);
          }
        }
      }
    } catch (_) {}

    // ---- 2. GPU Usage (NVIDIA only, with availability cache) ----
    if (_nvidiaSmiAvailable) {
      try {
        final gpuRes = await Process.run('nvidia-smi',
            ['--query-gpu=utilization.gpu', '--format=csv,noheader,nounits']);
        if (gpuRes.exitCode == 0) {
          final val = gpuRes.stdout.toString().trim().split('\n').first;
          if (val.isNotEmpty) {
            gpuStat.value = '$val%';
          }
        } else {
          _nvidiaSmiAvailable = false;
          gpuStat.value = '';
        }
      } catch (_) {
        _nvidiaSmiAvailable = false;
        gpuStat.value = '';
      }
    }
  }

  Future<void> _pollMacOSStats() async {
    // ---- 1. CPU Usage ----
    try {
      final cpuRes = await Process.run('sh', ['-c', "top -l 1 | grep 'CPU usage'"]);
      if (cpuRes.exitCode == 0) {
        final output = cpuRes.stdout.toString();
        // Format: "CPU usage: 5.55% user, 5.55% sys, 88.88% idle"
        final regExp = RegExp(r'(\d+\.?\d*)%\s+user');
        final match = regExp.firstMatch(output);
        if (match != null) {
          cpuStat.value = '${match.group(1)}%';
        }
      }
    } catch (_) {}

    // ---- 2. Storage Free Space ----
    try {
      final wsService = WorkspaceService();
      final wsDir = await wsService.getWorkspaceDirectory();
      final diskRes = await Process.run('df', ['-h', wsDir.path]);
      if (diskRes.exitCode == 0) {
        final lines = diskRes.stdout.toString().trim().split('\n');
        if (lines.length >= 2) {
          final parts = lines[1].split(RegExp(r'\s+'));
          if (parts.length >= 4) {
            storageStat.value = '${parts[3]} Free';
          }
        }
      }
    } catch (_) {}
  }

  Future<void> _pollLinuxStats() async {
    // ---- 1. CPU Usage (Native File reading of /proc/stat - ZERO process spawning) ----
    try {
      final file = File('/proc/stat');
      if (await file.exists()) {
        final lines = await file.readAsLines();
        if (lines.isNotEmpty) {
          final cpuLine = lines.first;
          final parts = cpuLine.split(RegExp(r'\s+')).where((p) => p.isNotEmpty).toList();
          if (parts.length >= 5 && parts[0] == 'cpu') {
            final user = int.parse(parts[1]);
            final nice = int.parse(parts[2]);
            final system = int.parse(parts[3]);
            final idle = int.parse(parts[4]);
            final iowait = int.parse(parts[5]);
            final irq = int.parse(parts[6]);
            final softirq = int.parse(parts[7]);

            int steal = 0;
            if (parts.length >= 9) {
              steal = int.parse(parts[8]);
            }

            final currentIdle = idle + iowait;
            final currentNonIdle = user + nice + system + irq + softirq + steal;
            final currentTotal = currentIdle + currentNonIdle;

            if (_lastCpuTicks != null) {
              final prevIdle = _lastCpuTicks![0];
              final prevTotal = _lastCpuTicks![1];

              final totalDiff = currentTotal - prevTotal;
              final idleDiff = currentIdle - prevIdle;

              if (totalDiff > 0) {
                final cpuUsage = ((totalDiff - idleDiff) / totalDiff) * 100;
                cpuStat.value = '${cpuUsage.toStringAsFixed(1)}%';
              }
            }
            _lastCpuTicks = [currentIdle, currentTotal];
          }
        }
      }
    } catch (_) {}

    // ---- 2. Storage Free Space ----
    try {
      final wsService = WorkspaceService();
      final wsDir = await wsService.getWorkspaceDirectory();
      final diskRes = await Process.run('df', ['-h', wsDir.path]);
      if (diskRes.exitCode == 0) {
        final lines = diskRes.stdout.toString().trim().split('\n');
        if (lines.length >= 2) {
          final parts = lines[1].split(RegExp(r'\s+'));
          if (parts.length >= 4) {
            storageStat.value = '${parts[3]} Free';
          }
        }
      }
    } catch (_) {}
  }

  String _formatBytesToGB(int bytes) {
    final gb = bytes / (1024 * 1024 * 1024);
    return '${gb.toStringAsFixed(1)} GB Free';
  }
}
