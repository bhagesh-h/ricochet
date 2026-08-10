import 'dart:async';

import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:uuid/uuid.dart';

import '../models/ai_connectivity_settings.dart';
import '../models/ai_draft_session.dart';
import '../models/ai_pipeline_draft.dart';
import '../services/ai_pipeline_layout.dart';
import '../services/ai_pipeline_parser.dart';
import '../services/ai_pipeline_validator.dart';
import '../services/ai_prompt_builder.dart';
import '../services/ai_service.dart';
import '../services/ai_telemetry_service.dart';
import '../services/ai_unknown_node_suggestions.dart';
import '../theme/ai_motion_tokens.dart';
import 'ai_controller.dart';
import 'docker_search_controller.dart';
import 'home_controller.dart';
import 'pipeline_controller.dart';
import 'pipeline_tabs_controller.dart';

class AiDraftController extends GetxController {
  AiDraftController({
    AiService? aiService,
    AiTelemetryService? telemetryService,
    AiPipelineParser? parser,
    AiPipelineValidator? validator,
    AiPipelineLayout? layout,
  })  : _aiService = aiService ?? AiService(),
        _ownsAiService = aiService == null,
        _telemetry = telemetryService ?? AiTelemetryService(),
        _parser = parser ?? AiPipelineParser(),
        _validator = validator ?? AiPipelineValidator(),
        _layout = layout ?? AiPipelineLayout();

  final AiService _aiService;
  final bool _ownsAiService;
  final AiTelemetryService _telemetry;
  final AiPipelineParser _parser;
  final AiPipelineValidator _validator;
  final AiPipelineLayout _layout;

  final phase = AiDraftPhase.idle.obs;
  final tabId = ''.obs;
  final description = ''.obs;
  final streamText = ''.obs;
  final progressStep = AiGenerateProgressStep.reading.obs;
  final elapsedSec = 0.obs;
  final ghosts = <AiGhostNode>[].obs;
  final ghostConnections = <AiDraftConnectionDef>[].obs;
  final focusedGhostIndex = (-1).obs;
  final stepByStepActive = false.obs;
  final acceptedCount = 0.obs;
  final errorMessage = ''.obs;
  final showPanel = false.obs;
  final unknownNodeIndices = <int>[].obs;

  AiPipelineDraft? _draft;
  final _acceptedNodeIds = <int, String>{};
  AiCancelToken? _activeCancel;
  Timer? _elapsedTimer;
  Timer? _progressTimer;
  DateTime? _requestStarted;
  int _progressStepIndex = 0;

  bool get isDraftActive => phase.value == AiDraftPhase.draftActive;

  int get pendingGhostCount =>
      ghosts.where((g) => g.status == AiGhostStatus.pending).length;

  bool get canRegenerate =>
      isDraftActive && acceptedCount.value == 0 && pendingGhostCount > 0;

  bool get hasPendingGhosts => pendingGhostCount > 0;

  String get waitingLabel {
    final sec = elapsedSec.value;
    if (sec < AiMotionTokens.latencyThresholdSlow.inSeconds) {
      return progressStep.value.label;
    }
    if (sec < AiMotionTokens.latencyThresholdVerySlow.inSeconds) {
      return 'Thinking… ${sec}s';
    }
    return 'Still working… ${sec}s';
  }

  bool canGenerate(AiController ai) =>
      ai.connectivity.value.enabled && ai.connectivity.value.connectionVerified;

  Future<void> openGenerateFromHome(String userDescription) async {
    final tabsCtrl = Get.find<PipelineTabsController>();
    final home = Get.find<HomeController>();
    final id = await tabsCtrl.createNewTabForGenerate();
    home.openEditor();
    await startGenerate(tabId: id, userDescription: userDescription);
  }

