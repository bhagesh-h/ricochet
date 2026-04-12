import 'dart:io';
import 'dart:convert';
import 'package:archive/archive.dart';
import 'package:flutter/foundation.dart';
import 'package:path_provider/path_provider.dart';
import 'package:path/path.dart' as path;
import 'directory_hashing_service.dart';

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
  
  final _hashingService = DirectoryHashingService();
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

  Directory? _workspaceDir;
  Directory? _pipelinesDir;
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

  // getRunsDirectory removed — Runs folder is no longer created.
  
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

  String _sanitizeRunSegment(String? value) {
    if (value == null) return '';
    final trimmed = value.trim();
    if (trimmed.isEmpty) return '';

    return trimmed
        .replaceAll(RegExp(r'[^a-zA-Z0-9_-]'), '_')
        .replaceAll(RegExp(r'_+'), '_')
        .replaceAll(RegExp(r'^_+|_+$'), '');
  }

  /// Create a temporary staging directory for a node's execution.
  /// Uses the OS temp directory so no Runs folder is created on disk.
  Future<Directory> createStagingDirectory(String nodeName) async {
    final sanitizedName = nodeName.replaceAll(RegExp(r'[^a-zA-Z0-9_-]'), '_');
    final timestamp = _getCustomTimestamp();
    final stagingPath = path.join(
      Directory.systemTemp.path,
      'ricochet_staging_${sanitizedName}_$timestamp',
    );

    final dir = Directory(stagingPath);
    await dir.create(recursive: true);
    return dir;
  }

  /// Finalizes node output: hashes the staging directory, compares with
  /// existing versions, and moves to a stable location if different.
  Future<String> finalizeNodeOutput({
    required String stagingPath,
    required String pipelineName,
    required String nodeName,
    String? explicitOverridePath,
  }) async {
    final stagingDir = Directory(stagingPath);
    if (!await stagingDir.exists()) return stagingPath;

    // 1. Explicit override (User manually chose a path)
    if (explicitOverridePath != null && explicitOverridePath.isNotEmpty) {
      final targetDir = Directory(explicitOverridePath);
      if (!await targetDir.exists()) await targetDir.create(recursive: true);
      
      // Copy contents from staging to target
      await _copyDirectory(stagingDir, targetDir);
      return explicitOverridePath;
    }

    // 2. Standardized path: Pipelines/[PipelineName]/
    final sanitizedNode = nodeName.replaceAll(RegExp(r'[^a-zA-Z0-9_-]'), '_');
    
    final baseDir = Directory(await createPipelineFolder(pipelineName));
    if (!await baseDir.exists()) await baseDir.create(recursive: true);

    // Calculate hash of staging using node-specific hash file name
    final nodeHashFile = '.$sanitizedNode\_hash';
    final hash = await _hashingService.calculateDirectoryHash(stagingDir, hashFileName: nodeHashFile);
    await _hashingService.writeHashFile(stagingDir, hash, hashFileName: nodeHashFile);

    // Check existing versions of this node in the results folder
    final versions = (await baseDir.list().toList())
        .whereType<Directory>()
        .where((d) {
          final bName = path.basename(d.path);
          return bName.startsWith('${sanitizedNode}_');
        })
        .toList();
        
    for (final versionDir in versions) {
      final existingHash = await _hashingService.readHashFile(versionDir, hashFileName: nodeHashFile);
      if (existingHash == hash) {
        // Found identical results! Keep the existing one and return its path.
        print('♻️ Found identical results for $nodeName, reusing: ${versionDir.path}');
        
        // Cleanup staging since we don't need it
        if (await stagingDir.exists()) {
           await stagingDir.delete(recursive: true);
        }
        
        return versionDir.path;
      }
    }

    // No match found or different results -> Create a new folder
    // Always append the requested timestamp format: ss_mm_hh_DD_MM_YYYY
    final now = DateTime.now();
    final ss = now.second.toString().padLeft(2, '0');
    final mm = now.minute.toString().padLeft(2, '0');
    final hh = now.hour.toString().padLeft(2, '0');
    final DD = now.day.toString().padLeft(2, '0');
    final MM = now.month.toString().padLeft(2, '0');
    final YYYY = now.year.toString();
    final timestamp = '${ss}_${mm}_${hh}_${DD}_${MM}_${YYYY}';
    
    final finalFolderName = '${sanitizedNode}_$timestamp';
    
    final finalPath = path.join(baseDir.path, finalFolderName);
    final finalDir = Directory(finalPath);
    
    // Move staging to finalPath
    await stagingDir.rename(finalDir.path);
    print('✅ New result version created for $nodeName: $finalPath');
    
    return finalPath;
  }

  /// Recursive directory copy helper
  Future<void> _copyDirectory(Directory source, Directory destination) async {
    await for (var entity in source.list(recursive: false)) {
      if (entity is Directory) {
        final newDest = Directory(path.join(destination.path, path.basename(entity.path)));
        await newDest.create(recursive: true);
        await _copyDirectory(entity, newDest);
      } else if (entity is File) {
        await entity.copy(path.join(destination.path, path.basename(entity.path)));
      }
    }
  }

  /// Get output file path for a node (Old logic, kept for backward compatibility if needed, 
  /// but PipelineController should use createStagingDirectory + finalizeNodeOutput)
  Future<String> getNodeOutputFilePath(String nodeId, String nodeName,
      {String filename = 'output.txt'}) async {
    final nodeDir = await createStagingDirectory(nodeName);
    return path.join(nodeDir.path, filename);
  }

  // listRunDirectories and cleanupOldRuns removed — Runs folder is no longer used.

  /// Get workspace path as string
  Future<String> getWorkspacePath() async {
    final dir = await getWorkspaceDirectory();
    return dir.path;
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

  /// List all pipeline folders that contain a pipeline*.json (Open Recent)
  Future<List<Map<String, String>>> listRecentPipelines() async {
    final pipelinesDir = await getPipelinesDirectory();
    final entities = await pipelinesDir.list().toList();
    final result = <Map<String, String>>[];

    for (final entity in entities.whereType<Directory>()) {
      bool hasJson = false;
      await for (final child in entity.list()) {
        final bName = path.basename(child.path);
        if (child is File && bName.startsWith('pipeline') && bName.endsWith('.json')) {
          hasJson = true;
          break;
        }
      }
      
      if (hasJson) {
        result.add({
          'name': path.basename(entity.path),
          'folderPath': entity.path,
        });
      }
    }
    return result;
  }

  /// Import a pipeline from a selected folder path.
  /// Returns the folderPath if valid (contains pipeline*.json), null otherwise.
  Future<String?> importPipelineFromFolder(String folderPath) async {
    final dir = Directory(folderPath);
    if (!await dir.exists()) return null;
    
    bool hasJson = false;
    await for (final entity in dir.list()) {
      final bName = path.basename(entity.path);
      if (entity is File && bName.startsWith('pipeline') && bName.endsWith('.json')) {
        hasJson = true;
        break;
      }
    }
    if (!hasJson) return null;
    return folderPath;
  }

  /// Import an exported pipeline from a .zip or .env file by decoding
  /// the hidden RICOCHET_STATE metadata.
  Future<String?> importPipelineFromExport(String filePath) async {
    String? envContent;

    if (filePath.endsWith('.zip')) {
      final bytes = await File(filePath).readAsBytes();
      final archive = ZipDecoder().decodeBytes(bytes);
      
      for (final file in archive) {
        if (file.isFile && path.basename(file.name) == 'pipeline_config.env') {
          envContent = utf8.decode(file.content as List<int>);
          break;
        }
      }
    } else if (filePath.endsWith('.env')) {
      envContent = await File(filePath).readAsString();
    } else if (filePath.endsWith('.json')) {
      // Direct raw pipeline.json import support
      return importPipelineFromFolder(File(filePath).parent.path);
    }
    
    if (envContent == null) return null;

    // Search for # RICOCHET_STATE:
    final lines = envContent.split('\n');
    String? stateB64;
    for (final line in lines.reversed) {
      if (line.startsWith('# RICOCHET_STATE: ')) {
        stateB64 = line.substring('# RICOCHET_STATE: '.length).trim();
        break;
      }
    }

    if (stateB64 == null) return null;

    try {
      final jsonStr = utf8.decode(base64Decode(stateB64));
      final Map<String, dynamic> stateMap = jsonDecode(jsonStr);
      
      final String pipelineName = stateMap['name'] ?? 'Imported Pipeline ${DateTime.now().millisecondsSinceEpoch}';
      final folderPath = await createPipelineFolder(pipelineName);
      
      final now = DateTime.now();
      final ss = now.second.toString().padLeft(2, '0');
      final mm = now.minute.toString().padLeft(2, '0');
      final hh = now.hour.toString().padLeft(2, '0');
      final DD = now.day.toString().padLeft(2, '0');
      final MM = now.month.toString().padLeft(2, '0');
      final YYYY = now.year.toString();
      final timestamp = '${ss}_${mm}_${hh}_${DD}_${MM}_${YYYY}';

      final pipelineJsonPath = path.join(folderPath, 'pipeline_$timestamp.json');
      
      final exportedJson = {
        'id': 'temp-id',
        'name': pipelineName,
        'folderPath': folderPath,
        'nodes': stateMap['nodes'] ?? [],
        'connections': stateMap['connections'] ?? [],
      };
      
      await File(pipelineJsonPath).writeAsString(jsonEncode(exportedJson));
      return folderPath;
    } catch (e) {
      print('Failed to decode ricochet state: $e');
      return null;
    }
  }
}

