import '../models/ai_connectivity_settings.dart';

/// Opt-in telemetry sink with an explicit allow-list (Phase 0: no-op default).
class AiTelemetryService {
  AiTelemetryService({
    bool Function()? isOptedIn,
    void Function(String event, Map<String, Object?> props)? sink,
  })  : _isOptedIn = isOptedIn ?? (() => false),
        _sink = sink ?? _noopSink;

  final bool Function() _isOptedIn;
  final void Function(String event, Map<String, Object?> props) _sink;

  static void _noopSink(String event, Map<String, Object?> props) {}

  static const allowedEvents = {
    'ai.settings.opened',
    'ai.connection.test_clicked',
    'ai.connection.test_result',
    'ai.generate.clicked',
    'ai.generate.completed',
    'ai.generate.regenerate_clicked',
    'ai.generate.accepted',
    'ai.generate.discarded',
    'ai.command.suggest_clicked',
    'ai.command.suggest_completed',
    'ai.command.regenerate_clicked',
    'ai.command.accepted',
    'ai.error.explain_clicked',
    'ai.search.assist_clicked',
    'ai.review.clicked',
    'ai.review.completed',
    'ai.review.cache_hit',
    'ai.review.refresh_clicked',
  };

  void track(String event, {Map<String, Object?> properties = const {}}) {
    if (!allowedEvents.contains(event)) return;
    if (!_isOptedIn()) return;
    _sink(event, Map<String, Object?>.from(properties));
  }

  void trackTestResult({
    required bool success,
    required AiLatencyBucket latencyBucket,
  }) {
    track(
      'ai.connection.test_result',
      properties: {
        'success': success,
        'latency_bucket': latencyBucket.name,
      },
    );
  }
}
