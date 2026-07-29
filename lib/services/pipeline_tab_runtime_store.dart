import 'package:get/get.dart';

import '../controllers/pipeline_controller.dart';
import '../models/pipeline_execution_context.dart';
import '../models/pipeline_file.dart';
import '../models/pipeline_node.dart';

/// In-memory canvas state for one pipeline tab.
class TabCanvasState {
  List<PipelineNode> nodes;
  List<Connection> connections;

  TabCanvasState({
    required this.nodes,
    required this.connections,
  });

  factory TabCanvasState.fromFile(PipelineFile file) {
    return TabCanvasState(
      nodes: file.nodes
          .map((node) => PipelineNode.fromJson(node.toJson()))
          .toList(),
      connections: file.connections
          .map((connection) => Connection.fromJson(connection.toJson()))
          .toList(),
    );
  }

  void writeToFile(PipelineFile file) {
    file.nodes = nodes.map((n) => PipelineNode.fromJson(n.toJson())).toList();
    file.connections =
        connections.map((c) => Connection.fromJson(c.toJson())).toList();
  }

  TabCanvasState clone() {
    return TabCanvasState(
      nodes: nodes.map((n) => PipelineNode.fromJson(n.toJson())).toList(),
      connections:
          connections.map((c) => Connection.fromJson(c.toJson())).toList(),
    );
  }
}

/// Detached execution graph for a single tab run.
class PipelineRunSession {
  final String tabId;
  final int runToken;
  final String pipelineName;
  final List<PipelineNode> nodes;
  final List<Connection> connections;
  late final PipelineExecutionContext context;

  PipelineRunSession._({
    required this.tabId,
    required this.runToken,
    required this.pipelineName,
    required this.nodes,
    required this.connections,
  });

  factory PipelineRunSession.create({
    required String tabId,
    required int runToken,
    required String pipelineName,
    required List<PipelineNode> nodes,
    required List<Connection> connections,
    required void Function(String nodeId) onNodeChanged,
  }) {
    final session = PipelineRunSession._(
      tabId: tabId,
      runToken: runToken,
      pipelineName: pipelineName,
      nodes: nodes,
      connections: connections,
    );
    session.context = PipelineExecutionContext.isolated(
      tabId: tabId,
      nodes: session.nodes,
      connections: session.connections,
      onNodeChanged: onNodeChanged,
    );
    return session;
  }
}

/// Single source of truth for per-tab pipeline canvas state and active runs.
///
/// The visible [PipelineController] canvas always reflects the active tab.
/// Background tab executions mutate isolated [PipelineRunSession] copies and
/// merge results back into this store without touching the active canvas.
class PipelineTabRuntimeStore extends GetxService {
  final Map<String, TabCanvasState> _canvasByTab = {};
  final Map<String, PipelineRunSession> _sessionsByTab = {};

  TabCanvasState ensureTab(PipelineFile tab) {
    return _canvasByTab.putIfAbsent(
      tab.id,
      () => TabCanvasState.fromFile(tab),
    );
  }

  TabCanvasState? canvasFor(String tabId) => _canvasByTab[tabId];

  bool hasActiveSession(String tabId) => _sessionsByTab.containsKey(tabId);

  PipelineRunSession? sessionFor(String tabId) => _sessionsByTab[tabId];

  /// Persist the active UI canvas into the tab store.
  void captureActiveCanvas(String tabId, PipelineController controller) {
    final state = _canvasByTab[tabId];
    if (state == null) return;
    state.nodes = controller.nodes
        .map((node) => PipelineNode.fromJson(node.toJson()))
        .toList();
    state.connections = controller.connections
        .map((connection) => Connection.fromJson(connection.toJson()))
        .toList();
  }

  /// Load a tab's stored canvas into the UI controller.
  void applyToController(String tabId, PipelineController controller) {
    final state = _canvasByTab[tabId];
    if (state == null) return;
    controller.loadPipelineDataFromState(
      tabId,
      state.nodes,
      state.connections,
    );
  }

  /// Flush stored canvas into the tab's [PipelineFile] model.
  void syncToFile(String tabId, PipelineFile file) {
    _canvasByTab[tabId]?.writeToFile(file);
  }

  /// Snapshot the tab's latest canvas and begin an isolated run session.
  PipelineRunSession beginSession({
    required String tabId,
    required int runToken,
    required String pipelineName,
    required PipelineController controller,
    required String? activeTabId,
  }) {
    if (activeTabId == tabId) {
      captureActiveCanvas(tabId, controller);
    }

    final snapshot = (_canvasByTab[tabId] ?? TabCanvasState(nodes: [], connections: []))
        .clone();
    PipelineRunSession? session;
    session = PipelineRunSession.create(
      tabId: tabId,
      runToken: runToken,
      pipelineName: pipelineName,
      nodes: snapshot.nodes,
      connections: snapshot.connections,
      onNodeChanged: (nodeId) {
        _mergeSessionNode(tabId, nodeId, session!);
        if (activeTabId == tabId) {
          _syncNodeToController(tabId, nodeId, controller);
        }
      },
    );
    _sessionsByTab[tabId] = session!;
    return session!;
  }

  void _mergeSessionNode(
    String tabId,
    String nodeId,
    PipelineRunSession session,
  ) {
    final state = _canvasByTab[tabId];
    if (state == null) return;

    final source = session.nodes.firstWhereOrNull((node) => node.id == nodeId);
    if (source == null) return;

    final index = state.nodes.indexWhere((node) => node.id == nodeId);
    if (index < 0) return;

    state.nodes[index] = PipelineNode.fromJson(source.toJson());
  }

  void _syncNodeToController(
    String tabId,
    String nodeId,
    PipelineController controller,
  ) {
    if (controller.currentTabId != tabId) return;
    final state = _canvasByTab[tabId];
    if (state == null) return;

    final source = state.nodes.firstWhereOrNull((node) => node.id == nodeId);
    final index = controller.nodes.indexWhere((node) => node.id == nodeId);
    if (source == null || index < 0) return;

    controller.nodes[index] = PipelineNode.fromJson(source.toJson());
    controller.nodes.refresh();
    controller.update([nodeId]);
  }

  /// Merge all session node states back into the tab store and optional UI.
  void finalizeSession({
    required String tabId,
    required PipelineRunSession session,
    required PipelineController controller,
    required String? activeTabId,
    required PipelineFile file,
  }) {
    for (final node in session.nodes) {
      _mergeSessionNode(tabId, node.id, session);
      if (activeTabId == tabId) {
        _syncNodeToController(tabId, node.id, controller);
      }
    }
    syncToFile(tabId, file);
    _sessionsByTab.remove(tabId);
  }

  void cancelSession(String tabId) {
    _sessionsByTab.remove(tabId);
  }

  /// Reload canvas from disk unless a background run owns this tab.
  void hydrateFromFile(PipelineFile tab) {
    if (_sessionsByTab.containsKey(tab.id)) return;
    _canvasByTab[tab.id] = TabCanvasState.fromFile(tab);
  }
}
