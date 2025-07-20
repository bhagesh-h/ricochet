import 'package:flutter/material.dart';
import 'package:get/get.dart';
import '../controllers/pipeline_controller.dart';
import '../models/pipeline_node.dart';

class CanvasArea extends StatelessWidget {
  const CanvasArea({super.key});

  @override
  Widget build(BuildContext context) {
    final PipelineController controller = Get.put(PipelineController());

    return DragTarget<String>(
      onAcceptWithDetails: (details) {
        final localOffset =
            (context.findRenderObject() as RenderBox).globalToLocal(details.offset);
        controller.addNode(details.data, localOffset);
      },
      builder: (context, candidateData, rejectedData) {
        return Obx(() {
          return Stack(
            children: [
              // 🔷 Draw connection lines behind widgets
              CustomPaint(
                size: Size.infinite,
                painter: ConnectionPainter(
                  nodes: controller.nodes,
                  connections: controller.connections,
                ),
              ),
              ...controller.nodes.map((node) {
                return Positioned(
                  left: node.position.dx,
                  top: node.position.dy,
                  child: Draggable<PipelineNode>(
                    data: node,
                    feedback: Material(child: Chip(label: Text(node.title))),
                    childWhenDragging: Container(),
                    onDragEnd: (details) {
                      final newOffset = (context.findRenderObject() as RenderBox)
                          .globalToLocal(details.offset);
                      controller.updateNodePosition(node.id, newOffset);
                    },
                    child: PipelineNodeWidget(node: node),
                  ),
                );
              }),
            ],
          );
        });
      },
    );
  }
}


class PipelineNodeWidget extends StatelessWidget {
  final PipelineNode node;
  const PipelineNodeWidget({required this.node, super.key});

  @override
  Widget build(BuildContext context) {
    final PipelineController controller = Get.find();

    return GestureDetector(
      onTap: () => _openConfigDialog(context, node),
      child: Container(
        width: 150,
        padding: const EdgeInsets.all(8),
        decoration: BoxDecoration(
          color: Colors.lightBlue[100],
          border: Border.all(color: Colors.blue),
          borderRadius: BorderRadius.circular(6),
        ),
        child: Column(
          children: [
            Text(node.title),
            const SizedBox(height: 8),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                IconButton(
                  tooltip: 'Set as source',
                  icon: const Icon(Icons.arrow_circle_right_outlined),
                  onPressed: () {
                    Get.find<TempConnection>().setSource(node.id);
                  },
                ),
                IconButton(
                  tooltip: 'Set as target',
                  icon: const Icon(Icons.arrow_circle_left_outlined),
                  onPressed: () {
                    final source = Get.find<TempConnection>().sourceId;
                    if (source != null) {
                      controller.addConnection(source, node.id);
                      Get.find<TempConnection>().clear();
                    }
                  },
                ),
              ],
            ),
            Row(
  mainAxisAlignment: MainAxisAlignment.end,
  children: [
    IconButton(
      tooltip: 'Delete Node',
      icon: const Icon(Icons.close, color: Colors.red),
      onPressed: () {
        Get.find<PipelineController>().deleteNode(node.id);
      },
    ),
  ],
),

          ],
        ),
      ),
    );
  }

  void _openConfigDialog(BuildContext context, PipelineNode node) {
    final TextEditingController inputFileController =
        TextEditingController(text: node.config['input'] ?? '');
    final TextEditingController paramController =
        TextEditingController(text: node.config['param'] ?? '');

    Get.dialog(
      AlertDialog(
        title: Text('Configure ${node.title}'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(
              controller: inputFileController,
              decoration: const InputDecoration(labelText: 'Input File Path'),
            ),
            TextField(
              controller: paramController,
              decoration: const InputDecoration(labelText: 'Parameter'),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Get.back(),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () {
              final newConfig = {
                'input': inputFileController.text,
                'param': paramController.text,
              };
              Get.find<PipelineController>()
                  .updateNodeConfig(node.id, newConfig);
              Get.back();
            },
            child: const Text('Save'),
          ),
        ],
      ),
    );
  }
}


class TempConnection extends GetxController {
  String? sourceId;

  void setSource(String id) {
    sourceId = id;
  }

  void clear() {
    sourceId = null;
  }
}



class ConnectionPainter extends CustomPainter {
  final List<PipelineNode> nodes;
  final List<Connection> connections;

  ConnectionPainter({required this.nodes, required this.connections});

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = Colors.blue
      ..strokeWidth = 2;

    for (var connection in connections) {
      final fromNode =
          nodes.firstWhereOrNull((n) => n.id == connection.fromNodeId);
      final toNode = nodes.firstWhereOrNull((n) => n.id == connection.toNodeId);
      if (fromNode != null && toNode != null) {
        final fromOffset = fromNode.position + const Offset(75, 25);
        final toOffset = toNode.position + const Offset(0, 25);
        canvas.drawLine(fromOffset, toOffset, paint);
      }
    }
  }

  @override
  bool shouldRepaint(covariant ConnectionPainter oldDelegate) => true;
}

