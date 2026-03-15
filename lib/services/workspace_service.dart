import 'dart:io';
import 'package:path_provider/path_provider.dart';
import 'package:path/path.dart' as path;

/// Service to manage workspace directories for pipeline execution
class WorkspaceService {
  static const String _workspaceDirName = 'bioflow_workspace';

  Directory? _workspaceDir;
  Directory? _currentRunDir;

  /// Get or create the main workspace directory
  Future<Directory> getWorkspaceDirectory() async {
    if (_workspaceDir != null) return _workspaceDir!;

    final appDocDir = await getApplicationDocumentsDirectory();
    final workspacePath = path.join(appDocDir.path, _workspaceDirName);

    _workspaceDir = Directory(workspacePath);
    if (!await _workspaceDir!.exists()) {
      await _workspaceDir!.create(recursive: true);
      print('📁 Created workspace directory: $workspacePath');
    }

    return _workspaceDir!;
  }

  /// Create a new run directory for this execution
  Future<Directory> createRunDirectory() async {
    final workspace = await getWorkspaceDirectory();
    final timestamp =
        DateTime.now().toIso8601String().replaceAll(':', '-').split('.')[0];
    final runDirPath = path.join(workspace.path, 'run_$timestamp');

    _currentRunDir = Directory(runDirPath);
    await _currentRunDir!.create(recursive: true);

    print('📂 Created run directory: $runDirPath');
    return _currentRunDir!;
  }

  /// Get the current run directory (or create if doesn't exist)
  Future<Directory> getCurrentRunDirectory() async {
    if (_currentRunDir != null && await _currentRunDir!.exists()) {
      return _currentRunDir!;
    }
    return await createRunDirectory();
  }

  /// Create a node-specific output directory
  Future<Directory> createNodeOutputDirectory(
      String nodeId, String nodeName) async {
    final runDir = await getCurrentRunDirectory();
    final sanitizedName = nodeName.replaceAll(RegExp(r'[^a-zA-Z0-9_-]'), '_');
    final nodeDirPath = path.join(runDir.path, '${sanitizedName}_$nodeId');

    final nodeDir = Directory(nodeDirPath);
    if (!await nodeDir.exists()) {
      await nodeDir.create(recursive: true);
    }

    return nodeDir;
  }

  /// Get output file path for a node
  Future<String> getNodeOutputFilePath(String nodeId, String nodeName,
      {String filename = 'output.txt'}) async {
    final nodeDir = await createNodeOutputDirectory(nodeId, nodeName);
    return path.join(nodeDir.path, filename);
  }

  /// List all run directories
  Future<List<Directory>> listRunDirectories() async {
    final workspace = await getWorkspaceDirectory();
    final entities = await workspace.list().toList();

    return entities
        .whereType<Directory>()
        .where((dir) => path.basename(dir.path).startsWith('run_'))
        .toList();
  }

  /// Clean up old run directories (keep last N runs)
  Future<void> cleanupOldRuns({int keepLast = 10}) async {
    final runs = await listRunDirectories();

    if (runs.length <= keepLast) return;

    // Sort by modification time (oldest first)
    runs.sort((a, b) => a.statSync().modified.compareTo(b.statSync().modified));

    final toDelete = runs.take(runs.length - keepLast);
    for (final dir in toDelete) {
      await dir.delete(recursive: true);
      print('🗑️ Deleted old run: ${path.basename(dir.path)}');
    }
  }

  /// Get workspace path as string
  Future<String> getWorkspacePath() async {
    final dir = await getWorkspaceDirectory();
    return dir.path;
  }

  /// Get current run path as string
  Future<String?> getCurrentRunPath() async {
    if (_currentRunDir == null) return null;
    return _currentRunDir!.path;
  }
}
