import 'package:flutter/material.dart';
import 'package:get/get.dart';
import '../../controllers/execution_controller.dart';

class ExecutionPanel extends StatefulWidget {
  const ExecutionPanel({Key? key}) : super(key: key);

  @override
  State<ExecutionPanel> createState() => _ExecutionPanelState();
}

class _ExecutionPanelState extends State<ExecutionPanel> {
  final ExecutionController execCtrl = Get.find();
  bool _isResizing = false;

  @override
  Widget build(BuildContext context) {
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
                height: 4, // Thin resize line
                color:
                    _isResizing ? const Color(0xFF6366F1) : Colors.transparent,
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
                const Icon(Icons.terminal, color: Color(0xFF10B981), size: 16),
                const SizedBox(width: 8),
                const Text(
                  'Execution Console',
                  style: TextStyle(
                    color: Colors.white,
                    fontWeight: FontWeight.w600,
                    fontSize: 13,
                  ),
                ),
                const Spacer(),
                Obx(() => Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        if (!execCtrl.isRunning.value)
                          IconButton(
                            onPressed: execCtrl.clearLog,
                            icon: const Icon(Icons.delete_outline, size: 16),
                            color: const Color(0xFF94A3B8),
                            tooltip: 'Clear Console',
                            padding: EdgeInsets.zero,
                            constraints: const BoxConstraints(),
                          ),
                        const SizedBox(width: 12),
                        IconButton(
                          onPressed: execCtrl.togglePanel,
                          icon: const Icon(Icons.close, size: 16),
                          color: const Color(0xFF94A3B8),
                          tooltip: 'Close Panel',
                          padding: EdgeInsets.zero,
                          constraints: const BoxConstraints(),
                        ),
                      ],
                    )),
              ],
            ),
          ),

          // Log Content
          Expanded(
            child: Obx(() {
              if (execCtrl.log.isEmpty) {
                return Center(
                  child: Text(
                    'Ready to execute pipeline...',
                    style: TextStyle(
                      color: const Color(0xFF64748B).withOpacity(0.5),
                      fontSize: 13,
                      fontFamily: 'monospace',
                    ),
                  ),
                );
              }

              return ListView.builder(
                padding: const EdgeInsets.all(12),
                itemCount: execCtrl.log.length,
                reverse:
                    true, // Auto-scroll to bottom (newest items first if we reverse list, but standard terminal appends)
                // Actually, for a terminal, we usually want to stick to bottom.
                // Let's keep standard order but use a ScrollController if needed.
                // For simplicity, let's just show the list.
                itemBuilder: (context, index) {
                  // If we want auto-scroll, we can use reverse: true and insert at 0?
                  // Or just standard list.
                  final line = execCtrl.log[index];
                  return Padding(
                    padding: const EdgeInsets.only(bottom: 4),
                    child: SelectableText(
                      // Allow text selection
                      line,
                      style: const TextStyle(
                        color: Color(0xFFE2E8F0),
                        fontSize: 12,
                        fontFamily: 'monospace',
                        height: 1.4,
                      ),
                    ),
                  );
                },
              );
            }),
          ),
        ],
      ),
    );
  }
}
