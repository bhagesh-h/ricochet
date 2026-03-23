import 'dart:convert';
import 'dart:io';

/// Maximum bytes retained per stream before truncation kicks in (5 MB).
const int _kMaxStreamBytes = 5 * 1024 * 1024;

/// Bytes kept at the head and tail of a truncated stream (2.5 MB each).
const int _kHalfMaxBytes = _kMaxStreamBytes ~/ 2;

/// A serialisable snapshot of a single subprocess invocation.
///
/// Used for:
/// - Debugging failures by replaying exact commands.
/// - Regenerating [FakeProcessRunner] scenarios from real runs.
/// - CI artifact upload on failure.
///
/// Large streams (stdout/stderr > 5 MB) are truncated with a head+tail
/// strategy to keep artifacts manageable.
class ExecutionTrace {
  final String executable;
  final List<String> arguments;
  final String? workingDirectory;
  final int exitCode;
  final String stdout;
  final String stderr;
  final DateTime startedAt;
  final DateTime finishedAt;

  /// True when [stdout] was truncated.
  final bool stdoutTruncated;

  /// True when [stderr] was truncated.
  final bool stderrTruncated;

  const ExecutionTrace({
    required this.executable,
    required this.arguments,
    this.workingDirectory,
    required this.exitCode,
    required this.stdout,
    required this.stderr,
    required this.startedAt,
    required this.finishedAt,
    this.stdoutTruncated = false,
    this.stderrTruncated = false,
  });

  Duration get duration => finishedAt.difference(startedAt);

  // ── Factory ────────────────────────────────────────────────────────────────

  /// Build a trace, applying the 5 MB head+tail truncation strategy to each
  /// stream that exceeds the limit.
  factory ExecutionTrace.fromRaw({
    required String executable,
    required List<String> arguments,
    String? workingDirectory,
    required int exitCode,
    required String rawStdout,
    required String rawStderr,
    required DateTime startedAt,
    required DateTime finishedAt,
  }) {
    final (stdout, stdoutTruncated) = _truncate(rawStdout);
    final (stderr, stderrTruncated) = _truncate(rawStderr);

    return ExecutionTrace(
      executable: executable,
      arguments: arguments,
      workingDirectory: workingDirectory,
      exitCode: exitCode,
      stdout: stdout,
      stderr: stderr,
      startedAt: startedAt,
      finishedAt: finishedAt,
      stdoutTruncated: stdoutTruncated,
      stderrTruncated: stderrTruncated,
    );
  }

  // ── Serialisation ──────────────────────────────────────────────────────────

  Map<String, dynamic> toJson() => {
        'executable': executable,
        'arguments': arguments,
        if (workingDirectory != null) 'workingDirectory': workingDirectory,
        'exitCode': exitCode,
        'stdout': stdout,
        'stdoutTruncated': stdoutTruncated,
        'stderr': stderr,
        'stderrTruncated': stderrTruncated,
        'startedAt': startedAt.toIso8601String(),
        'finishedAt': finishedAt.toIso8601String(),
        'durationMs': duration.inMilliseconds,
      };

  factory ExecutionTrace.fromJson(Map<String, dynamic> json) => ExecutionTrace(
        executable: json['executable'] as String,
        arguments: List<String>.from(json['arguments'] as List),
        workingDirectory: json['workingDirectory'] as String?,
        exitCode: json['exitCode'] as int,
        stdout: json['stdout'] as String,
        stderrTruncated: json['stderrTruncated'] as bool? ?? false,
        stderr: json['stderr'] as String,
        stdoutTruncated: json['stdoutTruncated'] as bool? ?? false,
        startedAt: DateTime.parse(json['startedAt'] as String),
        finishedAt: DateTime.parse(json['finishedAt'] as String),
      );

  /// Write this trace as a JSON file next to [runDir].
  Future<File> writeTo(Directory runDir, {String? name}) async {
    final filename = name ??
        '${executable.split(Platform.pathSeparator).last}'
            '_${startedAt.millisecondsSinceEpoch}.trace.json';
    final file = File('${runDir.path}${Platform.pathSeparator}$filename');
    await file.writeAsString(
      const JsonEncoder.withIndent('  ').convert(toJson()),
    );
    return file;
  }
}

/// Returns (possibly truncated string, wasTruncated).
///
/// Head+tail strategy: keep the first 2.5 MB and the last 2.5 MB with a
/// `[TRUNCATED: N bytes omitted]` marker in the middle.
(String, bool) _truncate(String raw) {
  final bytes = utf8.encode(raw);
  if (bytes.length <= _kMaxStreamBytes) return (raw, false);

  final omitted = bytes.length - _kMaxStreamBytes;
  final head = utf8.decode(bytes.sublist(0, _kHalfMaxBytes), allowMalformed: true);
  final tail = utf8.decode(
    bytes.sublist(bytes.length - _kHalfMaxBytes),
    allowMalformed: true,
  );
  final marker = '\n\n[TRUNCATED: $omitted bytes omitted]\n\n';
  return ('$head$marker$tail', true);
}
