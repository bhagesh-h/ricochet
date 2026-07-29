import 'package:get/get.dart';

import '../controllers/pipeline_controller.dart';
import '../models/pipeline_node.dart';

/// Execution-scoped view of a pipeline graph.
///
/// Live contexts mirror [PipelineController] for single-node runs from the UI.
/// Isolated contexts hold a detached copy used by background tab runs so canvas
/// tab switches never corrupt in-flight execution.
class PipelineExecutionContext {
  final String tabId;
  final List<PipelineNode> nodes;
  final List<Connection> connections;
  final void Function(String nodeId)? onNodeChanged;
  final PipelineController? _controller;

  PipelineExecutionContext._({
    required this.tabId,
    required this.nodes,
    required this.connections,
    this.onNodeChanged,
    PipelineController? controller,
  }) : _controller = controller;

  factory PipelineExecutionContext.live(PipelineController controller) {
    return PipelineExecutionContext._(
      tabId: controller.currentTabId ?? 'live',
      nodes: controller.nodes,
      connections: controller.connections,
      controller: controller,
    );
  }

  factory PipelineExecutionContext.isolated({
    required String tabId,
    required List<PipelineNode> nodes,
    required List<Connection> connections,
    void Function(String nodeId)? onNodeChanged,
  }) {
    return PipelineExecutionContext._(
      tabId: tabId,
      nodes: nodes,
      connections: connections,
      onNodeChanged: onNodeChanged,
    );
  }

  PipelineNode? findNode(String nodeId) {
    return nodes.firstWhereOrNull((node) => node.id == nodeId);
  }

  void setNodeStatus(String nodeId, BlockStatus status) {
    final node = findNode(nodeId);
    if (node == null) return;
    node.status = status;
    refreshNode(nodeId);
  }

  void refreshNode(String nodeId) {
    if (_controller != null) {
      _controller!.nodes.refresh();
      _controller!.update([nodeId]);
    } else {
      onNodeChanged?.call(nodeId);
    }
  }

  List<Connection> upstreamConnections(String nodeId) {
    return connections.where((connection) => connection.toNodeId == nodeId).toList();
  }
}