  Future<void> startGenerate({
    required String tabId,
    required String userDescription,
    bool regenerate = false,
  }) async {
    final ai = Get.find<AiController>();
    if (!canGenerate(ai)) {
      phase.value = AiDraftPhase.error;
      errorMessage.value =
          'Enable AI Assistant and run Test Connection in Settings first.';
      return;
    }

    if (regenerate) {
      _telemetry.track('ai.generate.regenerate_clicked');
    } else {
      _telemetry.track('ai.generate.clicked');
      acceptedCount.value = 0;
      stepByStepActive.value = false;
      _acceptedNodeIds.clear();
    }

    this.tabId.value = tabId;
    description.value = userDescription;
    streamText.value = '';
    errorMessage.value = '';
    ghosts.clear();
    ghostConnections.clear();
    unknownNodeIndices.clear();
    focusedGhostIndex.value = -1;
    phase.value = AiDraftPhase.streaming;
    showPanel.value = true;
    _progressStepIndex = 0;
    progressStep.value = AiGenerateProgressStep.reading;

    _activeCancel?.cancel();
    _activeCancel = AiCancelToken();
    _beginRequest(ai);
    _startTimers();

    final started = DateTime.now();
    final buffer = StringBuffer();
    final messages = AiPromptBuilder.forPipelineGenerate(
      description: userDescription,
      regenerate: regenerate,
    );

    try {
      await for (final token in _aiService.streamChat(
        settings: ai.connectivity.value,
        apiKey: ai.apiKey.value.isEmpty ? null : ai.apiKey.value,
        messages: messages,
        cancelToken: _activeCancel,
      )) {
        buffer.write(token);
        streamText.value = buffer.toString();
        if (_progressStepIndex < 3) {
          _progressStepIndex = (elapsedSec.value ~/ 2).clamp(0, 3);
          progressStep.value = AiGenerateProgressStep.values[_progressStepIndex];
        }
      }

      if (_activeCancel?.isCancelled == true) {
        phase.value = AiDraftPhase.idle;
        showPanel.value = false;
        return;
      }

      phase.value = AiDraftPhase.validating;
      progressStep.value = AiGenerateProgressStep.building;

      _draft = _parser.parse(buffer.toString());
      final validation = _validator.validate(_draft!);
      if (!validation.isValid) {
        throw AiServiceException(validation.errorMessage!);
      }

      unknownNodeIndices.value = validation.unknownNodeIndices;
      ghostConnections.value = List<AiDraftConnectionDef>.from(_draft!.connections);
      _buildGhosts(_draft!);

      phase.value = AiDraftPhase.draftActive;
      Get.find<PipelineController>().fitViewRequest.value++;

      final elapsed = DateTime.now().difference(started);
      _telemetry.track(
        'ai.generate.completed',
        properties: {
          'success': true,
          'node_count': _draft!.nodeCount,
          'latency_bucket': AiLatencyBucket.fromDuration(elapsed, timedOut: false)
              .name,
          'is_regenerate': regenerate,
        },
      );
    } on AiServiceException catch (e) {
      _failGenerate(e.message, regenerate: regenerate);
    } on AiPipelineParseException catch (e) {
      _failGenerate(e.message, regenerate: regenerate);
    } catch (_) {
      _failGenerate('Could not generate pipeline. Try again.', regenerate: regenerate);
    } finally {
      _stopTimers();
      _endRequest(ai);
    }
  }

  void _buildGhosts(AiPipelineDraft draft) {
    final layoutResult = _layout.layout(draft);
    final unknown = unknownNodeIndices.toSet();
    final built = <AiGhostNode>[];

    layoutResult.positionsByIndex.forEach((index, position) {
      final def = draft.nodes[index];
      built.add(
        AiGhostNode(
          id: const Uuid().v4(),
          index: index,
          nodeType: def.nodeType,
          position: position,
          parameterOverrides: def.parameterOverrides,
          isUnknownImage: unknown.contains(index),
          status: _acceptedNodeIds.containsKey(index)
              ? AiGhostStatus.accepted
              : AiGhostStatus.pending,
        ),
      );
    });

    if (layoutResult.hasSummaryGhost && layoutResult.summaryGhostPosition != null) {
      built.add(
        AiGhostNode(
          id: const Uuid().v4(),
          index: -1,
          nodeType: '__summary__',
          position: layoutResult.summaryGhostPosition!,
          status: AiGhostStatus.summary,
          summaryHiddenCount: layoutResult.overflowCount,
          summaryScrollToIndex: layoutResult.overflowScrollToIndex,
        ),
      );
    }

    ghosts.value = built;
  }

