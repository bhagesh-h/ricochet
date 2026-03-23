import 'dart:async';
import 'dart:io';

import 'package:Ricochet/services/process_runner.dart';

import 'failure_matrix.dart';

/// A fake [Process] used inside [FakeProcessRunner].
class _FakeProcess implements Process {
  final int _exitCode;
  final Stream<List<int>> _stdout;
  final Stream<List<int>> _stderr;
  bool _sigtermIgnored;

  _FakeProcess({
    required int exitCode,
    Stream<List<int>>? stdout,
    Stream<List<int>>? stderr,
    bool sigtermIgnored = false,
  })  : _exitCode = exitCode,
        _stdout = stdout ?? const Stream.empty(),
        _stderr = stderr ?? const Stream.empty(),
        _sigtermIgnored = sigtermIgnored;

  @override
  int get pid => 0;

  @override
  Future<int> get exitCode => Future.value(_exitCode);

  @override
  Stream<List<int>> get stdout => _stdout;

  @override
  Stream<List<int>> get stderr => _stderr;

  @override
  IOSink get stdin => throw UnimplementedError('FakeProcess.stdin not used in tests');

  @override
  bool kill([ProcessSignal signal = ProcessSignal.sigterm]) {
    if (signal == ProcessSignal.sigterm && _sigtermIgnored) {
      // Simulate a process that ignores SIGTERM.
      return true;
    }
    return true;
  }
}

/// A scenario-mapped, deterministic [ProcessRunner] for tests.
///
/// Configure it with [addResponse] before running a test:
/// ```dart
/// fake.addResponse(
///   executable: 'docker',
///   arguments: ['--version'],
///   exitCode: 0,
///   stdout: 'Docker version 24.0.6',
/// );
/// ```
///
/// Responses are keyed by `executable:arg0:arg1:…`.  Use [addFailureScenario]
/// to register an entire [FailureScenario] at once.
class FakeProcessRunner implements ProcessRunner {
  final Map<String, _FakeResponse> _responses = {};
  final List<_RecordedCall> recordedCalls = [];

  // ── Registration helpers ─────────────────────────────────────────────────

  void addResponse({
    required String executable,
    List<String> arguments = const [],
    int exitCode = 0,
    String stdout = '',
    String stderr = '',
    Duration? delay,
    bool sigtermIgnored = false,
    Duration? hangDuration,
  }) {
    final key = _key(executable, arguments);
    _responses[key] = _FakeResponse(
      exitCode: exitCode,
      stdout: stdout,
      stderr: stderr,
      delay: delay,
      sigtermIgnored: sigtermIgnored,
      hangDuration: hangDuration,
    );
  }

  /// Register all responses defined by a [FailureScenario].
  void addFailureScenario(FailureScenario scenario) {
    for (final stub in scenario.processStubs) {
      addResponse(
        executable: stub.executable,
        arguments: stub.arguments,
        exitCode: stub.exitCode,
        stdout: stub.stdout,
        stderr: stub.stderr,
        delay: stub.delay,
        sigtermIgnored: stub.sigtermIgnored,
        hangDuration: stub.hangDuration,
      );
    }
  }

  // ── ProcessRunner implementation ─────────────────────────────────────────

  @override
  Future<ProcessResult> run(
    String executable,
    List<String> arguments, {
    String? workingDirectory,
    Map<String, String>? environment,
    bool runInShell = false,
    Duration? timeout,
  }) async {
    final response = _responseFor(executable, arguments);
    recordedCalls.add(_RecordedCall(executable: executable, arguments: arguments));

    if (response.hangDuration != null) {
      // Simulate a hanging process.
      if (timeout != null && timeout < response.hangDuration!) {
        await Future<void>.delayed(timeout);
        throw TimeoutException(
          'FakeProcessRunner: "$executable" simulated hang exceeded timeout $timeout',
          timeout,
        );
      }
      await Future<void>.delayed(response.hangDuration!);
    } else if (response.delay != null) {
      await Future<void>.delayed(response.delay!);
    }

    return ProcessResult(0, response.exitCode, response.stdout, response.stderr);
  }

  @override
  Future<Process> start(
    String executable,
    List<String> arguments, {
    String? workingDirectory,
    Map<String, String>? environment,
    bool runInShell = false,
  }) async {
    final response = _responseFor(executable, arguments);
    recordedCalls.add(_RecordedCall(executable: executable, arguments: arguments));

    if (response.delay != null) {
      await Future<void>.delayed(response.delay!);
    }

    final stdoutCtrl = StreamController<List<int>>();
    final stderrCtrl = StreamController<List<int>>();

    // Emit output asynchronously so callers can set up listeners first.
    Future<void>.microtask(() {
      if (response.stdout.isNotEmpty) {
        stdoutCtrl.add(response.stdout.codeUnits.map((c) => c).toList());
      }
      stdoutCtrl.close();
      if (response.stderr.isNotEmpty) {
        stderrCtrl.add(response.stderr.codeUnits.map((c) => c).toList());
      }
      stderrCtrl.close();
    });

    return _FakeProcess(
      exitCode: response.exitCode,
      stdout: stdoutCtrl.stream,
      stderr: stderrCtrl.stream,
      sigtermIgnored: response.sigtermIgnored,
    );
  }

  @override
  Future<void> kill(
    Process process, {
    ProcessSignal signal = ProcessSignal.sigterm,
    Duration gracePeriod = const Duration(seconds: 5),
  }) async {
    process.kill(signal);
    // In tests the fake process always exits immediately on SIGKILL.
    if (process is _FakeProcess && process._sigtermIgnored) {
      process.kill(ProcessSignal.sigkill);
    }
  }

  // ── Helpers ───────────────────────────────────────────────────────────────

  String _key(String executable, List<String> arguments) =>
      [executable, ...arguments].join(':');

  _FakeResponse _responseFor(String executable, List<String> arguments) {
    final key = _key(executable, arguments);
    return _responses[key] ??
        _FakeResponse(
          exitCode: 1,
          stderr: 'FakeProcessRunner: no response configured for "$key"',
        );
  }

  /// Assert that [executable] was called with [arguments] at least once.
  void verifyCall(String executable, List<String> arguments) {
    final key = _key(executable, arguments);
    final found = recordedCalls.any(
      (c) => _key(c.executable, c.arguments) == key,
    );
    if (!found) {
      throw AssertionError(
        'FakeProcessRunner: expected call to "$key" but it was never made.\n'
        'Recorded calls: ${recordedCalls.map((c) => _key(c.executable, c.arguments)).toList()}',
      );
    }
  }
}

// ── Internal data classes ────────────────────────────────────────────────────

class _FakeResponse {
  final int exitCode;
  final String stdout;
  final String stderr;
  final Duration? delay;
  final bool sigtermIgnored;
  final Duration? hangDuration;

  const _FakeResponse({
    required this.exitCode,
    this.stdout = '',
    this.stderr = '',
    this.delay,
    this.sigtermIgnored = false,
    this.hangDuration,
  });
}

class _RecordedCall {
  final String executable;
  final List<String> arguments;
  const _RecordedCall({required this.executable, required this.arguments});
}
