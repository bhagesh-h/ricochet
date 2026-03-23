import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:Ricochet/models/log_event.dart';
import 'package:Ricochet/models/execution_trace.dart';

import '../helpers/log_event_matchers.dart';
import '../helpers/test_workspace_factory.dart';

void main() {
  // ── LogEvent construction ────────────────────────────────────────────────

  group('LogEvent construction', () {
    test('shorthand factories set the correct level', () {
      expect(LogEvent.trace('t').level, equals(LogLevel.trace));
      expect(LogEvent.info('i').level, equals(LogLevel.info));
      expect(LogEvent.warn('w').level, equals(LogLevel.warn));
      expect(LogEvent.error('e').level, equals(LogLevel.error));
    });

    test('LogEvent.now stamps a current timestamp', () {
      final before = DateTime.now();
      final event = LogEvent.now(LogLevel.info, 'hello');
      final after = DateTime.now();

      expect(event.timestamp.isAfter(before) || event.timestamp.isAtSameMomentAs(before), isTrue);
      expect(event.timestamp.isBefore(after) || event.timestamp.isAtSameMomentAs(after), isTrue);
    });

    test('context map is preserved', () {
      final event = LogEvent.error('failed', context: {'exitCode': 1, 'image': 'staphb/fastqc'});
      expect(event.context!['exitCode'], equals(1));
      expect(event.context!['image'], equals('staphb/fastqc'));
    });

    test('context is optional and defaults to null', () {
      final event = LogEvent.info('ok');
      expect(event.context, isNull);
    });
  });

  // ── LogEvent serialisation ──────────────────────────────────────────────

  group('LogEvent toJson / fromJson round-trip', () {
    test('round-trips a full event with context', () {
      final original = LogEvent(
        timestamp: DateTime(2024, 6, 1, 12, 0, 0),
        level: LogLevel.warn,
        message: 'image pull slow',
        context: {'layerId': 'abc123', 'percentage': 0.45},
      );

      final json = original.toJson();
      final restored = LogEvent.fromJson(json);

      expect(restored.level, equals(original.level));
      expect(restored.message, equals(original.message));
      expect(restored.timestamp, equals(original.timestamp));
      expect(restored.context!['layerId'], equals('abc123'));
    });

    test('json contains ISO-8601 timestamp string', () {
      final event = LogEvent.info('ts test');
      final json = event.toJson();
      expect(json['timestamp'], isA<String>());
      expect(() => DateTime.parse(json['timestamp'] as String), returnsNormally);
    });

    test('json contains the level name string', () {
      final event = LogEvent.error('boom');
      expect(event.toJson()['level'], equals('error'));
    });
  });

  // ── Log sequence matchers ──────────────────────────────────────────────

  group('log sequence matchers', () {
    test('isLogEvent matches exact level and message', () {
      final event = LogEvent.info('Docker started');
      expect(event, isLogEvent(level: LogLevel.info, message: 'Docker started'));
    });

    test('isLogEvent does NOT match wrong level', () {
      final event = LogEvent.warn('Docker started');
      expect(event, isNot(isLogEvent(level: LogLevel.info, message: 'Docker started')));
    });

    test('isLogEventContaining matches level and message substring', () {
      final event = LogEvent.error('Pull failed at layer abc123');
      expect(
        event,
        isLogEventContaining(level: LogLevel.error, messageContaining: 'abc123'),
      );
    });

    test('expectErrorLogged passes when list contains an error event', () {
      final events = [
        LogEvent.info('started'),
        LogEvent.error('something went wrong'),
      ];
      expectErrorLogged(events); // must not throw
    });

    test('expectErrorLogged fails when list has no error events', () {
      final events = [LogEvent.info('fine'), LogEvent.warn('minor')];
      expect(
        () => expectErrorLogged(events),
        throwsA(isA<TestFailure>()),
      );
    });

    test('expectLogSequence validates level + message pairs in order', () {
      final events = [
        LogEvent.info('step 1'),
        LogEvent.warn('step 2'),
        LogEvent.error('step 3'),
      ];
      expectLogSequence(events, [
        (LogLevel.info, 'step 1'),
        (LogLevel.warn, 'step 2'),
        (LogLevel.error, 'step 3'),
      ]);
    });

    test('expectMonotonicallyIncreasingTimestamps passes for sorted events', () {
      final t0 = DateTime(2024, 1, 1, 0, 0, 0);
      final events = [
        LogEvent(timestamp: t0, level: LogLevel.info, message: 'a'),
        LogEvent(timestamp: t0.add(const Duration(milliseconds: 1)), level: LogLevel.info, message: 'b'),
        LogEvent(timestamp: t0.add(const Duration(milliseconds: 2)), level: LogLevel.info, message: 'c'),
      ];
      expectMonotonicallyIncreasingTimestamps(events); // must not throw
    });

    test('expectMonotonicallyIncreasingTimestamps fails for reversed events', () {
      final t0 = DateTime(2024, 1, 1, 12, 0, 0);
      final events = [
        LogEvent(timestamp: t0, level: LogLevel.info, message: 'a'),
        LogEvent(timestamp: t0.subtract(const Duration(seconds: 1)), level: LogLevel.info, message: 'b'),
      ];
      expect(
        () => expectMonotonicallyIncreasingTimestamps(events),
        throwsA(isA<TestFailure>()),
      );
    });
  });

  // ── ExecutionTrace truncation ─────────────────────────────────────────────

  group('ExecutionTrace truncation', () {
    const kMaxBytes = 5 * 1024 * 1024; // 5 MB

    test('small stdout passes through unmodified', () {
      final trace = ExecutionTrace.fromRaw(
        executable: 'docker',
        arguments: ['run'],
        exitCode: 0,
        rawStdout: 'small output',
        rawStderr: '',
        startedAt: DateTime.now(),
        finishedAt: DateTime.now(),
      );
      expect(trace.stdout, equals('small output'));
      expect(trace.stdoutTruncated, isFalse);
    });

    test('large stdout is truncated and marked', () {
      // Generate 6 MB of data — 1 MB above the 5 MB cap.
      final big = 'x' * (kMaxBytes + 1024 * 1024);
      final trace = ExecutionTrace.fromRaw(
        executable: 'docker',
        arguments: ['pull', 'large:image'],
        exitCode: 0,
        rawStdout: big,
        rawStderr: '',
        startedAt: DateTime.now(),
        finishedAt: DateTime.now(),
      );
      expect(trace.stdoutTruncated, isTrue);
      expect(trace.stdout, contains('[TRUNCATED:'));
      // Truncated output must be ≤ 5 MB + marker overhead.
      expect(utf8.encode(trace.stdout).length, lessThanOrEqualTo(kMaxBytes + 200));
    });

    test('small stderr passes through unmodified', () {
      final trace = ExecutionTrace.fromRaw(
        executable: 'docker',
        arguments: ['info'],
        exitCode: 0,
        rawStdout: '',
        rawStderr: 'warning only',
        startedAt: DateTime.now(),
        finishedAt: DateTime.now(),
      );
      expect(trace.stderr, equals('warning only'));
      expect(trace.stderrTruncated, isFalse);
    });

    test('large stderr is truncated independently of stdout', () {
      final bigStderr = 'e' * (kMaxBytes + 512 * 1024);
      final trace = ExecutionTrace.fromRaw(
        executable: 'docker',
        arguments: ['logs'],
        exitCode: 1,
        rawStdout: 'tiny',
        rawStderr: bigStderr,
        startedAt: DateTime.now(),
        finishedAt: DateTime.now(),
      );
      expect(trace.stdoutTruncated, isFalse);
      expect(trace.stderrTruncated, isTrue);
    });

    test('truncated output preserves head and tail characters', () {
      final data = 'HEAD' + ('m' * (kMaxBytes + 100 * 1024)) + 'TAIL';
      final trace = ExecutionTrace.fromRaw(
        executable: 'cmd',
        arguments: [],
        exitCode: 0,
        rawStdout: data,
        rawStderr: '',
        startedAt: DateTime.now(),
        finishedAt: DateTime.now(),
      );
      expect(trace.stdout, startsWith('HEAD'));
      expect(trace.stdout, endsWith('TAIL'));
    });
  });

  // ── ExecutionTrace serialisation ────────────────────────────────────────

  group('ExecutionTrace toJson / fromJson round-trip', () {
    test('round-trips all fields', () {
      final start = DateTime(2024, 6, 1, 0, 0, 0);
      final finish = start.add(const Duration(seconds: 5));
      final original = ExecutionTrace(
        executable: 'docker',
        arguments: ['pull', 'ubuntu:22.04'],
        workingDirectory: '/tmp/pipeline',
        exitCode: 0,
        stdout: 'pull output',
        stderr: '',
        startedAt: start,
        finishedAt: finish,
      );

      final json = original.toJson();
      final restored = ExecutionTrace.fromJson(json);

      expect(restored.executable, equals('docker'));
      expect(restored.arguments, equals(['pull', 'ubuntu:22.04']));
      expect(restored.workingDirectory, equals('/tmp/pipeline'));
      expect(restored.exitCode, equals(0));
      expect(restored.stdout, equals('pull output'));
      expect(restored.startedAt, equals(start));
      expect(restored.finishedAt, equals(finish));
    });

    test('duration is computed from startedAt and finishedAt', () {
      final start = DateTime(2024, 1, 1);
      final finish = start.add(const Duration(seconds: 42));
      final trace = ExecutionTrace(
        executable: 'cmd',
        arguments: [],
        exitCode: 0,
        stdout: '',
        stderr: '',
        startedAt: start,
        finishedAt: finish,
      );
      expect(trace.duration, equals(const Duration(seconds: 42)));
    });
  });

  // ── ExecutionTrace writeTo ──────────────────────────────────────────────

  group('ExecutionTrace writeTo', () {
    final List<Directory> dirsToClean = [];

    setUp(() {
      dirsToClean.clear();
    });

    tearDown(() async {
      for (final d in List<Directory>.from(dirsToClean)) {
        await TestWorkspaceFactory.cleanup(d);
      }
      dirsToClean.clear();
    });

    test('writes a .trace.json file containing valid JSON', () async {
      final dir = await TestWorkspaceFactory.create(prefix: 'trace_write_test');
      dirsToClean.add(dir);
      final trace = ExecutionTrace(
        executable: 'docker',
        arguments: ['run', '--rm', 'staphb/fastqc:latest'],
        exitCode: 0,
        stdout: 'FastQC output',
        stderr: '',
        startedAt: DateTime.now(),
        finishedAt: DateTime.now(),
      );

      final file = await trace.writeTo(dir);

      expect(await file.exists(), isTrue);
      expect(file.path, endsWith('.trace.json'));

      final contents = await file.readAsString();
      final decoded = jsonDecode(contents) as Map<String, dynamic>;
      expect(decoded['executable'], equals('docker'));
      expect(decoded['exitCode'], equals(0));
    });

    test('written JSON can be deserialized back to ExecutionTrace', () async {
      final dir = await TestWorkspaceFactory.create(prefix: 'trace_roundtrip_test');
      dirsToClean.add(dir);
      final original = ExecutionTrace(
        executable: 'docker',
        arguments: ['info'],
        exitCode: 0,
        stdout: 'Server Version: 24.0.6',
        stderr: '',
        startedAt: DateTime(2024, 3, 15),
        finishedAt: DateTime(2024, 3, 15, 0, 0, 1),
      );

      final file = await original.writeTo(dir);
      final restored = ExecutionTrace.fromJson(
        jsonDecode(await file.readAsString()) as Map<String, dynamic>,
      );

      expect(restored.executable, equals(original.executable));
      expect(restored.exitCode, equals(original.exitCode));
      expect(restored.stdout, equals(original.stdout));
    });
  });
}