  void _failGenerate(String message, {required bool regenerate}) {
    phase.value = AiDraftPhase.error;
    errorMessage.value = message;
    _telemetry.track(
      'ai.generate.completed',
      properties: {
        'success': false,
        'node_count': 0,
        'latency_bucket': AiLatencyBucket.slow.name,
        'is_regenerate': regenerate,
      },
    );
  }

  Future<void> regenerate() async {
    if (!canRegenerate) return;
    await startGenerate(
      tabId: tabId.value,
      userDescription: description.value,
      regenerate: true,
    );
  }

  void cancelGenerate() {
    final wasActive = phase.value == AiDraftPhase.streaming ||
        phase.value == AiDraftPhase.validating;
    _activeCancel?.cancel();
    _stopTimers();
    streamText.value = '';
    if (wasActive) {
      phase.value = AiDraftPhase.idle;
      showPanel.value = false;
    }
  }

  void acceptAll() {
    if (!isDraftActive || _draft == null) return;
    final pipeline = Get.find<PipelineController>();
    final pending = ghosts
        .where((g) => g.status == AiGhostStatus.pending)
        .toList()
      ..sort((a, b) => a.index.compareTo(b.index));

    for (final ghost in pending) {
      _acceptGhostNode(ghost, pipeline);
    }
    _wireAllAcceptedConnections(pipeline);
    _telemetry.track('ai.generate.accepted', properties: {'mode': 'all'});
    _endSession();
  }

  void startStepByStep() {
    if (!isDraftActive) return;
    stepByStepActive.value = true;
    _focusNextPending();
  }

  void acceptFocusedOrNext() {
    if (!isDraftActive || _draft == null) return;
    final pipeline = Get.find<PipelineController>();
    final target = focusedGhostIndex.value >= 0
        ? ghosts.firstWhereOrNull((g) => g.index == focusedGhostIndex.value)
        : ghosts.firstWhereOrNull((g) => g.status == AiGhostStatus.pending);

    if (target == null || target.isSummary) return;
    _acceptGhostNode(target, pipeline);
    _wireAllAcceptedConnections(pipeline);

    if (pendingGhostCount == 0) {
      _telemetry.track('ai.generate.accepted', properties: {'mode': 'step'});
      _endSession();
    } else {
      _focusNextPending();
    }
  }

  void discardRemaining({bool hadPartialAccept = false}) {
    ghosts.removeWhere((g) => g.status == AiGhostStatus.pending);
    ghosts.removeWhere((g) => g.isSummary);
    _telemetry.track(
      'ai.generate.discarded',
      properties: {'had_partial_accept': hadPartialAccept},
    );
    if (pendingGhostCount == 0) {
      _endSession();
    }
  }

  bool needsExitConfirm() => isDraftActive && hasPendingGhosts;

  /// Returns true if navigation may proceed. When a draft still has pending
  /// ghosts, shows the same leave-confirm dialog used by the preview panel
  /// close button so Home / tab-close cannot silently discard them.
  Future<bool> confirmLeaveIfNeeded() async {
    if (!needsExitConfirm()) {
      if (showPanel.value) closePanel(force: true);
      return true;
    }

    final ok = await Get.dialog<bool>(
      AlertDialog(
        title: const Text('Leave review?'),
        content: const Text(
          'Accepted nodes stay; remaining suggestions will be removed.',
        ),
        actions: [
          TextButton(
            onPressed: () => Get.back(result: false),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () => Get.back(result: true),
            child: const Text('Leave'),
          ),
        ],
      ),
      barrierDismissible: false,
    );

    if (ok == true) {
      discardRemaining(hadPartialAccept: acceptedCount.value > 0);
      closePanel(force: true);
      return true;
    }
    return false;
  }

