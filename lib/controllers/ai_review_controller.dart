import 'dart:async';

import 'package:get/get.dart';

import '../models/ai_connectivity_settings.dart';
import '../models/pipeline_preflight_issue.dart';
import '../services/ai_pipeline_preflight_service.dart';
import '../services/ai_prompt_builder.dart';
import '../services/ai_service.dart';
import '../services/ai_telemetry_service.dart';
import '../theme/ai_motion_tokens.dart';
import 'ai_controller.dart';
import 'pipeline_controller.dart';

enum AiReviewPhase {
  idle,
  streaming,
  complete,
  error,
}

/// A cached AI review result for one pipeline tab. Kept valid only while the
/// pipeline's structural signature and the active AI model/endpoint are
/// unchanged from when it was generated.
class _CachedReview {
  _CachedReview({
    required this.pipelineSignature,
    required this.settingsSignature,
    required this.issues,
    required this.summary,
    required this.generatedAt,
  });

  final String pipelineSignature;
  final String settingsSignature;
  final List<PipelinePreflightIssue> issues;
  final String summary;
  final DateTime generatedAt;
}

class AiReviewController extends GetxController {
  AiReviewController({
    AiService? aiService,
    AiTelemetryService? telemetryService,
    AiPipelinePreflightService? preflightService,
  })  : _aiService = aiService ?? AiService(),
        _ownsAiService = aiService == null,
        _telemetry = telemetryService ?? AiTelemetryService(),
        _preflight = preflightService ?? AiPipelinePreflightService();

  final AiService _aiService;
  final bool _ownsAiService;
  final AiTelemetryService _telemetry;
  final AiPipelinePreflightService _preflight;

  final phase = AiReviewPhase.idle.obs;
  final issues = <PipelinePreflightIssue>[].obs;
  final streamText = ''.obs;
  final summary = ''.obs;
  final errorMessage = ''.obs;
  final elapsedSec = 0.obs;
  final showSheet = false.obs;

  /// True when [summary] came from cache rather than a fresh AI call.
  final isFromCache = false.obs;

  /// When the currently-shown summary was generated (fresh or cached).
  final Rxn<DateTime> reviewedAt = Rxn<DateTime>();

  /// Cached reviews keyed by pipeline tab id, so switching tabs doesn't lose
  /// a prior review, but editing the pipeline invalidates it automatically.
  final Map<String, _CachedReview> _cache = {};

  AiCancelToken? _cancel;
  Timer? _elapsedTimer;
  DateTime? _started;

  int get blockerCount =>
      issues.where((i) => i.severity == PreflightSeverity.blocker).length;

  int get warningCount =>
      issues.where((i) => i.severity == PreflightSeverity.warning).length;

  String get waitingLabel {
    final sec = elapsedSec.value;
    if (sec < AiMotionTokens.latencyThresholdSlow.inSeconds) {
      return 'Reviewing pipeline…';
    }
    if (sec < AiMotionTokens.latencyThresholdVerySlow.inSeconds) {
      return 'Thinking… ${sec}s';
    }
    return 'Still working… ${sec}s';
  }

  String get reviewedAgoLabel {
    final at = reviewedAt.value;
    if (at == null) return '';
    final diff = DateTime.now().difference(at);
    if (diff.inSeconds < 5) return 'Reviewed just now';
    if (diff.inMinutes < 1) return 'Reviewed ${diff.inSeconds}s ago';
    if (diff.inHours < 1) return 'Reviewed ${diff.inMinutes}m ago';
    return 'Reviewed ${diff.inHours}h ago';
  }

  String get _tabKey {
    if (!Get.isRegistered<PipelineController>()) return '__default__';
    return Get.find<PipelineController>().currentTabId ?? '__default__';
  }

  String _settingsSignature(AiController ai) =>
      '${ai.connectivity.value.baseUrl}|${ai.connectivity.value.model}';

