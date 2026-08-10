import 'dart:async';
import 'dart:convert';

import 'package:http/http.dart' as http;

import '../models/ai_connectivity_settings.dart';
import '../theme/ai_motion_tokens.dart';

class AiCancelToken {
  bool _cancelled = false;
  bool get isCancelled => _cancelled;
  void cancel() => _cancelled = true;
}

class AiTestResult {
  final bool success;
  final String message;
  final Duration latency;
  final AiLatencyBucket latencyBucket;
  final String? modelResponseSnippet;

  const AiTestResult({
    required this.success,
    required this.message,
    required this.latency,
    required this.latencyBucket,
    this.modelResponseSnippet,
  });
}

class AiServiceException implements Exception {
  final String message;
  const AiServiceException(this.message);

  @override
  String toString() => message;
}

/// OpenAI-compatible chat client for AI Assistant connectivity.
class AiService {
  AiService({http.Client? client}) : _client = client ?? http.Client();

  final http.Client _client;

  Uri _chatCompletionsUri(String baseUrl) =>
      Uri.parse('$baseUrl/chat/completions');

  Map<String, String> _headers(String? apiKey) {
    final headers = <String, String>{
      'Content-Type': 'application/json',
    };
    if (apiKey != null && apiKey.isNotEmpty) {
      headers['Authorization'] = 'Bearer $apiKey';
    }
    return headers;
  }

  Future<AiTestResult> testConnection({
    required AiConnectivitySettings settings,
    String? apiKey,
  }) async {
    final baseUrl = settings.normalizedBaseUrl;
    if (baseUrl.isEmpty) {
      return AiTestResult(
        success: false,
        message: 'Enter a base URL for your AI provider.',
        latency: Duration.zero,
        latencyBucket: AiLatencyBucket.fast,
      );
    }
    if (settings.model.trim().isEmpty) {
      return AiTestResult(
        success: false,
        message: 'Enter a model name.',
        latency: Duration.zero,
        latencyBucket: AiLatencyBucket.fast,
      );
    }

    final started = DateTime.now();
    var timedOut = false;

    try {
      final response = await _client
          .post(
            _chatCompletionsUri(baseUrl),
            headers: _headers(apiKey),
            body: jsonEncode({
              'model': settings.model.trim(),
              'messages': [
                {'role': 'user', 'content': 'ping'},
              ],
              'max_tokens': 5,
            }),
          )
          .timeout(
            Duration(seconds: settings.timeoutSeconds),
            onTimeout: () {
              timedOut = true;
              throw TimeoutException('Connection timed out');
            },
          );

      final elapsed = DateTime.now().difference(started);
      final bucket = AiLatencyBucket.fromDuration(elapsed, timedOut: timedOut);

      if (response.statusCode == 401 || response.statusCode == 403) {
        return AiTestResult(
          success: false,
          message: 'API key rejected.',
          latency: elapsed,
          latencyBucket: bucket,
        );
      }

      if (response.statusCode < 200 || response.statusCode >= 300) {
        return AiTestResult(
          success: false,
          message:
              'Server responded with HTTP ${response.statusCode}. Check URL and model.',
          latency: elapsed,
          latencyBucket: bucket,
        );
      }

      final body = jsonDecode(response.body);
      if (body is! Map<String, dynamic> ||
          body['choices'] is! List ||
          (body['choices'] as List).isEmpty) {
        return AiTestResult(
          success: false,
          message: 'Server responded but is not OpenAI-compatible.',
          latency: elapsed,
          latencyBucket: bucket,
        );
      }

      final choice = body['choices'].first;
      String? content;
      if (choice is Map<String, dynamic>) {
        final message = choice['message'];
        if (message is Map) {
          content = message['content']?.toString();
        }
      }
      final snippet = content?.toString().trim();

      final minLatency = elapsed < AiMotionTokens.testConnectionMinSuccess
          ? AiMotionTokens.testConnectionMinSuccess
          : elapsed;

      return AiTestResult(
        success: true,
        message: 'Connected successfully.',
        latency: minLatency,
        latencyBucket: bucket,
        modelResponseSnippet:
            snippet != null && snippet.isNotEmpty ? snippet : 'OK',
      );
    } on TimeoutException {
      final elapsed = DateTime.now().difference(started);
      return AiTestResult(
        success: false,
        message:
            'Connection timed out after ${settings.timeoutSeconds}s. Try a smaller model or increase timeout.',
        latency: elapsed,
        latencyBucket: AiLatencyBucket.slow,
      );
    } catch (e) {
      final elapsed = DateTime.now().difference(started);
      return AiTestResult(
        success: false,
        message: 'Cannot reach server — check URL, firewall, and that the service is running.',
        latency: elapsed,
        latencyBucket: AiLatencyBucket.fromDuration(elapsed, timedOut: timedOut),
      );
    }
  }

