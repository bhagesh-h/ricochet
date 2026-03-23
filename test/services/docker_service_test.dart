import 'package:flutter_test/flutter_test.dart';
import 'package:Ricochet/models/docker_info.dart';
import 'package:Ricochet/models/docker_pull_progress.dart';
import 'package:Ricochet/services/docker_service.dart';

import '../helpers/fake_process_runner.dart';
import '../helpers/failure_matrix.dart';

void main() {
  late FakeProcessRunner fakeRunner;
  late DockerService service;

  setUp(() {
    fakeRunner = FakeProcessRunner();
    service = DockerService.withRunner(fakeRunner);
  });

  // ── isDockerInstalled ───────────────────────────────────────────────────────

  group('isDockerInstalled', () {
    test('returns true when docker --version exits 0 on first path', () async {
      fakeRunner.addResponse(
        executable: '/usr/local/bin/docker',
        arguments: ['--version'],
        exitCode: 0,
        stdout: 'Docker version 24.0.6, build ed223bc',
      );

      expect(await service.isDockerInstalled(), isTrue);
    });

    test('returns true when found on fallback PATH entry', () async {
      // All specific paths fail; fallback "docker" succeeds.
      fakeRunner.addResponse(executable: '/usr/local/bin/docker', arguments: ['--version'], exitCode: 127);
      fakeRunner.addResponse(executable: '/opt/homebrew/bin/docker', arguments: ['--version'], exitCode: 127);
      fakeRunner.addResponse(executable: 'docker', arguments: ['--version'], exitCode: 0, stdout: 'Docker version 24.0.6');

      expect(await service.isDockerInstalled(), isTrue);
    });

    test('returns false when no docker path responds — failure matrix scenario', () async {
      final scenario = scenarioById('docker_not_installed_v1');
      fakeRunner.addFailureScenario(scenario);

      final installed = await service.isDockerInstalled();

      expect(installed, isFalse);
      expect(
        scenario.expected.dockerStatusName,
        equals('notInstalled'),
        reason: 'Scenario contract: expected status is notInstalled',
      );
    });
  });

  // ── isDockerRunning ─────────────────────────────────────────────────────────

  group('isDockerRunning', () {
    test('returns true when docker info exits 0', () async {
      _stubDockerInstalled(fakeRunner);
      fakeRunner.addResponse(
        executable: '/usr/local/bin/docker',
        arguments: ['info'],
        exitCode: 0,
        stdout: 'Server Version: 24.0.6',
      );

      expect(await service.isDockerRunning(), isTrue);
    });

    test('returns false when docker info exits non-zero (daemon stopped)', () async {
      _stubDockerInstalled(fakeRunner);
      fakeRunner.addResponse(
        executable: '/usr/local/bin/docker',
        arguments: ['info'],
        exitCode: 1,
        stderr: 'Cannot connect to the Docker daemon',
      );

      expect(await service.isDockerRunning(), isFalse);
    });
  });

  // ── getDockerStatus ─────────────────────────────────────────────────────────

  group('getDockerStatus', () {
    test('returns notInstalled when docker is not found', () async {
      final scenario = scenarioById('docker_not_installed_v1');
      fakeRunner.addFailureScenario(scenario);

      final status = await service.getDockerStatus();

      expect(status, equals(DockerStatus.notInstalled));
    });

    test('returns stopped when installed but daemon not running', () async {
      _stubDockerInstalled(fakeRunner);
      fakeRunner.addResponse(
        executable: '/usr/local/bin/docker',
        arguments: ['info'],
        exitCode: 1,
        stderr: 'Cannot connect to the Docker daemon',
      );

      expect(await service.getDockerStatus(), equals(DockerStatus.stopped));
    });

    test('returns running when installed and daemon responds', () async {
      _stubDockerInstalled(fakeRunner);
      fakeRunner.addResponse(
        executable: '/usr/local/bin/docker',
        arguments: ['info'],
        exitCode: 0,
        stdout: 'Server Version: 24.0.6',
      );

      expect(await service.getDockerStatus(), equals(DockerStatus.running));
    });
  });

  // ── pullImage stream parsing ────────────────────────────────────────────────

  group('pullImage', () {
    test('emits starting, downloading, and complete events for a successful pull', () async {
      _stubDockerInstalled(fakeRunner);
      // Provide a realistic Docker pull output.
      fakeRunner.addResponse(
        executable: '/usr/local/bin/docker',
        arguments: ['pull', 'staphb/fastqc:latest'],
        exitCode: 0,
        stdout: [
          'latest: Pulling from staphb/fastqc',
          'abc1234567890: Pulling fs layer',
          'abc1234567890: Download complete',
          'abc1234567890: Pull complete',
          'Status: Downloaded newer image for staphb/fastqc:latest',
        ].join('\n'),
      );

      final events = await service.pullImage('staphb/fastqc:latest').toList();

      expect(events, isNotEmpty);
      expect(
        events.first.status,
        anyOf(equals(PullStatus.starting), equals(PullStatus.downloading)),
        reason: 'First event must be starting or downloading',
      );
      expect(
        events.last.status,
        equals(PullStatus.complete),
        reason: 'Final event must be complete',
      );
    });

    test('emits error event on pull failure — failure matrix scenario', () async {
      // The scenario already stubs its own docker --version (executable: 'docker').
      // Do NOT call _stubDockerInstalled here — the path discovery will fall
      // through the full-path stubs and reach the plain 'docker' fallback.
      final scenario = scenarioById('image_pull_fails_mid_layer_v1');
      fakeRunner.addFailureScenario(scenario);

      final events = await service.pullImage('staphb/fastqc:latest').toList();

      expect(
        events.any((e) => e.status == PullStatus.error),
        isTrue,
        reason: 'At least one error event must be emitted on pull failure',
      );
    });
  });

  // ── imageExists ─────────────────────────────────────────────────────────────

  group('imageExists', () {
    test('returns true when docker images -q returns a non-empty id', () async {
      _stubDockerInstalled(fakeRunner);
      fakeRunner.addResponse(
        executable: '/usr/local/bin/docker',
        arguments: ['images', '-q', 'staphb/fastqc:latest'],
        exitCode: 0,
        stdout: 'sha256:abc123',
      );

      expect(await service.imageExists('staphb/fastqc:latest'), isTrue);
    });

    test('returns false when docker images -q returns empty', () async {
      _stubDockerInstalled(fakeRunner);
      fakeRunner.addResponse(
        executable: '/usr/local/bin/docker',
        arguments: ['images', '-q', 'nonexistent:latest'],
        exitCode: 0,
        stdout: '',
      );

      expect(await service.imageExists('nonexistent:latest'), isFalse);
    });
  });
}

// ── Test helpers ──────────────────────────────────────────────────────────────

/// Stub the docker --version check so the service finds it at the macOS Intel path.
void _stubDockerInstalled(FakeProcessRunner fake) {
  fake.addResponse(
    executable: '/usr/local/bin/docker',
    arguments: ['--version'],
    exitCode: 0,
    stdout: 'Docker version 24.0.6, build ed223bc',
  );
}
