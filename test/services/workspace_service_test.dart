import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:Ricochet/models/node_execution_identity.dart';
import 'package:Ricochet/services/workspace_service.dart';

import '../helpers/test_workspace_factory.dart';

void main() {
  // Track directories created in each test for cleanup.
  final List<Directory> created = [];

  Future<Directory> makeDir({String prefix = 'ricochet_ws_test'}) async {
    final dir = await TestWorkspaceFactory.create(prefix: prefix);
    created.add(dir);
    return dir;
  }

  late Directory testDir;
  late WorkspaceService service;

  setUp(() async {
    testDir = await makeDir();
    service = WorkspaceService.withPath(testDir.path);
  });

  tearDown(() async {
    for (final dir in List<Directory>.from(created)) {
      await TestWorkspaceFactory.cleanup(dir);
    }
    created.clear();
  });

  // ── getWorkspaceDirectory ───────────────────────────────────────────────────

  group('getWorkspaceDirectory', () {
    test('returns a Ricochet subdirectory inside the injected basePath', () async {
      final dir = await service.getWorkspaceDirectory();
      expect(dir.path, startsWith(testDir.path));
      expect(dir.path, endsWith('Ricochet'));
    });

    test('injected directory is created and exists', () async {
      final dir = await service.getWorkspaceDirectory();
      expect(await dir.exists(), isTrue);
    });

    test('injected path differs from default AppDocumentsDir path', () async {
      // The TestWorkspaceFactory creates under systemTemp, never appDocuments.
      final dir = await service.getWorkspaceDirectory();
      expect(dir.path, isNot(contains('Documents')));
    });
  });

  // ── createStagingDirectory ──────────────────────────────────────────────────

  group('createStagingDirectory', () {
    NodeExecutionIdentity _identity(String suffix) => NodeExecutionIdentity(
          tabId: 'tab-$suffix',
          nodeId: 'node-$suffix',
          nodeTitle: 'FastQC',
        );

    test('creates a directory inside system temp', () async {
      final runDir = await service.createStagingDirectory(_identity('a'));
      expect(await runDir.exists(), isTrue);
      expect(runDir.path, startsWith(Directory.systemTemp.path));
      if (await runDir.exists()) {
        await runDir.delete(recursive: true);
      }
    });

    test('successive calls produce distinct paths', () async {
      final dir1 = await service.createStagingDirectory(_identity('1'));
      final dir2 = await service.createStagingDirectory(_identity('2'));
      expect(dir1.path, isNot(equals(dir2.path)));
      if (await dir1.exists()) await dir1.delete(recursive: true);
      if (await dir2.exists()) await dir2.delete(recursive: true);
    });

    test('staging directory contains node name identifier', () async {
      final runDir =
          await service.createStagingDirectory(_identity('name'));
      expect(runDir.path, contains('FastQC'));
      if (await runDir.exists()) await runDir.delete(recursive: true);
    });

    test('same node title with different ids produces distinct paths', () async {
      final dir1 = await service.createStagingDirectory(_identity('alpha'));
      final dir2 = await service.createStagingDirectory(_identity('beta'));
      expect(dir1.path, isNot(equals(dir2.path)));
      if (await dir1.exists()) await dir1.delete(recursive: true);
      if (await dir2.exists()) await dir2.delete(recursive: true);
    });
  });

  // ── Parallel-safety: concurrent create() calls ──────────────────────────────

  group('TestWorkspaceFactory parallel safety', () {
    test('ten concurrent create() calls all produce distinct, existing dirs', () async {
      final dirs = await Future.wait(
        List.generate(
          10,
          (_) => makeDir(prefix: 'parallel_test'),
        ),
      );

      final paths = dirs.map((d) => d.path).toSet();
      expect(paths.length, equals(10), reason: 'All 10 paths must be unique');

      for (final d in dirs) {
        expect(await d.exists(), isTrue);
      }
    });
  });

  // ── cleanupAll ──────────────────────────────────────────────────────────────

  group('TestWorkspaceFactory.cleanup', () {
    test('removes a created directory', () async {
      final dir = await makeDir(prefix: 'cleanup_a');
      final dir2 = await makeDir(prefix: 'cleanup_b');

      await TestWorkspaceFactory.cleanup(dir);
      await TestWorkspaceFactory.cleanup(dir2);

      expect(await dir.exists(), isFalse);
      expect(await dir2.exists(), isFalse);
    });

    test('cleanup is idempotent — calling twice does not throw', () async {
      final dir = await makeDir(prefix: 'idempotent_test');
      await TestWorkspaceFactory.cleanup(dir);
      // Second call should be a no-op.
      await expectLater(TestWorkspaceFactory.cleanup(dir), completes);
    });
  });
}