  void closePanel({bool force = false}) {
    if (!force && needsExitConfirm()) return;
    cancelGenerate();
    showPanel.value = false;
    ghosts.clear();
    ghostConnections.clear();
    _draft = null;
    _acceptedNodeIds.clear();
    acceptedCount.value = 0;
    stepByStepActive.value = false;
    focusedGhostIndex.value = -1;
    phase.value = AiDraftPhase.idle;
  }

  void focusGhost(int index) {
    if (index < 0) return;
    focusedGhostIndex.value = index;
    ghosts.refresh();
  }

  void swapGhostNodeType(int index, String newNodeType) {
    if (_draft == null || index < 0 || index >= _draft!.nodes.length) return;
    final nodes = List<AiDraftNodeDef>.from(_draft!.nodes);
    final previous = nodes[index];
    nodes[index] = AiDraftNodeDef(
      nodeType: newNodeType,
      parameterOverrides: previous.parameterOverrides,
    );
    _applyDraftMutation(nodes);
    focusGhost(index);
  }

  void removeGhostAt(int index) {
    if (_draft == null || index < 0 || index >= _draft!.nodes.length) return;

    final nodes = List<AiDraftNodeDef>.from(_draft!.nodes)..removeAt(index);
    final connections = <AiDraftConnectionDef>[];
    final incoming = <int>[];
    final outgoing = <int>[];

    for (final conn in _draft!.connections) {
      if (conn.toIndex == index) {
        incoming.add(conn.fromIndex);
        continue;
      }
      if (conn.fromIndex == index) {
        outgoing.add(conn.toIndex);
        continue;
      }
      connections.add(
        AiDraftConnectionDef(
          fromIndex: conn.fromIndex > index ? conn.fromIndex - 1 : conn.fromIndex,
          toIndex: conn.toIndex > index ? conn.toIndex - 1 : conn.toIndex,
        ),
      );
    }

    for (final from in incoming) {
      for (final to in outgoing) {
        final bridgedFrom = from > index ? from - 1 : from;
        final bridgedTo = to > index ? to - 1 : to;
        if (bridgedFrom == bridgedTo) continue;
        final duplicate = connections.any(
          (c) => c.fromIndex == bridgedFrom && c.toIndex == bridgedTo,
        );
        if (!duplicate) {
          connections.add(
            AiDraftConnectionDef(fromIndex: bridgedFrom, toIndex: bridgedTo),
          );
        }
      }
    }

    _remapAcceptedIdsAfterRemoval(index);
    if (focusedGhostIndex.value == index) {
      focusedGhostIndex.value = -1;
    } else if (focusedGhostIndex.value > index) {
      focusedGhostIndex.value--;
    }
    _applyDraftMutation(nodes, connections: connections);
  }

  void _remapAcceptedIdsAfterRemoval(int removedIndex) {
    final remapped = <int, String>{};
    for (final entry in _acceptedNodeIds.entries) {
      if (entry.key == removedIndex) continue;
      final nextIndex = entry.key > removedIndex ? entry.key - 1 : entry.key;
      remapped[nextIndex] = entry.value;
    }
    _acceptedNodeIds
      ..clear()
      ..addAll(remapped);
  }

  Future<void> searchHubForGhost(int index) async {
    if (_draft == null || index < 0 || index >= _draft!.nodes.length) return;
    if (!Get.isRegistered<DockerSearchController>()) return;

    final nodeType = _draft!.nodes[index].nodeType;
    final query = AiUnknownNodeSuggestions.hubSearchQuery(nodeType);
    focusGhost(index);
    await Get.find<DockerSearchController>().searchDockerImages(query);
  }

