import 'package:flutter_test/flutter_test.dart';

import 'package:Ricochet/services/ai_telemetry_service.dart';

void main() {
  test('track is no-op when telemetry opt-in is false', () {
    var called = false;
    final telemetry = AiTelemetryService(
      isOptedIn: () => false,
      sink: (_, __) => called = true,
    );

    telemetry.track('ai.review.clicked');

    expect(called, isFalse);
  });

  test('track forwards allow-listed events when opted in', () {
    String? eventName;
    final telemetry = AiTelemetryService(
      isOptedIn: () => true,
      sink: (event, _) => eventName = event,
    );

    telemetry.track('ai.review.clicked');

    expect(eventName, 'ai.review.clicked');
  });

  test('track ignores events outside allow-list', () {
    var called = false;
    final telemetry = AiTelemetryService(
      isOptedIn: () => true,
      sink: (_, __) => called = true,
    );

    telemetry.track('ai.secret.event');

    expect(called, isFalse);
  });
}
