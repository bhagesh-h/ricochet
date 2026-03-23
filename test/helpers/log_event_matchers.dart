import 'package:flutter_test/flutter_test.dart';
import 'package:Ricochet/models/log_event.dart';

// ─────────────────────────────────────────────────────────────────────────────
// Custom Matchers
// ─────────────────────────────────────────────────────────────────────────────

/// Returns a [Matcher] that matches a [LogEvent] with [level] and a [message]
/// that **equals** [message].
///
/// Prefer this over `log.contains(someString)`.
Matcher isLogEvent({required LogLevel level, required String message}) =>
    _LogEventMatcher(level: level, message: message, exact: true);

/// Returns a [Matcher] that matches a [LogEvent] with [level] and a [message]
/// that **contains** [messageContaining].
///
/// Use only in [ExpectedOutcome] comparisons; never in raw test assertions.
Matcher isLogEventContaining({
  required LogLevel level,
  required String messageContaining,
}) =>
    _LogEventMatcher(level: level, message: messageContaining, exact: false);

/// Returns a [Matcher] that matches a single [LogLevel].
Matcher hasLevel(LogLevel level) => _LevelMatcher(level);

// ─────────────────────────────────────────────────────────────────────────────
// Assertion helpers
// ─────────────────────────────────────────────────────────────────────────────

/// Assert that [events] contains at least one error-level event.
void expectErrorLogged(List<LogEvent> events, {String? reason}) {
  expect(
    events.any((e) => e.level == LogLevel.error),
    isTrue,
    reason: reason ?? 'Expected at least one error-level LogEvent',
  );
}

/// Assert exact [LogEvent] sequence by level and message.
///
/// [expected] is a list of `(LogLevel, String message)` records.
void expectLogSequence(
  List<LogEvent> actual,
  List<(LogLevel, String)> expected, {
  String? reason,
}) {
  if (actual.length != expected.length) {
    fail(
      '${reason ?? 'Log sequence mismatch'}:\n'
      '  Expected ${expected.length} events:\n'
      '${expected.map((e) => '    [${e.$1.name}] ${e.$2}').join('\n')}\n'
      '  Actual ${actual.length} events:\n'
      '${actual.map((e) => '    [${e.level.name}] ${e.message}').join('\n')}',
    );
  }

  for (var i = 0; i < expected.length; i++) {
    final (expectedLevel, expectedMsg) = expected[i];
    final actual_ = actual[i];
    if (actual_.level != expectedLevel || actual_.message != expectedMsg) {
      fail(
        '${reason ?? 'Log event mismatch'} at index $i:\n'
        '  Expected: [${expectedLevel.name}] $expectedMsg\n'
        '  Actual:   [${actual_.level.name}] ${actual_.message}',
      );
    }
  }
}

/// Assert that all events in [events] have a [LogEvent.timestamp] that
/// increases monotonically (or is equal).
void expectMonotonicallyIncreasingTimestamps(
  List<LogEvent> events, {
  String? reason,
}) {
  for (var i = 1; i < events.length; i++) {
    if (events[i].timestamp.isBefore(events[i - 1].timestamp)) {
      fail(
        '${reason ?? 'Timestamps not monotonically increasing'} at index $i:\n'
        '  events[$i - 1].timestamp = ${events[i - 1].timestamp}\n'
        '  events[$i].timestamp     = ${events[i].timestamp}',
      );
    }
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Private Matcher implementations
// ─────────────────────────────────────────────────────────────────────────────

class _LogEventMatcher extends Matcher {
  final LogLevel level;
  final String message;
  final bool exact;

  const _LogEventMatcher({
    required this.level,
    required this.message,
    required this.exact,
  });

  @override
  bool matches(Object? item, Map<Object?, Object?> matchState) {
    if (item is! LogEvent) return false;
    if (item.level != level) return false;
    return exact ? item.message == message : item.message.contains(message);
  }

  @override
  Description describe(Description description) {
    final op = exact ? 'equals' : 'contains';
    return description.add('LogEvent(level: $level, message $op: "$message")');
  }

  @override
  Description describeMismatch(
    Object? item,
    Description mismatchDescription,
    Map<Object?, Object?> matchState,
    bool verbose,
  ) {
    if (item is! LogEvent) {
      return mismatchDescription.add('was not a LogEvent');
    }
    return mismatchDescription.add(
      'was LogEvent(level: ${item.level}, message: "${item.message}")',
    );
  }
}

class _LevelMatcher extends Matcher {
  final LogLevel level;
  const _LevelMatcher(this.level);

  @override
  bool matches(Object? item, Map<Object?, Object?> matchState) =>
      item is LogEvent && item.level == level;

  @override
  Description describe(Description description) =>
      description.add('LogEvent with level $level');
}
