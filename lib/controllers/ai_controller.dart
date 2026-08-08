import 'dart:async';

import 'package:get/get.dart';

import '../models/ai_connectivity_settings.dart';
import '../models/ai_prompt_bundle.dart';
import '../models/pipeline_node.dart';
import '../services/ai_prompt_builder.dart';
import '../services/ai_secure_storage.dart';
import '../services/ai_service.dart';
import '../services/ai_telemetry_service.dart';
import '../services/settings_service.dart';
import '../theme/ai_motion_tokens.dart';

enum AiCommandSuggestPhase {
  idle,
  streaming,
  proposed,
  error,
}

enum AiPillState {
  hidden,
  disconnected,
  connecting,
  ready,
  readyLocal,
  error,
}

enum AiConnectionTestPhase {
  idle,
  probing,
  success,
  failure,
}

enum AiExplainPhase {
  idle,
  streaming,
  complete,
  error,
}

enum AiSearchAssistPhase {
  idle,
  streaming,
  complete,
  error,
}

class AiController extends GetxController {
  AiController({
    SettingsService? settingsService,
    AiSecureStorage? secureStorage,
    AiService? aiService,
    AiTelemetryService? telemetryService,
  })  : _settingsService = settingsService ?? SettingsService(),
        _secureStorage = secureStorage ?? InMemoryAiSecureStorage(),
        _aiService = aiService ?? AiService(),
        _telemetry = telemetryService ?? AiTelemetryService();

  final SettingsService _settingsService;
  final AiSecureStorage _secureStorage;
  final AiService _aiService;
  final AiTelemetryService _telemetry;

  final connectivity = const AiConnectivitySettings().obs;
  final apiKey = ''.obs;
  final isLoading = true.obs;
  final isSaving = false.obs;

  final pillState = AiPillState.hidden.obs;
  final testPhase = AiConnectionTestPhase.idle.obs;
  final testMessage = ''.obs;
  final testSnippet = RxnString();
  final testLatencyMs = 0.obs;
  final inFlightRequestCount = 0.obs;

  AiTestResult? _lastTestResult;

  // Command suggest (Phase 1)
  final commandPhase = AiCommandSuggestPhase.idle.obs;
  final commandStreamText = ''.obs;
  final commandProposed = ''.obs;
  final commandOriginal = ''.obs;
  final commandElapsedSec = 0.obs;
  final commandTruncated = false.obs;
  final commandRegenerateCount = 0.obs;
  final commandError = ''.obs;
  final commandNodeId = ''.obs;
  final commandParamKey = ''.obs;

  // Error explain (Phase 3)
  final explainPhase = AiExplainPhase.idle.obs;
  final explainStreamText = ''.obs;
  final explainResult = ''.obs;
  final explainErrorMessage = ''.obs;
  final explainElapsedSec = 0.obs;
  final explainNodeId = ''.obs;
  final explainTruncated = false.obs;

  // NL Docker search assist (Phase 3)
  final searchAssistPhase = AiSearchAssistPhase.idle.obs;
  final searchAssistStreamText = ''.obs;
  final searchAssistQuery = ''.obs;
  final searchAssistError = ''.obs;
  final searchAssistElapsedSec = 0.obs;

  AiPromptBundle? _cachedBundle;
  String? _lastSuggestion;
  AiCancelToken? _commandCancel;
  AiCancelToken? _explainCancel;
  AiCancelToken? _searchCancel;
  Timer? _commandElapsedTimer;
  Timer? _explainElapsedTimer;
  Timer? _searchElapsedTimer;
  DateTime? _commandStarted;
  DateTime? _explainStarted;
  DateTime? _searchStarted;

  static const String enabledTooltip =
      'Connect any OpenAI-compatible API — cloud providers or localhost (Ollama, LM Studio).';

  @override
  void onInit() {
    super.onInit();
    loadSettings();
  }

  @override
  void onClose() {
    _commandElapsedTimer?.cancel();
    _explainElapsedTimer?.cancel();
    _searchElapsedTimer?.cancel();
    _commandCancel?.cancel();
    _explainCancel?.cancel();
    _searchCancel?.cancel();
    _aiService.dispose();
    super.onClose();
  }

  Future<void> loadSettings() async {
    isLoading.value = true;
    final settings = await _settingsService.load();
    connectivity.value = settings.aiAssistant;
    try {
      apiKey.value = await _secureStorage.readApiKey() ?? '';
    } catch (_) {
      apiKey.value = '';
    }
    _refreshPillState();
    isLoading.value = false;
  }

