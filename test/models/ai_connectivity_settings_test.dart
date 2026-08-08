import 'package:flutter_test/flutter_test.dart';

import 'package:Ricochet/models/ai_connectivity_settings.dart';

void main() {
  test('preset URL templates are not pre-filled in defaults', () {
    const settings = AiConnectivitySettings();
    expect(settings.baseUrl, isEmpty);
    expect(settings.providerPreset, AiProviderPreset.custom);
  });

  test('manual URL diverges from preset', () {
    const settings = AiConnectivitySettings(
      providerPreset: AiProviderPreset.ollama,
      baseUrl: 'http://127.0.0.1:11434/v1',
    );
    expect(settings.urlMatchesPreset(AiProviderPreset.ollama), isTrue);
    expect(
      settings.copyWith(baseUrl: 'http://example.com/v1').urlMatchesPreset(
        AiProviderPreset.ollama,
      ),
      isFalse,
    );
  });

  test('isLoopbackHost detects localhost endpoints', () {
    expect(
      const AiConnectivitySettings(baseUrl: 'http://127.0.0.1:11434/v1')
          .isLoopbackHost,
      isTrue,
    );
    expect(
      const AiConnectivitySettings(baseUrl: 'https://api.openai.com/v1')
          .isLoopbackHost,
      isFalse,
    );
  });

  test('json round trip preserves ai fields', () {
    const original = AiConnectivitySettings(
      enabled: true,
      providerPreset: AiProviderPreset.openai,
      baseUrl: 'https://api.openai.com/v1',
      model: 'gpt-4o-mini',
      connectionVerified: true,
      telemetryOptIn: true,
    );
    final restored = AiConnectivitySettings.fromJson(original.toJson());
    expect(restored.enabled, isTrue);
    expect(restored.model, 'gpt-4o-mini');
    expect(restored.connectionVerified, isTrue);
    expect(restored.telemetryOptIn, isTrue);
  });
}
