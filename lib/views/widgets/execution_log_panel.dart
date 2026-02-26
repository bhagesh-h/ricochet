import 'package:flutter/material.dart';
import 'package:get/get.dart';
import '../../controllers/pipeline_controller.dart';
import '../../models/pipeline_node.dart';

class ExecutionLogPanel extends StatelessWidget {
  const ExecutionLogPanel({Key? key}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    final controller = Get.find<PipelineController>();

    return Obx(() {
      final selectedId = controller.selectedNode.value;
      if (selectedId == null) return const SizedBox.shrink();

      final node = controller.nodes.firstWhereOrNull((n) => n.id == selectedId);
      // Show panel if node exists and has logs, or is running
      if (node == null ||
          (node.logs.isEmpty && node.status != BlockStatus.running)) {
        return const SizedBox.shrink();
      }

      return Positioned(
        bottom: 0,
        left: 0,
        right: 350, // Avoid overlap with sidebar
        child: Container(
          height: 250,
          decoration: BoxDecoration(
            color: Colors.white,
            border: Border(top: BorderSide(color: Colors.grey.shade300)),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withOpacity(0.05),
                blurRadius: 10,
                offset: const Offset(0, -5),
              ),
            ],
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Header
              Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                color: const Color(0xFFF8FAFC),
                child: Row(
                  children: [
                    Icon(Icons.terminal_rounded,
                        size: 16, color: Colors.blueGrey.shade700),
                    const SizedBox(width: 8),
                    Text(
                      'Execution Logs: ${node.title}',
                      style: TextStyle(
                        fontWeight: FontWeight.w600,
                        color: Colors.blueGrey.shade900,
                        fontSize: 13,
                      ),
                    ),
                    const Spacer(),
                    // Open output folder button
                    TextButton.icon(
                      onPressed: () =>
                          Get.find<PipelineController>().openOutputDirectory(),
                      icon: const Icon(Icons.folder_open, size: 14),
                      label: const Text('Open Output Folder',
                          style: TextStyle(fontSize: 11)),
                      style: TextButton.styleFrom(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 8, vertical: 4),
                      ),
                    ),
                    const SizedBox(width: 8),
                    if (node.status == BlockStatus.running)
                      Container(
                        margin: const EdgeInsets.only(right: 12),
                        padding: const EdgeInsets.symmetric(
                            horizontal: 8, vertical: 2),
                        decoration: BoxDecoration(
                          color: Colors.blue.withOpacity(0.1),
                          borderRadius: BorderRadius.circular(4),
                          border:
                              Border.all(color: Colors.blue.withOpacity(0.2)),
                        ),
                        child: Row(
                          children: const [
                            SizedBox(
                              width: 8,
                              height: 8,
                              child: CircularProgressIndicator(strokeWidth: 2),
                            ),
                            SizedBox(width: 6),
                            Text(
                              'Running',
                              style: TextStyle(
                                  fontSize: 10,
                                  color: Colors.blue,
                                  fontWeight: FontWeight.bold),
                            ),
                          ],
                        ),
                      ),
                    IconButton(
                      icon: const Icon(Icons.close, size: 16),
                      onPressed: () => controller.selectNode(null),
                      padding: EdgeInsets.zero,
                      constraints: const BoxConstraints(),
                    ),
                  ],
                ),
              ),
              const Divider(height: 1),

              // Logs List
              Expanded(
                child: GetBuilder<PipelineController>(
                  id: node.id,
                  builder: (_) {
                    if (node.logs.isEmpty) {
                      return const Center(
                        child: Text(
                          'Waiting for logs...',
                          style: TextStyle(color: Colors.grey, fontSize: 12),
                        ),
                      );
                    }

                    return ListView.builder(
                      padding: const EdgeInsets.all(12),
                      itemCount: node.logs.length,
                      itemBuilder: (context, index) {
                        final log = node.logs[index];
                        final isError = log.contains('[STDERR]');
                        final isStdout = log.contains('[STDOUT]');

                        Color color =
                            const Color(0xFF334155); // Default slate-700
                        if (isError) color = const Color(0xFFEF4444);
                        if (isStdout) color = const Color(0xFF0F172A);

                        return Padding(
                          padding: const EdgeInsets.only(bottom: 4),
                          child: Text(
                            log,
                            style: TextStyle(
                              fontFamily: 'monospace',
                              fontSize: 12,
                              color: color,
                              height: 1.4,
                            ),
                          ),
                        );
                      },
                    );
                  },
                ),
              ),
            ],
          ),
        ),
      );
    });
  }
}