  void _refreshPillState() {
    if (!connectivity.value.enabled) {
      pillState.value = AiPillState.hidden;
      return;
    }
    if (inFlightRequestCount.value > 0 ||
        testPhase.value == AiConnectionTestPhase.probing) {
      pillState.value = AiPillState.connecting;
      return;
    }
    if (_lastTestResult != null && !_lastTestResult!.success) {
      pillState.value = AiPillState.error;
      return;
    }
    if (!connectivity.value.connectionVerified) {
      pillState.value = AiPillState.disconnected;
      return;
    }
    pillState.value = connectivity.value.isLoopbackHost
        ? AiPillState.readyLocal
        : AiPillState.ready;
  }

  void _beginRequest() {
    inFlightRequestCount.value++;
    _refreshPillState();
  }

  void _endRequest() {
    if (inFlightRequestCount.value > 0) {
      inFlightRequestCount.value--;
    }
    _refreshPillState();
  }

  /// Shared in-flight tracking for draft/review controllers.
  void trackInflightRequestStart() => _beginRequest();

  void trackInflightRequestEnd() => _endRequest();

  void trackCommandAccepted() {
    _telemetry.track('ai.command.accepted');
  }

  Future<void> saveConnectivity(AiConnectivitySettings next) async {
    isSaving.value = true;
    final previous = connectivity.value;
    connectivity.value = next;
    try {
      final current = await _settingsService.load();
      await _settingsService.save(current.copyWith(aiAssistant: next));
      _refreshPillState();
      await _persistApiKeyBestEffort();
    } catch (_) {
      connectivity.value = previous;
      _refreshPillState();
      rethrow;
    } finally {
      isSaving.value = false;
    }
  }

  Future<void> _persistApiKeyBestEffort() async {
    try {
      if (apiKey.value.isEmpty) {
        await _secureStorage.deleteApiKey();
      } else {
        await _secureStorage.writeApiKey(apiKey.value);
      }
    } catch (_) {
      // Connectivity toggles must not fail when OS keychain is unavailable.
    }
  }

  Future<void> setEnabled(bool enabled) async {
    await saveConnectivity(connectivity.value.copyWith(enabled: enabled));
  }

  Future<void> applyPreset(AiProviderPreset preset) async {
    if (preset == AiProviderPreset.custom) {
      await saveConnectivity(
        connectivity.value.copyWith(
          providerPreset: preset,
          connectionVerified: false,
        ),
      );
      return;
    }
    final url = AiConnectivitySettings.presetUrlTemplates[preset] ?? '';
    final modelHint = AiConnectivitySettings.presetModelHints[preset] ?? '';
    await saveConnectivity(
      connectivity.value.copyWith(
        providerPreset: preset,
        baseUrl: url,
        model: connectivity.value.model.isEmpty
            ? modelHint
            : connectivity.value.model,
        connectionVerified: false,
      ),
    );
  }

  void onBaseUrlChanged(String url) {
    var nextPreset = connectivity.value.providerPreset;
    final probe = connectivity.value.copyWith(baseUrl: url);
    if (nextPreset != AiProviderPreset.custom &&
        !probe.urlMatchesPreset(nextPreset)) {
      nextPreset = AiProviderPreset.custom;
    }
    connectivity.value = probe.copyWith(
      providerPreset: nextPreset,
      connectionVerified: false,
    );
    _refreshPillState();
  }

  Future<void> persistConnectivityAndKey() async {
    await saveConnectivity(connectivity.value);
  }

  Future<void> testConnection() async {
    _telemetry.track('ai.connection.test_clicked');
    testPhase.value = AiConnectionTestPhase.probing;
    testMessage.value = 'Resolving host…';
    testSnippet.value = null;
    _beginRequest();

    try {
      await Future<void>.delayed(const Duration(milliseconds: 200));
      if (testPhase.value != AiConnectionTestPhase.probing) return;
      testMessage.value = 'Handshaking…';

      final result = await _aiService.testConnection(
        settings: connectivity.value,
        apiKey: apiKey.value.isEmpty ? null : apiKey.value,
      );

      _lastTestResult = result;
      _telemetry.trackTestResult(
        success: result.success,
        latencyBucket: result.latencyBucket,
      );

      if (result.success) {
        testPhase.value = AiConnectionTestPhase.success;
        testMessage.value = result.message;
        testSnippet.value = result.modelResponseSnippet;
        testLatencyMs.value = result.latency.inMilliseconds;
        await saveConnectivity(
          connectivity.value.copyWith(connectionVerified: true),
        );
      } else {
        testPhase.value = AiConnectionTestPhase.failure;
        testMessage.value = result.message;
        testLatencyMs.value = result.latency.inMilliseconds;
        await saveConnectivity(
          connectivity.value.copyWith(connectionVerified: false),
        );
      }
    } finally {
      _endRequest();
      _refreshPillState();
    }
  }

