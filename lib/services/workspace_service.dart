import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:path_provider/path_provider.dart';
import 'package:path/path.dart' as path;

/// Service to manage workspace directories for pipeline execution.
///
/// This class is a singleton — every `WorkspaceService()` call returns the
/// same instance so that all controllers share a single [_currentRunDir].
/// Without this guarantee, [PipelineController] and [ExecutionController]
/// would each hold their own run-directory pointer that can diverge.
///
/// For tests, use [WorkspaceService.withPath] to obtain an isolated instance
/// rooted at a temporary directory (via [TestWorkspaceFactory]).
class WorkspaceService {
  // ── Singleton boilerplate ─────────────────────────────────────────────────────
  static final WorkspaceService _instance = WorkspaceService._internal(null);
  factory WorkspaceService() => _instance;
  WorkspaceService._internal(this._overrideBasePath);
  // ────────────────────────────────────────────────────────────────────────────

  /// Creates a non-singleton instance rooted at [basePath].
  ///
  /// Use this in tests by passing a directory created with [TestWorkspaceFactory]:
  /// ```dart
  /// final testDir = await TestWorkspaceFactory.create();
  /// final service = WorkspaceService.withPath(testDir.path);
  /// ```
  @visibleForTesting
  WorkspaceService.withPath(String basePath) : _overrideBasePath = basePath;

  /// When non-null, all directories are rooted here instead of the system
  /// application documents directory.  Set only by [WorkspaceService.withPath].
  final String? _overrideBasePath;
  static const String _workspaceDirName = 'Ricochet';
  static const String _pipelinesDirName = 'Pipelines';
  static const String _runsDirName = 'Runs';

  Directory? _workspaceDir;
  Directory? _pipelinesDir;
  Directory? _runsDir;
  Directory? _currentRunDir;

  /// Get or create the main workspace directory
  Future<Directory> getWorkspaceDirectory() async {
    if (_workspaceDir != null) return _workspaceDir!;

    final String basePath;
    if (_overrideBasePath != null) {
      basePath = _overrideBasePath;
    } else {
      final appDocDir = await getApplicationDocumentsDirectory();
      basePath = appDocDir.path;
    }

    final workspacePath = path.join(basePath, _workspaceDirName);

    _workspaceDir = Directory(workspacePath);
    if (!await _workspaceDir!.exists()) {
      await _workspaceDir!.create(recursive: true);
      print('📁 Created workspace directory: $workspacePath');
    }

    return _workspaceDir!;
  }

  /// Get or create the Pipelines directory
  Future<Directory> getPipelinesDirectory() async {
    if (_pipelinesDir != null) return _pipelinesDir!;
    
    final workspace = await getWorkspaceDirectory();
    final pipelinesPath = path.join(workspace.path, _pipelinesDirName);
    
    _pipelinesDir = Directory(pipelinesPath);
    if (!await _pipelinesDir!.exists()) {
      await _pipelinesDir!.create(recursive: true);
    }
    
    return _pipelinesDir!;
  }

  /// Get or create the Runs directory
  Future<Directory> getRunsDirectory() async {
    if (_runsDir != null) return _runsDir!;
    
    final workspace = await getWorkspaceDirectory();
    final runsPath = path.join(workspace.path, _runsDirName);
    
    _runsDir = Directory(runsPath);
    if (!await _runsDir!.exists()) {
      await _runsDir!.create(recursive: true);
    }
    
    return _runsDir!;
  }
  
  /// Create a new dedicated directory for a pipeline project
  Future<String> createPipelineFolder(String pipelineName) async {
    final pipelinesDir = await getPipelinesDirectory();
    final sanitizedName = pipelineName.replaceAll(RegExp(r'[^a-zA-Z0-9_\s-]'), '_').trim();
    final folderPath = path.join(pipelinesDir.path, sanitizedName);
    
    final dir = Directory(folderPath);
    if (!await dir.exists()) {
      await dir.create(recursive: true);
    }
    
    return dir.path;
  }

