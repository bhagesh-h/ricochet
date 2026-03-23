/// Severity levels for a [LogEvent].
enum LogLevel {
  trace,
  info,
  warn,
  error,
}

/// A structured, immutable log entry emitted by services and the orchestrator.
///
/// All observability tests assert on [LogEvent] fields and sequences.
/// Never match raw strings — use the typed fields.
class LogEvent {
  final DateTime timestamp;
  final LogLevel level;
  final String message;

  /// Optional structured context (node id, image name, exit code, …).
  final Map<String, dynamic>? context;

  const LogEvent({
    required this.timestamp,
    required this.level,
    required this.message,
    this.context,
  });

  /// Convenience constructor that stamps [DateTime.now()] automatically.
  factory LogEvent.now(
    LogLevel level,
    String message, {
    Map<String, dynamic>? context,
  }) {
    return LogEvent(
      timestamp: DateTime.now(),
      level: level,
      message: message,
      context: context,
    );
  }

  // ── Shorthand factories ────────────────────────────────────────────────────

  factory LogEvent.trace(String message, {Map<String, dynamic>? context}) =>
      LogEvent.now(LogLevel.trace, message, context: context);

  factory LogEvent.info(String message, {Map<String, dynamic>? context}) =>
      LogEvent.now(LogLevel.info, message, context: context);

  factory LogEvent.warn(String message, {Map<String, dynamic>? context}) =>
      LogEvent.now(LogLevel.warn, message, context: context);

  factory LogEvent.error(String message, {Map<String, dynamic>? context}) =>
      LogEvent.now(LogLevel.error, message, context: context);

  // ── Serialisation ──────────────────────────────────────────────────────────

  Map<String, dynamic> toJson() => {
        'timestamp': timestamp.toIso8601String(),
        'level': level.name,
        'message': message,
        if (context != null) 'context': context,
      };

  factory LogEvent.fromJson(Map<String, dynamic> json) => LogEvent(
        timestamp: DateTime.parse(json['timestamp'] as String),
        level: LogLevel.values.byName(json['level'] as String),
        message: json['message'] as String,
        context: json['context'] as Map<String, dynamic>?,
      );

  @override
  String toString() => '[${level.name.toUpperCase()}] $message';
}