  void resetTestPhase() {
    if (testPhase.value == AiConnectionTestPhase.probing) return;
    testPhase.value = AiConnectionTestPhase.idle;
  }

  void notifySettingsOpened() {
    _telemetry.track('ai.settings.opened');
  }

  bool get canSuggestCommand =>
      connectivity.value.enabled && connectivity.value.connectionVerified;

  void clearCommandSuggestIfNodeChanged(String nodeId) {
    if (commandNodeId.value.isNotEmpty && commandNodeId.value != nodeId) {
      discardCommandSuggestion();
    }
  }

  Future<void> suggestCommand({
    required PipelineNode node,
    required String paramKey,
    required String partialCommand,
    required List<PipelineNode> allNodes,
    required List<Connection> connections,
    bool regenerate = false,
  }) async {
    if (!canSuggestCommand) {
      commandPhase.value = AiCommandSuggestPhase.error;
      commandError.value =
          'Enable AI Assistant and run Test Connection in Settings first.';
      return;
    }

    if (regenerate) {
      if (_lastSuggestion == null) return;
      _telemetry.track('ai.command.regenerate_clicked');
    } else {
      _telemetry.track('ai.command.suggest_clicked');
      commandOriginal.value = partialCommand;
      commandRegenerateCount.value = 0;
    }

    // Always rebuild from the current canvas so regenerate (and any
    // upstream connection / parameter edits) never reuse a stale prompt.
    _cachedBundle = AiPromptBuilder.forCommand(
      targetNode: node,
      allNodes: allNodes,
      connections: connections,
      partialCommand: partialCommand,
      paramKey: paramKey,
    );

    commandNodeId.value = node.id;
    commandParamKey.value = paramKey;
    commandTruncated.value = _cachedBundle?.contextTruncated ?? false;
    commandStreamText.value = '';
    commandProposed.value = '';
    commandError.value = '';
    commandPhase.value = AiCommandSuggestPhase.streaming;

    final messages = regenerate
        ? _cachedBundle!.regenerateMessages(_lastSuggestion!)
        : _cachedBundle!.initialMessages();

    if (regenerate) {
      commandRegenerateCount.value++;
    }

    _commandCancel?.cancel();
    _commandCancel = AiCancelToken();
    _beginRequest();
    _startCommandElapsedTimer();

    final started = DateTime.now();
    final buffer = StringBuffer();

    try {
      await for (final token in _aiService.streamChat(
        settings: connectivity.value,
        apiKey: apiKey.value.isEmpty ? null : apiKey.value,
        messages: messages,
        cancelToken: _commandCancel,
      )) {
        buffer.write(token);
        commandStreamText.value = buffer.toString();
      }

      if (_commandCancel?.isCancelled == true) {
        commandPhase.value = AiCommandSuggestPhase.idle;
        return;
      }

      final cleaned = extractShellCommand(buffer.toString());
      if (cleaned.trim().isEmpty) {
        throw const AiServiceException('Model returned an empty command.');
      }

      _lastSuggestion = cleaned;
      commandProposed.value = cleaned;
      commandPhase.value = AiCommandSuggestPhase.proposed;

      final elapsed = DateTime.now().difference(started);
      _telemetry.track(
        'ai.command.suggest_completed',
        properties: {
          'success': true,
          'latency_bucket': AiLatencyBucket.fromDuration(elapsed, timedOut: false)
              .name,
          'is_regenerate': regenerate,
        },
      );
    } on AiServiceException catch (e) {
      commandPhase.value = AiCommandSuggestPhase.error;
      commandError.value = e.message;
      _telemetry.track(
        'ai.command.suggest_completed',
        properties: {
          'success': false,
          'latency_bucket': AiLatencyBucket.slow.name,
          'is_regenerate': regenerate,
        },
      );
    } catch (_) {
      commandPhase.value = AiCommandSuggestPhase.error;
      commandError.value = 'Could not complete suggestion. Try again.';
      _telemetry.track(
        'ai.command.suggest_completed',
        properties: {
          'success': false,
          'latency_bucket': AiLatencyBucket.slow.name,
          'is_regenerate': regenerate,
        },
      );
    } finally {
      _stopCommandElapsedTimer();
      _endRequest();
    }
  }