  /// Opens the review sheet. Reuses a cached result for the current tab
  /// when the pipeline hasn't changed since the last review, unless
  /// [forceRefresh] is set (e.g. user tapped the refresh button).
  Future<void> openReview({bool forceRefresh = false}) async {
    if (phase.value == AiReviewPhase.streaming) return;

    final freshIssues = _preflight.collectIssues();
    issues.value = freshIssues;
    errorMessage.value = '';
    showSheet.value = true;
    _telemetry.track('ai.review.clicked');

    if (!Get.isRegistered<AiController>()) {
      summary.value = '';
      isFromCache.value = false;
      phase.value = AiReviewPhase.complete;
      return;
    }

    final ai = Get.find<AiController>();
    if (!ai.canSuggestCommand) {
      summary.value = '';
      isFromCache.value = false;
      phase.value = AiReviewPhase.complete;
      return;
    }

    final tabKey = _tabKey;
    final pipelineSignature = _preflight.pipelineSignature();
    final settingsSignature = _settingsSignature(ai);

    if (!forceRefresh) {
      final cached = _cache[tabKey];
      if (cached != null &&
          cached.pipelineSignature == pipelineSignature &&
          cached.settingsSignature == settingsSignature) {
        issues.value = cached.issues;
        summary.value = cached.summary;
        streamText.value = '';
        isFromCache.value = true;
        reviewedAt.value = cached.generatedAt;
        phase.value = AiReviewPhase.complete;
        _telemetry.track('ai.review.cache_hit');
        return;
      }
    }

    summary.value = '';
    streamText.value = '';
    isFromCache.value = false;
    phase.value = AiReviewPhase.streaming;
    final messages = AiPromptBuilder.forPipelineReview(
      preflightIssues: freshIssues,
      pipelineSummary: _preflight.summaryContext(),
    );

    _cancel?.cancel();
    _cancel = AiCancelToken();
    ai.trackInflightRequestStart();
    _startElapsedTimer();

    final buffer = StringBuffer();
    try {
      await for (final token in _aiService.streamChat(
        settings: ai.connectivity.value,
        apiKey: ai.apiKey.value.isEmpty ? null : ai.apiKey.value,
        messages: messages,
        cancelToken: _cancel,
      )) {
        buffer.write(token);
        streamText.value = buffer.toString();
      }

      if (_cancel?.isCancelled == true) {
        phase.value = AiReviewPhase.idle;
        return;
      }

      final cleaned = buffer.toString().trim();
      if (cleaned.isEmpty) {
        throw const AiServiceException('Model returned an empty review.');
      }

      summary.value = cleaned;
      phase.value = AiReviewPhase.complete;
      reviewedAt.value = DateTime.now();
      _cache[tabKey] = _CachedReview(
        pipelineSignature: pipelineSignature,
        settingsSignature: settingsSignature,
        issues: freshIssues,
        summary: cleaned,
        generatedAt: reviewedAt.value!,
      );
      _telemetry.track(
        'ai.review.completed',
        properties: {
          'success': true,
          'issue_count': issues.length,
          'blocker_count': blockerCount,
          'warning_count': warningCount,
          'latency_bucket': AiLatencyBucket.fromDuration(
            DateTime.now().difference(_started ?? DateTime.now()),
            timedOut: false,
          ).name,
        },
      );
    } on AiServiceException catch (e) {
      phase.value = AiReviewPhase.error;
      errorMessage.value = e.message;
      _telemetry.track(
        'ai.review.completed',
        properties: {'success': false, 'issue_count': issues.length},
      );
    } catch (_) {
      phase.value = AiReviewPhase.error;
      errorMessage.value = 'Could not complete pipeline review.';
      _telemetry.track(
        'ai.review.completed',
        properties: {'success': false, 'issue_count': issues.length},
      );
    } finally {
      _stopElapsedTimer();
      ai.trackInflightRequestEnd();
    }
  }

  /// Forces a brand-new AI review, ignoring any cached result for this tab.
  Future<void> refreshReview() {
    _telemetry.track('ai.review.refresh_clicked');
    return openReview(forceRefresh: true);
  }

  void closeReview() {
    _cancel?.cancel();
    _stopElapsedTimer();
    showSheet.value = false;
    phase.value = AiReviewPhase.idle;
    streamText.value = '';
    errorMessage.value = '';
    // Keep summary/issues/isFromCache/reviewedAt so re-opening without
    // pipeline changes shows the cached result instantly instead of a blank
    // sheet flash.
  }

  void _startElapsedTimer() {
    _started = DateTime.now();
    elapsedSec.value = 0;
    _elapsedTimer?.cancel();
    _elapsedTimer = Timer.periodic(const Duration(seconds: 1), (_) {
      if (_started == null) return;
      elapsedSec.value = DateTime.now().difference(_started!).inSeconds;
    });
  }

  void _stopElapsedTimer() {
    _elapsedTimer?.cancel();
    _elapsedTimer = null;
    _started = null;
  }

  @override
  void onClose() {
    _cancel?.cancel();
    _stopElapsedTimer();
    if (_ownsAiService) {
      _aiService.dispose();
    }
    super.onClose();
  }
}
