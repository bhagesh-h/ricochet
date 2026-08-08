import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:get/get.dart';

import 'package:Ricochet/controllers/ai_controller.dart';
import 'package:Ricochet/models/ai_connectivity_settings.dart';
import 'package:Ricochet/models/app_settings.dart';
import 'package:Ricochet/models/pipeline_node.dart';
import 'package:Ricochet/services/ai_secure_storage.dart';
import 'package:Ricochet/services/ai_service.dart';
import 'package:Ricochet/services/settings_service.dart';

PipelineNode _node(String id, {String title = 'Align'}) => PipelineNode(
      id: id,
      title: title,
      description: '',
      position: Offset.zero,
      category: BlockCategory.processing,
      iconCodePoint: '0xe8d5',
      parameters: [],
    );

class _FakeSettingsService extends SettingsService {
  AppSettings stored = const AppSettings();

  @override
  Future<AppSettings> load() async => stored;

  @override
  Future<void> save(AppSettings settings) async {
    stored = settings;
  }
}

class _FakeAiService extends AiService {
  AiTestResult nextResult = const AiTestResult(
    success: true,
    message: 'ok',
    latency: Duration(milliseconds: 50),
    latencyBucket: AiLatencyBucket.fast,
    modelResponseSnippet: 'pong',
  );

  List<String> streamTokens = const ['fastqc ', r'$INPUT_FILE', ' -o /outputs/'];
  AiServiceException? streamError;

  @override
  Future<AiTestResult> testConnection({
    required AiConnectivitySettings settings,
    String? apiKey,
  }) async =>
      nextResult;

  @override
  Stream<String> streamChat({
    required AiConnectivitySettings settings,
    String? apiKey,
    required List<Map<String, String>> messages,
    AiCancelToken? cancelToken,
  }) async* {
    if (streamError != null) throw streamError!;
    for (final token in streamTokens) {
      if (cancelToken?.isCancelled == true) return;
      yield token;
    }
  }

  @override
  void dispose() {}
}

class _FailWriteSecureStorage extends InMemoryAiSecureStorage {
  @override
  Future<void> writeApiKey(String value) async {
    throw Exception('keychain unavailable');
  }

  @override
  Future<void> deleteApiKey() async {
    throw Exception('keychain unavailable');
  }
}