  Future<void> regenerateCommand({
    required PipelineNode node,
    required String paramKey,
    required String partialCommand,
    required List<PipelineNode> allNodes,
    required List<Connection> connections,
  }) {
    return suggestCommand(
      node: node,
      paramKey: paramKey,
      partialCommand: partialCommand,
      allNodes: allNodes,
      connections: connections,
      regenerate: true,
    );
  }

  void cancelCommandSuggestion() {
    _commandCancel?.cancel();
    _stopCommandElapsedTimer();
    commandPhase.value = AiCommandSuggestPhase.idle;
    commandStreamText.value = '';
  }

  void discardCommandSuggestion() {
    cancelCommandSuggestion();
    commandProposed.value = '';
    commandOriginal.value = '';
    _cachedBundle = null;
    _lastSuggestion = null;
    commandRegenerateCount.value = 0;
    commandNodeId.value = '';
    commandParamKey.value = '';
  }

  String get commandWaitingLabel => _waitingLabel(commandElapsedSec.value, 'Suggesting…');

  String get explainWaitingLabel => _waitingLabel(explainElapsedSec.value, 'Explaining…');

  String get searchAssistWaitingLabel =>
      _waitingLabel(searchAssistElapsedSec.value, 'Finding tools…');

  String _waitingLabel(int sec, String prefix) {
    if (sec < AiMotionTokens.latencyThresholdSlow.inSeconds) {
      return prefix;
    }
    if (sec < AiMotionTokens.latencyThresholdVerySlow.inSeconds) {
      return 'Thinking… ${sec}s';
    }
    return 'Still working… ${sec}s';
  }

  Future<void> explainError({
    required PipelineNode node,
  }) async {
    if (!canSuggestCommand) {
      explainPhase.value = AiExplainPhase.error;
      explainErrorMessage.value =
          'Enable AI Assistant and run Test Connection in Settings first.';
      return;
    }

    _telemetry.track('ai.error.explain_clicked');
    explainNodeId.value = node.id;
    explainStreamText.value = '';
    explainResult.value = '';
    explainErrorMessage.value = '';
    explainPhase.value = AiExplainPhase.streaming;

    final commandParam = node.parameters.firstWhereOrNull((p) => p.key == 'command');
    final logExcerpt = buildLogExcerpt(node.logs);
    explainTruncated.value = isLogExcerptTruncated(node.logs);

    final messages = AiPromptBuilder.forErrorExplain(
      nodeTitle: node.title,
      dockerImage: node.dockerImage,
      command: commandParam?.value?.toString(),
      logExcerpt: logExcerpt,
      truncated: explainTruncated.value,
    );

    _explainCancel?.cancel();
    _explainCancel = AiCancelToken();
    _beginRequest();
    _startExplainElapsedTimer();

    final buffer = StringBuffer();
    try {
      await for (final token in _aiService.streamChat(
        settings: connectivity.value,
        apiKey: apiKey.value.isEmpty ? null : apiKey.value,
        messages: messages,
        cancelToken: _explainCancel,
      )) {
        buffer.write(token);
        explainStreamText.value = buffer.toString();
      }

      if (_explainCancel?.isCancelled == true) {
        explainPhase.value = AiExplainPhase.idle;
        return;
      }

      final cleaned = buffer.toString().trim();
      if (cleaned.isEmpty) {
        throw const AiServiceException('Model returned an empty explanation.');
      }

      explainResult.value = cleaned;
      explainPhase.value = AiExplainPhase.complete;
    } on AiServiceException catch (e) {
      explainPhase.value = AiExplainPhase.error;
      explainErrorMessage.value = e.message;
    } catch (_) {
      explainPhase.value = AiExplainPhase.error;
      explainErrorMessage.value = 'Could not explain this error. Try again.';
    } finally {
      _stopExplainElapsedTimer();
      _endRequest();
    }
  }

  void dismissErrorExplain() {
    _explainCancel?.cancel();
    _stopExplainElapsedTimer();
    explainPhase.value = AiExplainPhase.idle;
    explainStreamText.value = '';
    explainResult.value = '';
    explainErrorMessage.value = '';
    explainNodeId.value = '';
    explainTruncated.value = false;
  }

  void clearExplainIfNodeChanged(String nodeId) {
    if (explainNodeId.value.isNotEmpty && explainNodeId.value != nodeId) {
      dismissErrorExplain();
    }
  }

