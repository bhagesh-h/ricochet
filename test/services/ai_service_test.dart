import 'dart:convert';
import 'dart:async';

import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';

import 'package:Ricochet/models/ai_connectivity_settings.dart';
import 'package:Ricochet/services/ai_service.dart';

void main() {
  group('AiService.testConnection', () {
    test('fails when base URL is empty', () async {
      final service = AiService();
      final result = await service.testConnection(
        settings: const AiConnectivitySettings(model: 'm'),
        apiKey: null,
      );
      expect(result.success, isFalse);
      service.dispose();
    });

    test('succeeds on OpenAI-compatible response', () async {
      final client = MockClient((request) async {
        expect(request.url.path, endsWith('/chat/completions'));
        return http.Response(
          jsonEncode({
            'choices': [
              {
                'message': {'content': 'pong'},
              },
            ],
          }),
          200,
        );
      });

      final service = AiService(client: client);
      final result = await service.testConnection(
        settings: const AiConnectivitySettings(
          baseUrl: 'http://127.0.0.1:11434/v1',
          model: 'llama3.2',
        ),
      );

      expect(result.success, isTrue);
      expect(result.modelResponseSnippet, 'pong');
      service.dispose();
    });

    test('reports auth failure', () async {
      final client = MockClient((_) async => http.Response('nope', 401));
      final service = AiService(client: client);
      final result = await service.testConnection(
        settings: const AiConnectivitySettings(
          baseUrl: 'https://api.openai.com/v1',
          model: 'gpt-4o-mini',
        ),
        apiKey: 'bad',
      );
      expect(result.success, isFalse);
      expect(result.message, contains('API key'));
      service.dispose();
    });
  });

  group('AiService.streamChat', () {
    test('times out on a stalled stream', () async {
      final service = AiService(client: _StallHttpClient());
      final settings = const AiConnectivitySettings(
        baseUrl: 'http://127.0.0.1:11434/v1',
        model: 'llama3.2',
        timeoutSeconds: 1,
      );

      await expectLater(
        service
            .streamChat(
              settings: settings,
              messages: const [
                {'role': 'user', 'content': 'hi'},
              ],
            )
            .drain(),
        throwsA(isA<AiServiceException>().having(
          (e) => e.message,
          'message',
          contains('timed out'),
        )),
      );
      service.dispose();
    });
  });
}

class _StallHttpClient extends http.BaseClient {
  @override
  Future<http.StreamedResponse> send(http.BaseRequest request) async {
    final controller = StreamController<List<int>>();
    return http.StreamedResponse(
      controller.stream,
      200,
      headers: {'content-type': 'text/event-stream'},
    );
  }
}
