import 'dart:ui';

import 'package:get/get.dart';
import 'package:uuid/uuid.dart';
import '../models/pipeline_node.dart';

class Connection {
  final String fromNodeId;
  final String toNodeId;

  Connection({required this.fromNodeId, required this.toNodeId});
}

class PipelineController extends GetxController {
  var nodes = <PipelineNode>[].obs;
  var connections = <Connection>[].obs;

  void addNode(String title, Offset position) {
    final id = const Uuid().v4();
    nodes.add(PipelineNode(id: id, title: title, position: position));
  }

  void updateNodePosition(String id, Offset newPosition) {
    final index = nodes.indexWhere((node) => node.id == id);
    if (index != -1) {
      nodes[index].position = newPosition;
      nodes.refresh();
    }
  }

  void addConnection(String fromId, String toId) {
    if (fromId != toId &&
        !connections.any((c) => c.fromNodeId == fromId && c.toNodeId == toId)) {
      connections.add(Connection(fromNodeId: fromId, toNodeId: toId));
    }
  }

  void updateNodeConfig(String id, Map<String, dynamic> newConfig) {
  final index = nodes.indexWhere((node) => node.id == id);
  if (index != -1) {
    nodes[index].config = newConfig;
    nodes.refresh();
  }
}

void clearAll() {
  nodes.clear();
  connections.clear();
}

void deleteNode(String id) {
  nodes.removeWhere((n) => n.id == id);
  connections.removeWhere((c) => c.fromNodeId == id || c.toNodeId == id);
}





}