  Stream<String> streamChat({
    required AiConnectivitySettings settings,
    String? apiKey,
    required List<Map<String, String>> messages,
    AiCancelToken? cancelToken,
  }) {
    return _streamChatImpl(
      settings: settings,
      apiKey: apiKey,
      messages: messages,
      cancelToken: cancelToken,
    );
  }

  Stream<String> _streamChatImpl({
    required AiConnectivitySettings settings,
    String? apiKey,
    required List<Map<String, String>> messages,
    AiCancelToken? cancelToken,
  }) async* {
    final timeout = Duration(seconds: settings.timeoutSeconds);
    final deadline = DateTime.now().add(timeout);

    void checkDeadline() {
      if (DateTime.now().isAfter(deadline)) {
        throw AiServiceException(
          'Request timed out after ${settings.timeoutSeconds}s. Try a smaller model or increase timeout.',
        );
      }
    }
    final baseUrl = settings.normalizedBaseUrl;
    if (baseUrl.isEmpty) {
      throw const AiServiceException('Enter a base URL for your AI provider.');
    }
    if (settings.model.trim().isEmpty) {
      throw const AiServiceException('Enter a model name.');
    }

    final request = http.Request('POST', _chatCompletionsUri(baseUrl));
    request.headers.addAll(_headers(apiKey));
    request.body = jsonEncode({
      'model': settings.model.trim(),
      'messages': messages,
      'stream': true,
      'temperature': settings.temperature,
      'max_tokens': settings.maxTokens,
    });

    final response = await _client.send(request).timeout(
      timeout,
      onTimeout: () {
        throw AiServiceException(
          'Request timed out after ${settings.timeoutSeconds}s. Try a smaller model or increase timeout.',
        );
      },
    );
    if (response.statusCode == 401 || response.statusCode == 403) {
      throw const AiServiceException('API key rejected.');
    }
    if (response.statusCode < 200 || response.statusCode >= 300) {
      throw AiServiceException(
        'Server responded with HTTP ${response.statusCode}.',
      );
    }

    final lines = response.stream
        .transform(utf8.decoder)
        .transform(const LineSplitter())
        .timeout(
          timeout,
          onTimeout: (sink) {
            sink.addError(
              AiServiceException(
                'Request timed out after ${settings.timeoutSeconds}s. Try a smaller model or increase timeout.',
              ),
            );
            sink.close();
          },
        );

    await for (final line in lines) {
      checkDeadline();
      if (cancelToken?.isCancelled == true) break;
      if (!line.startsWith('data:')) continue;
      final payload = line.substring(5).trim();
      if (payload == '[DONE]') break;
      if (payload.isEmpty) continue;

      try {
        final decoded = jsonDecode(payload);
        if (decoded is! Map<String, dynamic>) continue;
        final choices = decoded['choices'];
        if (choices is! List || choices.isEmpty) continue;
        final choice = choices.first;
        if (choice is! Map) continue;
        final delta = choice['delta'];
        if (delta is! Map) continue;
        final content = delta['content'];
        if (content is String && content.isNotEmpty) {
          yield content;
        }
      } catch (_) {
        continue;
      }
    }
  }

  void dispose() => _client.close();
}
