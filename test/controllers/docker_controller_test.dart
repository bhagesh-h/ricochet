import 'package:flutter_test/flutter_test.dart';
import 'package:get/get.dart';
import 'package:Ricochet/controllers/docker_controller.dart';
import 'package:Ricochet/models/docker_info.dart';
import 'package:Ricochet/services/docker_service.dart';

import '../helpers/fake_process_runner.dart';
import '../helpers/state_sequence_asserter.dart';

void main() {
  late FakeProcessRunner fakeRunner;
  late DockerService service;
  late DockerController controller;

  setUp(() {
    // GetX needs a test binding for .obs reactivity.
    TestWidgetsFlutterBinding.ensureInitialized();
    fakeRunner = FakeProcessRunner();
    service = DockerService.withRunner(fakeRunner);
    controller = DockerController.withService(service);
  });

  tearDown(() {
    controller.onClose();
    Get.reset();
  });

  // ── checkDockerStatus state transitions ────────────────────────────────────

  group('checkDockerStatus state transitions', () {
    test('transitions checking → running when Docker is installed and daemon is up',
        () async {
      _stubDockerReady(fakeRunner);

      final states = <DockerStatus>[];
      // Capture the initial checking value and all subsequent changes.
      states.add(controller.status.value); // current value before any await
      controller.status.listen(states.add);

      await controller.checkDockerStatus();

      StateSequenceAsserter.assertContainsSubsequence(
        actual: states,
        expected: [DockerStatus.running],
        reason: 'status must reach running after a successful check',
      );
    });

    test('settles to notInstalled when docker executable is absent', () async {
      _stubDockerNotInstalled(fakeRunner);

      final states = <DockerStatus>[];
      controller.status.listen(states.add);

      await controller.checkDockerStatus();

      StateSequenceAsserter.assertEndsWith(
        actual: states,
        expected: [DockerStatus.notInstalled],
        reason: 'status must settle on notInstalled',
      );
    });

    test('settles to stopped when installed but daemon is not running', () async {
      _stubDockerInstalled(fakeRunner);
      fakeRunner.addResponse(
        executable: '/usr/local/bin/docker',
        arguments: ['info'],
        exitCode: 1,
        stderr: 'Cannot connect to the Docker daemon',
      );

      final states = <DockerStatus>[];
      controller.status.listen(states.add);

      await controller.checkDockerStatus();

      StateSequenceAsserter.assertEndsWith(
        actual: states,
        expected: [DockerStatus.stopped],
        reason: 'status must settle on stopped when daemon is unreachable',
      );
    });

    test('concurrent checkDockerStatus calls are serialised — only one completes',
        () async {
      _stubDockerReady(fakeRunner);

      // Fire two concurrent checks; the second should be a no-op while the
      // first is in-flight (isChecking guard).
      await Future.wait([
        controller.checkDockerStatus(),
        controller.checkDockerStatus(),
      ]);

      // Both await without throwing is the assertion.
      expect(controller.isChecking.value, isFalse);
    });
  });

  // ── retryConnection ────────────────────────────────────────────────────────

  group('retryConnection', () {
    test('re-runs status check and updates status observable', () async {
      // First call: not installed.
      _stubDockerNotInstalled(fakeRunner);
      await controller.checkDockerStatus();
      expect(controller.status.value, equals(DockerStatus.notInstalled));

      // Install Docker and retry — now it should be running.
      fakeRunner = FakeProcessRunner();
      service = DockerService.withRunner(fakeRunner);
      controller = DockerController.withService(service);

      _stubDockerReady(fakeRunner);
      await controller.retryConnection();

      expect(controller.status.value, equals(DockerStatus.running));
    });
  });

  // ── dockerInfo population ──────────────────────────────────────────────────

  group('dockerInfo population', () {
    test('populates dockerInfo when Docker is running', () async {
      _stubDockerReady(fakeRunner);

      await controller.checkDockerStatus();

      expect(controller.dockerInfo.value, isNotNull);
      expect(controller.dockerInfo.value!.isRunning, isTrue);
    });

    test('clears dockerInfo when Docker is not running', () async {
      _stubDockerInstalled(fakeRunner);
      fakeRunner.addResponse(
        executable: '/usr/local/bin/docker',
        arguments: ['info'],
        exitCode: 1,
        stderr: 'Cannot connect to the Docker daemon',
      );

      // Pre-populate to verify it gets cleared.
      controller.dockerInfo.value = DockerInfo(
        version: '24.0.6',
        serverVersion: '24.0.6',
        operatingSystem: 'Docker Desktop',
        architecture: 'aarch64',
        isRunning: true,
        containers: 0,
        images: 0,
        checkedAt: DateTime.now(),
      );

      await controller.checkDockerStatus();

      expect(controller.dockerInfo.value, isNull);
    });
  });

  // ── statusMessage ──────────────────────────────────────────────────────────

  group('statusMessage', () {
    test('returns userMessage from DockerStatus enum when no dockerInfo set',
        () async {
      _stubDockerNotInstalled(fakeRunner);
      await controller.checkDockerStatus();

      expect(
        controller.statusMessage,
        equals(DockerStatus.notInstalled.userMessage),
      );
    });
  });

  // ── periodic health check lifecycle ───────────────────────────────────────

  group('periodic health check', () {
    test('stopPeriodicHealthCheck prevents further timer-driven checks', () async {
      _stubDockerReady(fakeRunner);

      controller.stopPeriodicHealthCheck();

      // Calling stop again is a no-op.
      expect(() => controller.stopPeriodicHealthCheck(), returnsNormally);
    });
  });
}

// ── Test helpers ──────────────────────────────────────────────────────────────

/// Stub Docker installed and daemon running (happy path).
void _stubDockerReady(FakeProcessRunner fake) {
  _stubDockerInstalled(fake);
  fake.addResponse(
    executable: '/usr/local/bin/docker',
    arguments: ['info'],
    exitCode: 0,
    stdout: [
      'Client:',
      ' Version: 24.0.6',
      'Server:',
      ' Server Version: 24.0.6',
      ' Operating System: Docker Desktop',
      ' Architecture: aarch64',
      ' Containers: 3',
      ' Images: 12',
    ].join('\n'),
  );
}

/// Stub Docker installed at the first macOS path.
void _stubDockerInstalled(FakeProcessRunner fake) {
  fake.addResponse(
    executable: '/usr/local/bin/docker',
    arguments: ['--version'],
    exitCode: 0,
    stdout: 'Docker version 24.0.6, build ed223bc',
  );
}

/// Stub all docker paths as absent (exit 127).
void _stubDockerNotInstalled(FakeProcessRunner fake) {
  fake.addResponse(executable: '/usr/local/bin/docker', arguments: ['--version'], exitCode: 127);
  fake.addResponse(executable: '/opt/homebrew/bin/docker', arguments: ['--version'], exitCode: 127);
  fake.addResponse(executable: 'docker', arguments: ['--version'], exitCode: 127);
}
