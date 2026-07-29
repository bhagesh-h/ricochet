import '../models/pipeline_node.dart';

/// Pure DAG scheduling helpers shared by the canvas and execution engine.
class PipelineGraphScheduler {
  PipelineGraphScheduler._();

  /// Returns nodes in topological order. Throws if the graph contains a cycle.
  static List<PipelineNode> executionOrder(
    List<PipelineNode> nodes,
    List<Connection> connections,
  ) {
    return executionLevels(nodes, connections).expand((level) => level).toList();
  }

  /// Returns execution waves for parallel scheduling.
  static List<List<PipelineNode>> executionLevels(
    List<PipelineNode> nodes,
    List<Connection> connections,
  ) {
    final inDegree = <String, int>{};
    final adjacencyList = <String, List<String>>{};

    for (final node in nodes) {
      inDegree[node.id] = 0;
      adjacencyList[node.id] = [];
    }

    for (final connection in connections) {
      if (inDegree.containsKey(connection.toNodeId) &&
          inDegree.containsKey(connection.fromNodeId)) {
        adjacencyList[connection.fromNodeId]!.add(connection.toNodeId);
        inDegree[connection.toNodeId] = inDegree[connection.toNodeId]! + 1;
      }
    }

    var queue = <String>[];
    inDegree.forEach((nodeId, degree) {
      if (degree == 0) queue.add(nodeId);
    });
    queue.sort();

    final levels = <List<PipelineNode>>[];
    var processed = 0;

    while (queue.isNotEmpty) {
      final levelIds = List<String>.from(queue)..sort();
      queue = [];

      levels.add(
        levelIds.map((id) => nodes.firstWhere((n) => n.id == id)).toList(),
      );
      processed += levelIds.length;

      for (final u in levelIds) {
        for (final v in adjacencyList[u]!) {
          inDegree[v] = inDegree[v]! - 1;
          if (inDegree[v] == 0) {
            queue.add(v);
          }
        }
      }
    }

    if (processed != nodes.length) {
      throw Exception('Cycle detected in pipeline! Please remove loops.');
    }

    return levels;
  }
}