  void _applyDraftMutation(
    List<AiDraftNodeDef> nodes, {
    List<AiDraftConnectionDef>? connections,
  }) {
    _draft = AiPipelineDraft(
      nodes: nodes,
      connections: connections ?? _draft!.connections,
    );
    final validation = _validator.validate(_draft!);
    unknownNodeIndices.value = validation.unknownNodeIndices;
    ghostConnections.value = List<AiDraftConnectionDef>.from(_draft!.connections);
    _buildGhosts(_draft!);
    Get.find<PipelineController>().fitViewRequest.value++;
  }

  void focusSummaryGhost(AiGhostNode summary) {
    final scrollTo = summary.summaryScrollToIndex ?? 0;
    focusGhost(scrollTo);
  }

  List<AiGhostNode> ghostsForTab(String activeTabId) {
    if (tabId.value != activeTabId || !showPanel.value) return const [];
    if (phase.value != AiDraftPhase.draftActive) return const [];
    return ghosts;
  }

  void _acceptGhostNode(AiGhostNode ghost, PipelineController pipeline) {
    if (ghost.status != AiGhostStatus.pending || _draft == null) return;
    final def = _draft!.nodes[ghost.index].toTemplateDef(ghost.position);
    final node = pipeline.addNodeFromTemplateDef(def);
    _acceptedNodeIds[ghost.index] = node.id;
    final idx = ghosts.indexWhere((g) => g.id == ghost.id);
    if (idx >= 0) {
      ghosts[idx] = ghost.copyWith(status: AiGhostStatus.accepted);
    }
    acceptedCount.value++;
    if (Get.isRegistered<PipelineTabsController>()) {
      Get.find<PipelineTabsController>().markActiveTabDirty();
    }
  }

  void _wireAllAcceptedConnections(PipelineController pipeline) {
    for (final conn in ghostConnections) {
      final fromId = _acceptedNodeIds[conn.fromIndex];
      final toId = _acceptedNodeIds[conn.toIndex];
      if (fromId == null || toId == null) continue;
      pipeline.addConnection(fromId, toId);
    }
  }

  void _focusNextPending() {
    final next = ghosts.firstWhereOrNull((g) => g.status == AiGhostStatus.pending);
    focusedGhostIndex.value = next?.index ?? -1;
    ghosts.refresh();
  }

  void _endSession() {
    showPanel.value = false;
    ghosts.clear();
    ghostConnections.clear();
    _draft = null;
    stepByStepActive.value = false;
    focusedGhostIndex.value = -1;
    phase.value = AiDraftPhase.idle;
  }

  void _beginRequest(AiController ai) {
    ai.trackInflightRequestStart();
  }

  void _endRequest(AiController ai) {
    ai.trackInflightRequestEnd();
  }

  void _startTimers() {
    _requestStarted = DateTime.now();
    elapsedSec.value = 0;
    _elapsedTimer?.cancel();
    _elapsedTimer = Timer.periodic(const Duration(seconds: 1), (_) {
      if (_requestStarted == null) return;
      elapsedSec.value =
          DateTime.now().difference(_requestStarted!).inSeconds;
    });
    _progressTimer?.cancel();
    _progressTimer = Timer.periodic(AiMotionTokens.progressStepMin, (_) {
      if (_progressStepIndex < AiGenerateProgressStep.values.length - 1) {
        _progressStepIndex++;
        progressStep.value = AiGenerateProgressStep.values[_progressStepIndex];
      }
    });
  }

  void _stopTimers() {
    _elapsedTimer?.cancel();
    _elapsedTimer = null;
    _progressTimer?.cancel();
    _progressTimer = null;
    _requestStarted = null;
  }

  @override
  void onClose() {
    _activeCancel?.cancel();
    _stopTimers();
    if (_ownsAiService) {
      _aiService.dispose();
    }
    super.onClose();
  }
}
