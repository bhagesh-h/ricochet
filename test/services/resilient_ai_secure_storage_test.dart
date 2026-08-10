import 'package:flutter_test/flutter_test.dart';

import 'package:Ricochet/services/ai_secure_storage.dart';
import 'package:Ricochet/services/resilient_ai_secure_storage.dart';

class _ThrowingSecureStorage implements AiSecureStorage {
  @override
  Future<void> deleteApiKey() async {
    throw Exception('keychain unavailable');
  }

  @override
  Future<String?> readApiKey() async {
    throw Exception('keychain unavailable');
  }

  @override
  Future<void> writeApiKey(String value) async {
    throw Exception('keychain unavailable');
  }
}

void main() {
  test('falls back to secondary storage when primary storage fails', () async {
    final fallback = InMemoryAiSecureStorage();
    final storage = ResilientAiSecureStorage(
      primary: _ThrowingSecureStorage(),
      fallback: fallback,
    );

    await storage.writeApiKey('sk-test-key');
    expect(await storage.readApiKey(), 'sk-test-key');
    await storage.deleteApiKey();
    expect(await storage.readApiKey(), isNull);
  });
}
