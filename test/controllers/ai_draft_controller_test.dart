import 'package:flutter_test/flutter_test.dart';
import 'package:get/get.dart';
import 'dart:async';

import 'package:Ricochet/controllers/ai_controller.dart';
import 'package:Ricochet/controllers/ai_draft_controller.dart';
import 'package:Ricochet/controllers/pipeline_controller.dart';
import 'package:Ricochet/models/ai_connectivity_settings.dart';
import 'package:Ricochet/models/ai_draft_session.dart';
import 'package:Ricochet/services/ai_service.dart';

class _FakeAiService extends AiService {
  String streamPayload = '''
{
  "nodes": [
    {"nodeType": "Input"},
    {"nodeType": "FastQC"},
    {"nodeType": "Output"}
  ],
  "connections": [
    {"from": 0, "to": 1},
    {"from": 1, "to": 2}
  ]
}
''';

  @override
  Stream<String> streamChat({
    required AiConnectivitySettings settings,
    String? apiKey,
    required List<Map<String, String>> messages,
    AiCancelToken? cancelToken,
  }) async* {
    yield streamPayload;
  }

  @override
  void dispose() {}
}

class _SlowFakeAiService extends AiService {
  _SlowFakeAiService(this._controller);

  final StreamController<String> _controller;

  @override
  Stream<String> streamChat({
    required AiConnectivitySettings settings,
    String? apiKey,
    required List<Map<String, String>> messages,
    AiCancelToken? cancelToken,
  }) async* {
    await for (final token in _controller.stream) {
      if (cancelToken?.isCancelled == true) return;
      yield token;
    }
  }

  @override
  void dispose() {}
}

void main() {
  late _FakeAiService aiService;
  late AiController aiController;
  late AiDraftController draftController;
  late PipelineController pipelineController;

  setUp(() {
    Get.testMode = true;
    aiService = _FakeAiService();
    aiController = AiController(aiService: aiService);
    Get.put(aiController);
    pipelineController = PipelineController();
    Get.put(pipelineController);
    draftController = AiDraftController(aiService: aiService);
    Get.put(draftController);

    aiController.connectivity.value = const AiConnectivitySettings(
      enabled: true,
      connectionVerified: true,
      baseUrl: 'http://127.0.0.1:11434/v1',
      model: 'llama3.2',
    );
  });

  tearDown(() => Get.deleteAll(force: true));

  test('startGenerate builds draft ghosts after stream completes', () async {
    await draftController.startGenerate(
      tabId: 'tab-1',
      userDescription: 'QC FASTQ reads',
    );

    expect(draftController.phase.value, AiDraftPhase.draftActive);
    expect(draftController.ghosts.length, 3);
    expect(draftController.showPanel.value, isTrue);
  });

  test('acceptAll materializes nodes on the canvas', () async {
    await draftController.startGenerate(
      tabId: 'tab-1',
      userDescription: 'QC FASTQ reads',
    );

    draftController.acceptAll();

    expect(pipelineController.nodes.length, 3);
    expect(draftController.showPanel.value, isFalse);
    expect(draftController.phase.value, AiDraftPhase.idle);
  });

  test('discardRemaining clears pending ghosts', () async {
    await draftController.startGenerate(
      tabId: 'tab-1',
      userDescription: 'QC FASTQ reads',
    );

    draftController.discardRemaining();
    draftController.closePanel(force: true);

    expect(draftController.ghosts, isEmpty);
    expect(pipelineController.nodes, isEmpty);
  });

  test('swapGhostNodeType replaces unknown draft node', () async {
    aiService.streamPayload = '''
{
  "nodes": [
    {"nodeType": "Input"},
    {"nodeType": "MysteryAligner"},
    {"nodeType": "Output"}
  ],
  "connections": [
    {"from": 0, "to": 1},
    {"from": 1, "to": 2}
  ]
}
''';

    await draftController.startGenerate(
      tabId: 'tab-1',
      userDescription: 'align reads',
    );

    expect(draftController.unknownNodeIndices, [1]);
    draftController.swapGhostNodeType(1, 'BWA');
    expect(draftController.unknownNodeIndices, isEmpty);
    expect(
      draftController.ghosts.any((g) => g.index == 1 && g.nodeType == 'BWA'),
      isTrue,
    );
  });

  test('cancelGenerate closes panel and resets in-flight count once', () async {
    final stream = StreamController<String>();
    addTearDown(stream.close);

    Get.delete<AiDraftController>(force: true);
    final slowService = _SlowFakeAiService(stream);
    draftController = AiDraftController(aiService: slowService);
    Get.put(draftController);

    final generateFuture = draftController.startGenerate(
      tabId: 'tab-1',
      userDescription: 'slow pipeline',
    );
    await Future<void>.delayed(Duration.zero);
    expect(draftController.showPanel.value, isTrue);
    expect(aiController.inFlightRequestCount.value, 1);

    draftController.cancelGenerate();
    stream.add('ignored');
    await stream.close();
    await generateFuture;

    expect(draftController.showPanel.value, isFalse);
    expect(draftController.phase.value, AiDraftPhase.idle);
    expect(aiController.inFlightRequestCount.value, 0);
  });

  test('removeGhostAt remaps accepted connection indices after partial accept', () async {
    await draftController.startGenerate(
      tabId: 'tab-1',
      userDescription: 'QC FASTQ reads',
    );

    draftController.startStepByStep();
    draftController.acceptFocusedOrNext();
    expect(pipelineController.nodes.length, 1);

    draftController.removeGhostAt(1);
    draftController.acceptFocusedOrNext();

    expect(pipelineController.nodes.length, 2);
    expect(pipelineController.connections.length, 1);
  });
}
