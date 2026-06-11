import 'dart:async';
import 'dart:io';

/// Abstract interface for running child processes.
///
/// All production code that spawns a subprocess must go through this
/// interface so tests can inject a [FakeProcessRunner] without touching
/// the real OS.
abstract class ProcessRunner {
  /// Run [executable] with [arguments] and wait for it to finish.
  ///
  /// If [timeout] is supplied the process is killed via [kill] if it has
  /// not exited within that duration and a [TimeoutException] is thrown.
  Future<ProcessResult> run(
    String executable,
    List<String> arguments, {
    String? workingDirectory,
    Map<String, String>? environment,
    bool runInShell = false,
    Duration? timeout,
  });

  /// Start [executable] with [arguments] without waiting for it to finish.
  ///
  /// The caller is responsible for consuming stdout/stderr and for calling
  /// [kill] if the process must be terminated early.
  Future<Process> start(
    String executable,
    List<String> arguments, {
    String? workingDirectory,
    Map<String, String>? environment,
    bool runInShell = false,
  });

  /// Gracefully terminate [process].
  ///
  /// Sends SIGTERM (or `taskkill` on Windows) first.  If the process has not
  /// exited within [gracePeriod] (default 5 seconds) it is hard-killed with
  /// SIGKILL (or `taskkill /F` on Windows).  This two-step guarantee prevents
  /// zombie processes in CI when Docker pulls or bio-pipeline containers ignore
  /// SIGTERM.
  Future<void> kill(
    Process process, {
    ProcessSignal signal = ProcessSignal.sigterm,
    Duration gracePeriod = const Duration(seconds: 5),
  });
}

/// Production implementation that delegates to [Process.run] / [Process.start].
class SystemProcessRunner implements ProcessRunner {
  const SystemProcessRunner();

  @override
  Future<ProcessResult> run(
    String executable,
    List<String> arguments, {
    String? workingDirectory,
    Map<String, String>? environment,
    bool runInShell = false,
    Duration? timeout,
  }) async {
    if (timeout == null) {
      return Process.run(
        executable,
        arguments,
        workingDirectory: workingDirectory,
        environment: environment,
        runInShell: runInShell,
      );
    }

    // Timeout path: start the process and race against a timer.
    final process = await Process.start(
      executable,
      arguments,
      workingDirectory: workingDirectory,
      environment: environment,
      runInShell: runInShell,
    );

    bool timedOut = false;
    final timer = Future<void>.delayed(timeout, () async {
      timedOut = true;
      await kill(process);
    });

    // Collect output while the process runs.
    final stdoutBuffer = StringBuffer();
    final stderrBuffer = StringBuffer();
    final stdoutDone = process.stdout
        .transform(const SystemEncoding().decoder)
        .listen(stdoutBuffer.write)
        .asFuture<void>();
    final stderrDone = process.stderr
        .transform(const SystemEncoding().decoder)
        .listen(stderrBuffer.write)
        .asFuture<void>();

    final exitCode = await Future.any([
      process.exitCode,
      timer.then((_) => -1),
    ]);

    await Future.wait([stdoutDone, stderrDone]);

    if (timedOut) {
      throw TimeoutException(
        'Process "$executable" exceeded timeout of $timeout',
        timeout,
      );
    }

    return ProcessResult(
      process.pid,
      exitCode,
      stdoutBuffer.toString(),
      stderrBuffer.toString(),
    );
  }

  @override
  Future<Process> start(
    String executable,
    List<String> arguments, {
    String? workingDirectory,
    Map<String, String>? environment,
    bool runInShell = false,
  }) {
    return Process.start(
      executable,
      arguments,
      workingDirectory: workingDirectory,
      environment: environment,
      runInShell: runInShell,
    );
  }

  @override
  Future<void> kill(
    Process process, {
    ProcessSignal signal = ProcessSignal.sigterm,
    Duration gracePeriod = const Duration(seconds: 5),
  }) async {
    // Step 1: polite termination.
    process.kill(signal);

    // Step 2: escalate to SIGKILL if the process ignores SIGTERM.
    await process.exitCode
        .timeout(gracePeriod, onTimeout: () => _forceKill(process));
  }

  int _forceKill(Process process) {
    process.kill(ProcessSignal.sigkill);
    return -1;
  }
}