void main() {
  late _FakeSettingsService settings;
  late InMemoryAiSecureStorage secure;
  late _FakeAiService aiService;
  late AiController controller;

  setUp(() {
    Get.testMode = true;
    settings = _FakeSettingsService();
    secure = InMemoryAiSecureStorage();
    aiService = _FakeAiService();
    controller = AiController(
      settingsService: settings,
      secureStorage: secure,
      aiService: aiService,
    );
  });

  tearDown(() => Get.deleteAll(force: true));

  test('pill hidden when AI disabled', () async {
    controller.onInit();
    await Future<void>.delayed(Duration.zero);
    expect(controller.pillState.value, AiPillState.hidden);
  });

  test('setEnabled(false) succeeds when api key storage fails', () async {
    final failSecure = _FailWriteSecureStorage();
    final ctrl = AiController(
      settingsService: settings,
      secureStorage: failSecure,
      aiService: aiService,
    );
    ctrl.onInit();
    await Future<void>.delayed(Duration.zero);
    await ctrl.setEnabled(true);
    expect(ctrl.connectivity.value.enabled, isTrue);

    await ctrl.setEnabled(false);

    expect(ctrl.connectivity.value.enabled, isFalse);
    expect(settings.stored.aiAssistant.enabled, isFalse);
    expect(ctrl.pillState.value, AiPillState.hidden);
  });

  test('preset apply fills URL and resets verification', () async {
    controller.onInit();
    await Future<void>.delayed(Duration.zero);
    await controller.setEnabled(true);
    await controller.applyPreset(AiProviderPreset.ollama);
    expect(controller.connectivity.value.baseUrl,
        'http://127.0.0.1:11434/v1');
    expect(controller.connectivity.value.connectionVerified, isFalse);
  });

  test('successful test marks connection verified', () async {
    controller.onInit();
    await Future<void>.delayed(Duration.zero);
    await controller.setEnabled(true);
    controller.connectivity.value = controller.connectivity.value.copyWith(
      baseUrl: 'http://127.0.0.1:11434/v1',
      model: 'llama3.2',
    );
    await controller.testConnection();
    expect(controller.connectivity.value.connectionVerified, isTrue);
    expect(controller.pillState.value, AiPillState.readyLocal);
    expect(settings.stored.aiAssistant.connectionVerified, isTrue);
  });

  test('onBaseUrlChanged reverts preset to custom when diverged', () {
    controller.connectivity.value = const AiConnectivitySettings(
      providerPreset: AiProviderPreset.ollama,
      baseUrl: 'http://127.0.0.1:11434/v1',
    );
    controller.onBaseUrlChanged('http://localhost:9999/v1');
    expect(controller.connectivity.value.providerPreset, AiProviderPreset.custom);
  });

  test('suggestCommand streams then proposes cleaned command', () async {
    controller.onInit();
    await Future<void>.delayed(Duration.zero);
    controller.connectivity.value = const AiConnectivitySettings(
      enabled: true,
      connectionVerified: true,
      baseUrl: 'http://127.0.0.1:11434/v1',
      model: 'llama3.2',
    );

    final node = _node('n1');
    await controller.suggestCommand(
      node: node,
      paramKey: 'command',
      partialCommand: '',
      allNodes: [node],
      connections: const [],
    );

    expect(controller.commandPhase.value, AiCommandSuggestPhase.proposed);
    expect(controller.commandProposed.value, 'fastqc \$INPUT_FILE -o /outputs/');
    expect(controller.commandNodeId.value, 'n1');
  });

  test('suggestCommand blocked when not verified', () async {
    controller.onInit();
    await Future<void>.delayed(Duration.zero);
    controller.connectivity.value = const AiConnectivitySettings(
      enabled: true,
      connectionVerified: false,
    );

    await controller.suggestCommand(
      node: _node('n1'),
      paramKey: 'command',
      partialCommand: '',
      allNodes: const [],
      connections: const [],
    );

    expect(controller.commandPhase.value, AiCommandSuggestPhase.error);
  });

  test('regenerateCommand increments alternative count', () async {
    controller.onInit();
    await Future<void>.delayed(Duration.zero);
    controller.connectivity.value = const AiConnectivitySettings(
      enabled: true,
      connectionVerified: true,
      baseUrl: 'http://127.0.0.1:11434/v1',
      model: 'llama3.2',
    );
    aiService.streamTokens = const ['echo alt'];

    final node = _node('n1');
    await controller.suggestCommand(
      node: node,
      paramKey: 'command',
      partialCommand: 'draft',
      allNodes: [node],
      connections: const [],
    );
    await controller.regenerateCommand(
      node: node,
      paramKey: 'command',
      partialCommand: 'draft',
      allNodes: [node],
      connections: const [],
    );

    expect(controller.commandRegenerateCount.value, 1);
    expect(controller.commandProposed.value, 'echo alt');
  });

  test('discardCommandSuggestion clears state', () async {
    controller.onInit();
    await Future<void>.delayed(Duration.zero);
    controller.connectivity.value = const AiConnectivitySettings(
      enabled: true,
      connectionVerified: true,
      baseUrl: 'http://127.0.0.1:11434/v1',
      model: 'llama3.2',
    );

    final node = _node('n1');
    await controller.suggestCommand(
      node: node,
      paramKey: 'command',
      partialCommand: '',
      allNodes: [node],
      connections: const [],
    );
    controller.discardCommandSuggestion();

    expect(controller.commandPhase.value, AiCommandSuggestPhase.idle);
    expect(controller.commandProposed.value, isEmpty);
    expect(controller.commandNodeId.value, isEmpty);
  });

  test('explainError streams explanation for failed node', () async {
    controller.onInit();
    await Future<void>.delayed(Duration.zero);
    controller.connectivity.value = const AiConnectivitySettings(
      enabled: true,
      connectionVerified: true,
      baseUrl: 'http://127.0.0.1:11434/v1',
      model: 'llama3.2',
    );
    aiService.streamTokens = const ['Missing ', 'input file'];

    final node = _node('n1');
    node.logs.add('[STDERR] file not found');
    node.status = BlockStatus.failed;

    await controller.explainError(node: node);

    expect(controller.explainPhase.value, AiExplainPhase.complete);
    expect(controller.explainResult.value, 'Missing input file');
  });

  test('assistDockerSearch returns cleaned query', () async {
    controller.onInit();
    await Future<void>.delayed(Duration.zero);
    controller.connectivity.value = const AiConnectivitySettings(
      enabled: true,
      connectionVerified: true,
      baseUrl: 'http://127.0.0.1:11434/v1',
      model: 'llama3.2',
    );
    aiService.streamTokens = const ['bwa mem'];

    final query = await controller.assistDockerSearch('align reads to reference');

    expect(query, 'bwa mem');
    expect(controller.searchAssistPhase.value, AiSearchAssistPhase.complete);
  });
}
