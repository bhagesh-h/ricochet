import 'package:flutter/material.dart';
import 'package:get/get.dart';
import '../../controllers/execution_controller.dart';
import '../../controllers/pipeline_controller.dart';
import '../../models/pipeline_node.dart';

class ExecutionPanel extends StatefulWidget {
  const ExecutionPanel({Key? key}) : super(key: key);

  @override
  State<ExecutionPanel> createState() => _ExecutionPanelState();
}

class _ExecutionPanelState extends State<ExecutionPanel> {
  final ExecutionController execCtrl = Get.find();
  final PipelineController pipelineCtrl = Get.find();
  bool _isResizing = false;

  @override
  Widget build(BuildContext context) {
    return Obx(() {
      // Check if we should show node-specific logs or pipeline logs
      final selectedNodeId = pipelineCtrl.selectedNode.value;
      final selectedNode = selectedNodeId != null
          ? pipelineCtrl.nodes.firstWhereOrNull((n) => n.id == selectedNodeId)
          : null;

      // Show node logs if: node is selected AND (has logs OR is running)
      final showNodeLogs = selectedNode != null &&
          (selectedNode.logs.isNotEmpty ||
              selectedNode.status == BlockStatus.running);

      // Show pipeline logs if execution console is visible
      final showPipelineLogs = execCtrl.showPanel.value;

      // Don't show panel if nothing to display
      if (!showNodeLogs && !showPipelineLogs) {
        return const SizedBox.shrink();
      }

      return Container(
        decoration: const BoxDecoration(
          color: Color(0xFF0F172A),
          border: Border(
            top: BorderSide(color: Color(0xFF1E293B)),
          ),
          boxShadow: [
            BoxShadow(
              color: Colors.black26,
              blurRadius: 10,
              offset: Offset(0, -2),
            ),
          ],
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Resize Handle
            GestureDetector(
              onVerticalDragStart: (_) => setState(() => _isResizing = true),
              onVerticalDragEnd: (_) => setState(() => _isResizing = false),
              onVerticalDragUpdate: (details) {
                final newHeight = execCtrl.panelHeight.value - details.delta.dy;
                execCtrl.setPanelHeight(newHeight);
              },
              child: MouseRegion(
                cursor: SystemMouseCursors.resizeRow,
                child: Container(
                  height: 4,
                  color: _isResizing
                      ? const Color(0xFF6366F1)
                      : Colors.transparent,
                  alignment: Alignment.center,
                  child: Container(
                    width: 40,
                    height: 4,
                    decoration: BoxDecoration(
                      color: const Color(0xFF334155),
                      borderRadius: BorderRadius.circular(2),
                    ),
                  ),
                ),
              ),
            ),

            // Header
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
              decoration: const BoxDecoration(
                color: Color(0xFF1E293B),
                border: Border(
                  bottom: BorderSide(color: Color(0xFF334155)),
                ),
              ),
              child: Row(
                children: [
                  const Icon(Icons.terminal,
                      color: Color(0xFF10B981), size: 16),
                  const SizedBox(width: 8),
                  Text(
                    showNodeLogs
                        ? 'Execution Logs: ${selectedNode.title}'
                        : 'Execution Console',
                    style: const TextStyle(
                      color: Colors.white,
                      fontWeight: FontWeight.w600,
                      fontSize: 13,
                    ),
                  ),
                  const Spacer(),

                  // Show "Open Output Folder" button for node logs
                  if (showNodeLogs) ...[
                    TextButton.icon(
                      onPressed: () => pipelineCtrl.openOutputDirectory(),
                      icon: const Icon(Icons.folder_open,
                          size: 14, color: Color(0xFF10B981)),
                      label: const Text(
                        'Open Output Folder',
                        style:
                            TextStyle(fontSize: 11, color: Color(0xFF10B981)),
                      ),
                      style: TextButton.styleFrom(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 8, vertical: 4),
                      ),
                    ),
                    const SizedBox(width: 8),
                  ],

                  // Show "Open Run Folder" button for pipeline logs
                  if (!showNodeLogs) ...[
                    TextButton.icon(
                      onPressed: () => pipelineCtrl.openOutputDirectory(),
                      icon: const Icon(Icons.folder_open,
                          size: 14, color: Color(0xFF3B82F6)),
                      label: const Text(
                        'Open Run Folder',
                        style:
                            TextStyle(fontSize: 11, color: Color(0xFF3B82F6)),
                      ),
                      style: TextButton.styleFrom(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 8, vertical: 4),
                      ),
                    ),
                    const SizedBox(width: 8),
                  ],

                  // Running indicator
                  if (showNodeLogs &&
                      selectedNode.status == BlockStatus.running)
                    Container(
                      margin: const EdgeInsets.only(right: 12),
                      padding: const EdgeInsets.symmetric(
                          horizontal: 8, vertical: 2),
                      decoration: BoxDecoration(
                        color: const Color(0xFF10B981).withOpacity(0.2),
                        borderRadius: BorderRadius.circular(4),
                        border: Border.all(
                            color: const Color(0xFF10B981).withOpacity(0.3)),
                      ),
                      child: Row(
                        children: [
                          const SizedBox(
                            width: 8,
                            height: 8,
                            child: CircularProgressIndicator(
                              strokeWidth: 2,
                              valueColor: AlwaysStoppedAnimation<Color>(
                                  Color(0xFF10B981)),
                            ),
                          ),
                          const SizedBox(width: 6),
                          const Text(
                            'Running',
                            style: TextStyle(
                              fontSize: 10,
                              color: Color(0xFF10B981),
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ],
                      ),
                    ),

                  // Clear button (only for pipeline logs)
                  if (showPipelineLogs &&
                      !execCtrl.isRunning.value &&
                      !showNodeLogs)
                    IconButton(
                      onPressed: execCtrl.clearLog,
                      icon: const Icon(Icons.delete_outline, size: 16),
                      color: const Color(0xFF94A3B8),
                      tooltip: 'Clear Console',
                      padding: EdgeInsets.zero,
                      constraints: const BoxConstraints(),
                    ),

                  const SizedBox(width: 12),

                  // Close button
                  IconButton(
                    onPressed: () {
                      if (showNodeLogs) {
                        pipelineCtrl.selectNode(null);
                      } else {
                        execCtrl.togglePanel();
                      }
                    },
                    icon: const Icon(Icons.close, size: 16),
                    color: const Color(0xFF94A3B8),
                    padding: EdgeInsets.zero,
                    constraints: const BoxConstraints(),
                  ),
                ],
              ),
            ),

            // Content
            Expanded(
              child: showNodeLogs
                  ? _buildNodeLogs(selectedNode)
                  : _buildPipelineLogs(),
            ),
          ],
        ),
      );
    });
  }

  Widget _buildNodeLogs(PipelineNode node) {
    return GetBuilder<PipelineController>(
      id: node.id,
      builder: (_) {
        if (node.logs.isEmpty) {
          return const Center(
            child: Text(
              'Waiting for logs...',
              style: TextStyle(color: Color(0xFF64748B), fontSize: 12),
            ),
          );
        }

        return ListView.builder(
          padding: const EdgeInsets.all(12),
          itemCount: node.logs.length,
          itemBuilder: (context, index) {
            final log = node.logs[index];
            final isError = log.contains('[STDERR]');
            final isSystem = log.contains('[SYSTEM]');
            final isStdout = log.contains('[STDOUT]');

            Color color = const Color(0xFF94A3B8); // Default
            if (isError) color = const Color(0xFFEF4444); // Red
            if (isStdout) color = const Color(0xFF10B981); // Green
            if (isSystem) color = const Color(0xFF3B82F6); // Blue

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
    );
  }

  Widget _buildPipelineLogs() {
    return Obx(() {
      if (execCtrl.log.isEmpty) {
        return const Center(
          child: Text(
            'No execution logs yet. Click "Execute" to run the pipeline.',
            style: TextStyle(color: Color(0xFF64748B), fontSize: 12),
          ),
        );
      }

      return ListView.builder(
        padding: const EdgeInsets.all(12),
        itemCount: execCtrl.log.length,
        itemBuilder: (context, index) {
          final log = execCtrl.log[index];

          // Determine color based on log content
          Color color = const Color(0xFF94A3B8);
          if (log.contains('✅') || log.contains('🎉')) {
            color = const Color(0xFF10B981);
          } else if (log.contains('❌') || log.contains('⚠️')) {
            color = const Color(0xFFEF4444);
          } else if (log.contains('🚀') || log.contains('▶️')) {
            color = const Color(0xFF3B82F6);
          }

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
    });
  }
}
