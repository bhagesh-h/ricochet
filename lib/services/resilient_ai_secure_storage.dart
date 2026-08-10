import 'ai_secure_storage.dart';
import 'flutter_ai_secure_storage.dart';
import 'workspace_ai_secure_storage.dart';

/// Tries OS secure storage first, then falls back to the workspace file store.
class ResilientAiSecureStorage implements AiSecureStorage {
  ResilientAiSecureStorage({
    AiSecureStorage? primary,
    AiSecureStorage? fallback,
  })  : _primary = primary ?? FlutterAiSecureStorage(),
        _fallback = fallback ?? WorkspaceAiSecureStorage();

  final AiSecureStorage _primary;
  final AiSecureStorage _fallback;

  @override
  Future<void> writeApiKey(String value) async {
    try {
      await _primary.writeApiKey(value);
      try {
        await _fallback.deleteApiKey();
      } catch (_) {}
      return;
    } catch (_) {
      await _fallback.writeApiKey(value);
    }
  }

  @override
  Future<String?> readApiKey() async {
    try {
      final value = await _primary.readApiKey();
      if (value != null && value.isNotEmpty) return value;
    } catch (_) {}

    try {
      return await _fallback.readApiKey();
    } catch (_) {
      return null;
    }
  }

  @override
  Future<void> deleteApiKey() async {
    await Future.wait([
      _primary.deleteApiKey().catchError((_) {}),
      _fallback.deleteApiKey().catchError((_) {}),
    ]);
  }
}
