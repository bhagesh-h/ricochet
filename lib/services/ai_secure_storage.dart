/// Persists the AI API key outside of settings.json.
abstract class AiSecureStorage {
  static const String apiKeyStorageKey = 'ricochet_ai_api_key';

  Future<void> writeApiKey(String value);
  Future<String?> readApiKey();
  Future<void> deleteApiKey();
}

class InMemoryAiSecureStorage implements AiSecureStorage {
  String? _value;

  @override
  Future<void> deleteApiKey() async {
    _value = null;
  }

  @override
  Future<String?> readApiKey() async => _value;

  @override
  Future<void> writeApiKey(String value) async {
    _value = value;
  }
}
