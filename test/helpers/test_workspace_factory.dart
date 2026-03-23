import 'dart:io';

/// Factory that creates unique, disposable temp directories for tests.
///
/// Rules enforced by this class:
/// - Each [create] call returns a **new** directory with a UUID-like suffix.
/// - Directories never share a path, even across parallel test runners.
/// - No global static state is used.
/// - [cleanup] is idempotent — safe to call even if the directory was already
///   deleted.
///
/// Usage:
/// ```dart
/// late Directory testDir;
///
/// setUp(() async { testDir = await TestWorkspaceFactory.create(); });
/// tearDown(() async { await TestWorkspaceFactory.cleanup(testDir); });
/// ```
abstract final class TestWorkspaceFactory {
  TestWorkspaceFactory._();

  /// Create a fresh temp directory guaranteed unique for this test run.
  static Future<Directory> create({String prefix = 'bioflow_test_'}) async {
    // Use system temp + a high-resolution timestamp + pid combination so that
    // parallel test workers running on the same machine never collide.
    final suffix = '${DateTime.now().microsecondsSinceEpoch}_${pid}';
    final dir = await Directory.systemTemp.createTemp('$prefix$suffix');
    return dir;
  }

  /// Delete [dir] and all its contents.  Safe to call multiple times.
  static Future<void> cleanup(Directory dir) async {
    try {
      if (await dir.exists()) {
        await dir.delete(recursive: true);
      }
    } catch (_) {
      // Idempotent — ignore errors from concurrent cleanup or already-gone dirs.
    }
  }
}
