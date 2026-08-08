import 'package:flutter/foundation.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';

import 'ai_secure_storage.dart';

class FlutterAiSecureStorage implements AiSecureStorage {
  FlutterAiSecureStorage({FlutterSecureStorage? storage})
      : _storage = storage ??
            const FlutterSecureStorage(
              mOptions: MacOsOptions(
                useDataProtectionKeyChain: false,
              ),
            );

  @visibleForTesting
  FlutterAiSecureStorage.inject(FlutterSecureStorage storage) : _storage = storage;

  final FlutterSecureStorage _storage;

  @override
  Future<void> deleteApiKey() =>
      _storage.delete(key: AiSecureStorage.apiKeyStorageKey);

  @override
  Future<String?> readApiKey() =>
      _storage.read(key: AiSecureStorage.apiKeyStorageKey);

  @override
  Future<void> writeApiKey(String value) => _storage.write(
        key: AiSecureStorage.apiKeyStorageKey,
        value: value,
      );
}
