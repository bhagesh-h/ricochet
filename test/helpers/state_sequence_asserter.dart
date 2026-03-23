import 'package:flutter_test/flutter_test.dart';

/// Asserts that an observable sequence of states matches [expected] exactly,
/// in order.
///
/// Usage:
/// ```dart
/// final states = <DockerStatus>[];
/// controller.status.listen(states.add);
///
/// await controller.checkDockerStatus();
///
/// StateSequenceAsserter.assertSequence(
///   actual: states,
///   expected: [DockerStatus.checking, DockerStatus.running],
/// );
/// ```
abstract final class StateSequenceAsserter {
  StateSequenceAsserter._();

  /// Assert that [actual] equals [expected] in order and length.
  ///
  /// Prints a human-readable diff on failure to make it obvious which
  /// transition was wrong.
  static void assertSequence<T>({
    required List<T> actual,
    required List<T> expected,
    String? reason,
  }) {
    if (actual.length != expected.length) {
      fail(
        '${reason ?? 'State sequence mismatch'}:\n'
        '  Expected ${expected.length} states: $expected\n'
        '  Actual   ${actual.length} states:   $actual',
      );
    }

    for (var i = 0; i < expected.length; i++) {
      if (actual[i] != expected[i]) {
        fail(
          '${reason ?? 'State sequence mismatch'} at index $i:\n'
          '  Expected: ${expected[i]}\n'
          '  Actual:   ${actual[i]}\n'
          '  Full sequence — expected: $expected\n'
          '  Full sequence — actual:   $actual',
        );
      }
    }
  }

  /// Assert that [actual] **contains** [expected] as a contiguous subsequence,
  /// useful when the full sequence includes intermediate states you don't want
  /// to enumerate.
  static void assertContainsSubsequence<T>({
    required List<T> actual,
    required List<T> expected,
    String? reason,
  }) {
    if (expected.isEmpty) return;

    for (var start = 0; start <= actual.length - expected.length; start++) {
      if (actual.sublist(start, start + expected.length)
          .indexed
          .every((rec) => rec.$2 == expected[rec.$1])) {
        return; // found
      }
    }

    fail(
      '${reason ?? 'Expected subsequence not found'}:\n'
      '  Looking for: $expected\n'
      '  In sequence: $actual',
    );
  }

  /// Assert that [actual] ends with [expected] — useful for checking final
  /// settled state without caring about transient intermediate states.
  static void assertEndsWith<T>({
    required List<T> actual,
    required List<T> expected,
    String? reason,
  }) {
    if (expected.isEmpty) return;
    if (actual.length < expected.length) {
      fail(
        '${reason ?? 'assertEndsWith'}:\n'
        '  Sequence too short (${actual.length}) to end with $expected',
      );
    }
    final tail = actual.sublist(actual.length - expected.length);
    expect(tail, equals(expected), reason: reason ?? 'state sequence tail mismatch');
  }
}