  /// Get a custom formatted timestamp (ss_mm_hh_DD_MM_YYYY)
  String _getCustomTimestamp() {
    final now = DateTime.now();
    final ss = now.second.toString().padLeft(2, '0');
    final mm = now.minute.toString().padLeft(2, '0');
    final hh = now.hour.toString().padLeft(2, '0');
    final dd = now.day.toString().padLeft(2, '0');
    final M = now.month.toString().padLeft(2, '0');
    final yyyy = now.year.toString();
    return '${ss}_${mm}_${hh}_${dd}_${M}_$yyyy';
  }

  /// Create a new run directory for this execution
  Future<Directory> createRunDirectory({String? pipelineName}) async {
    final runsDir = await getRunsDirectory();
    final timestamp = _getCustomTimestamp();
    final pipelineSegment = _sanitizeRunSegment(pipelineName);

    final baseName = pipelineSegment.isEmpty
        ? 'Run_$timestamp'
        : '${pipelineSegment}_$timestamp';

    var runDirPath = path.join(runsDir.path, baseName);
    var attempt = 1;
    while (await Directory(runDirPath).exists()) {
      attempt++;
      runDirPath = path.join(runsDir.path, '${baseName}_$attempt');
    }

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

  /// Reset the cached run directory so the NEXT call to [getCurrentRunDirectory]
  /// creates a brand-new timestamped folder.  Call this at the start of every
  /// pipeline execution so repeated runs never share a workspace directory.
  Future<Directory> startNewRun({String? pipelineName}) async {
    _currentRunDir = null;
    return await createRunDirectory(pipelineName: pipelineName);
  }

  String _sanitizeRunSegment(String? value) {
    if (value == null) return '';
    final trimmed = value.trim();
    if (trimmed.isEmpty) return '';

    return trimmed
        .replaceAll(RegExp(r'[^a-zA-Z0-9_-]'), '_')
        .replaceAll(RegExp(r'_+'), '_')
        .replaceAll(RegExp(r'^_+|_+$'), '');
  }

  /// Create a node-specific output directory
  Future<Directory> createNodeOutputDirectory(
      String nodeId, String nodeName) async {
    final runDir = await getCurrentRunDirectory();
    final sanitizedName = nodeName.replaceAll(RegExp(r'[^a-zA-Z0-9_-]'), '_');
    // Using _$timestamp as requested
    final timestamp = _getCustomTimestamp();
    final nodeDirPath = path.join(runDir.path, '${sanitizedName}_$timestamp');

    var actualPath = nodeDirPath;
    var attempt = 1;
    while (await Directory(actualPath).exists()) {
      attempt++;
      actualPath = '${nodeDirPath}_$attempt';
    }

    final nodeDir = Directory(actualPath);
    await nodeDir.create(recursive: true);

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
    final runsDir = await getRunsDirectory();
    final entities = await runsDir.list().toList();

    return entities
        .whereType<Directory>()
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

  /// Save an exported zip byte array to the exports folder
  Future<String> saveExportZip(List<int> zipBytes, String filename) async {
    final workspace = await getWorkspaceDirectory();
    final exportsDirPath = path.join(workspace.path, 'exports');
    
    final exportsDir = Directory(exportsDirPath);
    if (!await exportsDir.exists()) {
      await exportsDir.create(recursive: true);
    }

    final filePath = path.join(exportsDir.path, filename);
    final file = File(filePath);
    await file.writeAsBytes(zipBytes);
    
    print('📦 Export saved to: $filePath');
    return filePath;
  }

  /// List all pipeline folders that contain a pipeline.json (Open Recent)
  Future<List<Map<String, String>>> listRecentPipelines() async {
    final pipelinesDir = await getPipelinesDirectory();
    final entities = await pipelinesDir.list().toList();
    final result = <Map<String, String>>[];

    for (final entity in entities.whereType<Directory>()) {
      final jsonFile = File(path.join(entity.path, 'pipeline.json'));
      if (await jsonFile.exists()) {
        result.add({
          'name': path.basename(entity.path),
          'folderPath': entity.path,
        });
      }
    }
    return result;
  }

  /// Import a pipeline from a selected folder path.
  /// Returns the folderPath if valid (contains pipeline.json), null otherwise.
  Future<String?> importPipelineFromFolder(String folderPath) async {
    final jsonFile = File(path.join(folderPath, 'pipeline.json'));
    if (!await jsonFile.exists()) return null;
    return folderPath;
  }
}

