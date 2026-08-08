import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:get/get.dart';

import 'package:Ricochet/controllers/ai_controller.dart';
import 'package:Ricochet/controllers/ai_review_controller.dart';
import 'package:Ricochet/controllers/execution_controller.dart';
import 'package:Ricochet/controllers/pipeline_controller.dart';
import 'package:Ricochet/models/ai_connectivity_settings.dart';
import 'package:Ricochet/models/pipeline_node.dart';
import 'package:Ricochet/services/ai_service.dart';
import 'package:Ricochet/services/ai_telemetry_service.dart';

class _FakeAiService extends AiService {
  List<String> streamTokens = const ['Pipeline looks ready with minor command gaps.'];
  int callCount = 0;

  @override
  Stream<String> streamChat({
    required AiConnectivitySettings settings,
    String? apiKey,
    required List<Map<String, String>> messages,
    AiCancelToken? cancelToken,
  }) async* {
    callCount++;
    for (final token in streamTokens) {
      yield token;
    }
  }

  @override
  void dispose() {}
}

void main() {
  late _FakeAiService aiService;
  late AiController aiController;
  late AiReviewController reviewController;
  final events = <String>[];

  setUp(() {
    Get.testMode = true;
    events.clear();
    aiService = _FakeAiService();
    aiController = AiController(
      aiService: aiService,
      telemetryService: AiTelemetryService(
        isOptedIn: () => true,
        sink: (event, _) => events.add(event),
      ),
    );
    Get.put(aiController);
    Get.put(PipelineController());
    Get.put(ExecutionController());
    reviewController = AiReviewController(
      aiService: aiService,
      telemetryService: AiTelemetryService(
        isOptedIn: () => true,
        sink: (event, _) => events.add(event),
      ),
    );
    Get.put(reviewController);

    aiController.connectivity.value = const AiConnectivitySettings(
      enabled: true,
      connectionVerified: true,
      baseUrl: 'http://127.0.0.1:11434/v1',
      model: 'llama3.2',
    );
  });

  tearDown(() => Get.deleteAll(force: true));

  test('openReview collects preflight issues and AI summary', () async {
    await reviewController.openReview();

    expect(reviewController.showSheet.value, isTrue);
    expect(reviewController.phase.value, AiReviewPhase.complete);
    expect(reviewController.summary.value, isNotEmpty);
    expect(events, contains('ai.review.clicked'));
    expect(events, contains('ai.review.completed'));
  });

  test('a second openReview call reuses the cached result instead of re-calling the AI', () async {
    await reviewController.openReview();
    expect(aiService.callCount, 1);
    final firstSummary = reviewController.summary.value;

    reviewController.closeReview();
    await reviewController.openReview();

    expect(aiService.callCount, 1, reason: 'should not re-call the AI when pipeline is unchanged');
    expect(reviewController.summary.value, firstSummary);
    expect(reviewController.isFromCache.value, isTrue);
    expect(events, contains('ai.review.cache_hit'));
  });

  test('refreshReview forces a new AI call even when nothing changed', () async {
    await reviewController.openReview();
    expect(aiService.callCount, 1);

    aiService.streamTokens = const ['Updated review after refresh.'];
    await reviewController.refreshReview();

    expect(aiService.callCount, 2);
    expect(reviewController.summary.value, 'Updated review after refresh.');
    expect(reviewController.isFromCache.value, isFalse);
    expect(events, contains('ai.review.refresh_clicked'));
  });

  test('editing the pipeline invalidates the cache automatically', () async {
    final pipelineCtrl = Get.find<PipelineController>();
    await reviewController.openReview();
    expect(aiService.callCount, 1);

    pipelineCtrl.nodes.add(PipelineNode(
      id: 'n1',
      title: 'Input Data',
      description: '',
      position: Offset.zero,
      category: BlockCategory.input,
      iconCodePoint: '0xe2c7',
      parameters: [
        BlockParameter(
          key: 'files',
          label: 'Input Files',
          type: ParameterType.multiFile,
          value: <String>['a.fastq'],
        ),
      ],
    ));

    await reviewController.openReview();
    expect(aiService.callCount, 2, reason: 'pipeline changed, cache should miss');
    expect(reviewController.isFromCache.value, isFalse);
  });
}