  Future<String?> assistDockerSearch(String naturalLanguageQuery) async {
    final query = naturalLanguageQuery.trim();
    if (query.isEmpty) return null;

    if (!canSuggestCommand) {
      searchAssistPhase.value = AiSearchAssistPhase.error;
      searchAssistError.value =
          'Enable AI Assistant and run Test Connection in Settings first.';
      return null;
    }

    _telemetry.track('ai.search.assist_clicked');
    searchAssistStreamText.value = '';
    searchAssistQuery.value = '';
    searchAssistError.value = '';
    searchAssistPhase.value = AiSearchAssistPhase.streaming;

    final messages = AiPromptBuilder.forDockerSearchAssist(
      naturalLanguageQuery: query,
    );

    _searchCancel?.cancel();
    _searchCancel = AiCancelToken();
    _beginRequest();
    _startSearchElapsedTimer();

    final buffer = StringBuffer();
    try {
      await for (final token in _aiService.streamChat(
        settings: connectivity.value,
        apiKey: apiKey.value.isEmpty ? null : apiKey.value,
        messages: messages,
        cancelToken: _searchCancel,
      )) {
        buffer.write(token);
        searchAssistStreamText.value = buffer.toString();
      }

      if (_searchCancel?.isCancelled == true) {
        searchAssistPhase.value = AiSearchAssistPhase.idle;
        return null;
      }

      final cleaned = extractSearchQuery(buffer.toString());
      if (cleaned.isEmpty) {
        throw const AiServiceException('Model returned an empty search query.');
      }

      searchAssistQuery.value = cleaned;
      searchAssistPhase.value = AiSearchAssistPhase.complete;
      return cleaned;
    } on AiServiceException catch (e) {
      searchAssistPhase.value = AiSearchAssistPhase.error;
      searchAssistError.value = e.message;
      return null;
    } catch (_) {
      searchAssistPhase.value = AiSearchAssistPhase.error;
      searchAssistError.value = 'Could not suggest a search. Try again.';
      return null;
    } finally {
      _stopSearchElapsedTimer();
      _endRequest();
    }
  }

  void dismissSearchAssist() {
    _searchCancel?.cancel();
    _stopSearchElapsedTimer();
    searchAssistPhase.value = AiSearchAssistPhase.idle;
    searchAssistStreamText.value = '';
    searchAssistQuery.value = '';
    searchAssistError.value = '';
  }

  void _startCommandElapsedTimer() {
    _commandStarted = DateTime.now();
    commandElapsedSec.value = 0;
    _commandElapsedTimer?.cancel();
    _commandElapsedTimer = Timer.periodic(const Duration(seconds: 1), (_) {
      if (_commandStarted == null) return;
      commandElapsedSec.value =
          DateTime.now().difference(_commandStarted!).inSeconds;
    });
  }

  void _stopCommandElapsedTimer() {
    _commandElapsedTimer?.cancel();
    _commandElapsedTimer = null;
    _commandStarted = null;
  }

  void _startExplainElapsedTimer() {
    _explainStarted = DateTime.now();
    explainElapsedSec.value = 0;
    _explainElapsedTimer?.cancel();
    _explainElapsedTimer = Timer.periodic(const Duration(seconds: 1), (_) {
      if (_explainStarted == null) return;
      explainElapsedSec.value =
          DateTime.now().difference(_explainStarted!).inSeconds;
    });
  }

  void _stopExplainElapsedTimer() {
    _explainElapsedTimer?.cancel();
    _explainElapsedTimer = null;
    _explainStarted = null;
  }

  void _startSearchElapsedTimer() {
    _searchStarted = DateTime.now();
    searchAssistElapsedSec.value = 0;
    _searchElapsedTimer?.cancel();
    _searchElapsedTimer = Timer.periodic(const Duration(seconds: 1), (_) {
      if (_searchStarted == null) return;
      searchAssistElapsedSec.value =
          DateTime.now().difference(_searchStarted!).inSeconds;
    });
  }

  void _stopSearchElapsedTimer() {
    _searchElapsedTimer?.cancel();
    _searchElapsedTimer = null;
    _searchStarted = null;
  }

  String get pillLabel {
    switch (pillState.value) {
      case AiPillState.hidden:
        return '';
      case AiPillState.disconnected:
        return 'AI · Setup';
      case AiPillState.connecting:
        return 'AI · Connecting';
      case AiPillState.ready:
        return 'AI · Ready';
      case AiPillState.readyLocal:
        return 'AI · Local';
      case AiPillState.error:
        return 'AI · Error';
    }
  }
}
