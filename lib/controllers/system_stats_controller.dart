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
    _pollingTimer = Timer.periodic(const Duration(seconds: 2), (_) => _pollStats());
  }

  void stopPolling() {
    _pollingTimer?.cancel();
    _pollingTimer = null;
    cpuStat.value = '';
    gpuStat.value = '';
    storageStat.value = '';
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
    // ---- 1. CPU Usage ----
    try {
      final cpuRes = await Process.run('powershell', [
        '-Command',
        'Get-CimInstance Win32_Processor | Select-Object -ExpandProperty LoadPercentage'
      ]);
      if (cpuRes.exitCode == 0) {
        final val = cpuRes.stdout.toString().trim();
        if (val.isNotEmpty) {
          cpuStat.value = '$val%';
        }
      }
    } catch (_) {}

    // ---- 2. GPU Usage (NVIDIA only) ----
    try {
      final gpuRes = await Process.run('nvidia-smi',
          ['--query-gpu=utilization.gpu', '--format=csv,noheader,nounits']);
      if (gpuRes.exitCode == 0) {
        final val = gpuRes.stdout.toString().trim().split('\n').first;
        if (val.isNotEmpty) {
          gpuStat.value = '$val%';
        }
      }
    } catch (_) {
      gpuStat.value = '';
    }

    // ---- 3. Storage Free Space (Workspace Drive) ----
    try {
      final wsService = WorkspaceService();
      final wsDir = await wsService.getWorkspaceDirectory();
      final wsPath = wsDir.path;
      if (wsPath.length >= 2 && wsPath[1] == ':') {
        final driveLetter = wsPath.substring(0, 2);
        final diskRes = await Process.run('powershell', [
          '-Command',
          '(Get-PSDrive ${driveLetter[0]}).Free'
        ]);

        if (diskRes.exitCode == 0) {
          final val = diskRes.stdout.toString().trim();
          final bytes = int.tryParse(val);
          if (bytes != null) {
            storageStat.value = _formatBytesToGB(bytes);
          }
        }
      }
    } catch (_) {}
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
    // ---- 1. CPU Usage ----
    try {
      final cpuRes = await Process.run('sh', ['-c', "top -bn1 | grep 'Cpu(s)'"]);
      if (cpuRes.exitCode == 0) {
        final output = cpuRes.stdout.toString();
        // Format: "%Cpu(s):  5.0 us,  2.0 sy, ..."
        final regExp = RegExp(r'(\d+\.?\d*)\s+us');
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

  String _formatBytesToGB(int bytes) {
    final gb = bytes / (1024 * 1024 * 1024);
    return '${gb.toStringAsFixed(1)} GB Free';
  }
}
