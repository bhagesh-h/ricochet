import 'dart:io';

import 'package:path/path.dart' as path;
import 'package:path_provider/path_provider.dart';

import 'ai_secure_storage.dart';
import 'workspace_service.dart';

/// Local file-backed API key store used when OS keychain / credential manager
/// is unavailable (e.g. missing macOS entitlements during local development).
///
/// Keys are stored under the OS application-support directory (not iCloud-
/// synced Documents) with owner-only permissions on POSIX systems. A legacy
/// workspace copy under Documents/Ricochet is migrated away on first read/write
/// so earlier installs do not leave plaintext keys in cloud-synced folders.
class WorkspaceAiSecureStorage implements AiSecureStorage {
  WorkspaceAiSecureStorage({WorkspaceService? workspaceService})
      : _workspaceService = workspaceService ?? WorkspaceService();

  static const String _fileName = '.ai_api_key';
  static const String _appFolderName = 'Ricochet';

  final WorkspaceService _workspaceService;

  Future<File> _keyFile() async {
    final support = await getApplicationSupportDirectory();
    final dir = Directory(path.join(support.path, _appFolderName));
    if (!await dir.exists()) {
      await dir.create(recursive: true);
    }
    return File(path.join(dir.path, _fileName));
  }

  Future<File> _legacyKeyFile() async {
    final workspace = await _workspaceService.getWorkspaceDirectory();
    return File(path.join(workspace.path, _fileName));
  }

  Future<void> _restrictPermissions(File file) async {
    if (Platform.isWindows) return;
    try {
      await Process.run('chmod', ['600', file.path]);
    } catch (_) {
      // Best-effort; absence of chmod must not block key persistence.
    }
  }

  Future<void> _deleteLegacyIfPresent() async {
    try {
      final legacy = await _legacyKeyFile();
      if (await legacy.exists()) {
        await legacy.delete();
      }
    } catch (_) {}
  }

  @override
  Future<void> writeApiKey(String value) async {
    final file = await _keyFile();
    if (value.isEmpty) {
      if (await file.exists()) {
        await file.delete();
      }
      await _deleteLegacyIfPresent();
      return;
    }
    await file.writeAsString(value, flush: true);
    await _restrictPermissions(file);
    await _deleteLegacyIfPresent();
  }

  @override
  Future<String?> readApiKey() async {
    final file = await _keyFile();
    if (await file.exists()) {
      final value = await file.readAsString();
      return value.isEmpty ? null : value;
    }

    // One-time migration from the old Documents/Ricochet location.
    try {
      final legacy = await _legacyKeyFile();
      if (await legacy.exists()) {
        final value = await legacy.readAsString();
        if (value.isNotEmpty) {
          await writeApiKey(value);
          return value;
        }
        await legacy.delete();
      }
    } catch (_) {}

    return null;
  }

  @override
  Future<void> deleteApiKey() async {
    final file = await _keyFile();
    if (await file.exists()) {
      await file.delete();
    }
    await _deleteLegacyIfPresent();
  }
}
