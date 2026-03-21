import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
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

  // Scroll controllers for auto-scroll
  final ScrollController _pipelineScrollCtrl = ScrollController();
  final ScrollController _nodeScrollCtrl = ScrollController();

  // ── Elapsed time ──────────────────────────────────────────────────────────
  Timer? _elapsedTimer;
  DateTime? _runStartTime;
  int _elapsedSeconds = 0;

  @override
  void initState() {
    super.initState();
    _pipelineScrollCtrl.addListener(() => _onScroll(_pipelineScrollCtrl));
    _nodeScrollCtrl.addListener(() => _onScroll(_nodeScrollCtrl));

    // Listen for pipeline start / stop to drive the elapsed timer.
    ever(execCtrl.isRunning, (bool running) {
      if (running) {
        _runStartTime = DateTime.now();
        _elapsedSeconds = 0;
        _elapsedTimer?.cancel();
        _elapsedTimer = Timer.periodic(const Duration(seconds: 1), (_) {
          if (mounted) {
            setState(() {
              _elapsedSeconds =
                  DateTime.now().difference(_runStartTime!).inSeconds;
            });
          }
        });
      } else {
        _elapsedTimer?.cancel();
        _elapsedTimer = null;
      }
    });
  }

  @override
  void dispose() {
    _elapsedTimer?.cancel();
    _pipelineScrollCtrl.dispose();
    _nodeScrollCtrl.dispose();
    super.dispose();
  }

  String get _elapsedLabel {
    if (_elapsedSeconds < 60) return '${_elapsedSeconds}s';
    final m = _elapsedSeconds ~/ 60;
    final s = (_elapsedSeconds % 60).toString().padLeft(2, '0');
    return '${m}m ${s}s';
  }

  bool _shouldAutoScroll = true;

  void _scrollToBottom(ScrollController ctrl) {
    if (!_shouldAutoScroll) return;

    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (ctrl.hasClients) {
        final maxScroll = ctrl.position.maxScrollExtent;
        final currentScroll = ctrl.offset;
        
        // Only scroll if we are reasonably close to the bottom 
        // OR if the user is already at the bottom
        if (maxScroll - currentScroll < 100 || currentScroll == 0) {
           ctrl.animateTo(
            maxScroll,
            duration: const Duration(milliseconds: 300),
            curve: Curves.easeOutCubic,
          );
        }
      }
    });
  }

  // Handle manual scroll to toggle auto-scroll
  void _onScroll(ScrollController ctrl) {
    if (ctrl.hasClients) {
      final isAtBottom = ctrl.offset >= ctrl.position.maxScrollExtent - 50;
      if (_shouldAutoScroll != isAtBottom) {
        setState(() => _shouldAutoScroll = isAtBottom);
      }
    }
  }

  void _copyToClipboard(List<String> logs) {
    final text = logs.join('\n');
    Clipboard.setData(ClipboardData(text: text));
    Get.snackbar(
      'Copied',
      'Logs copied to clipboard',
      snackPosition: SnackPosition.BOTTOM,
      duration: const Duration(seconds: 2),
      backgroundColor: const Color(0xFF1E293B),
      colorText: Colors.white,
    );
  }

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

      return SizedBox(
        height: execCtrl.panelHeight.value,
        child: Container(
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

                    // ── Stop Pipeline button (fix #6) ─────────────────────
                    if (execCtrl.isRunning.value)
                      Padding(
                        padding: const EdgeInsets.only(right: 8),
                        child: TextButton.icon(
                          onPressed: () => execCtrl.stopPipeline(),
                          icon: const Icon(Icons.stop_circle_outlined,
                              size: 14, color: Color(0xFFEF4444)),
                          label: const Text(
                            'Stop',
                            style: TextStyle(
                                fontSize: 11, color: Color(0xFFEF4444)),
                          ),
                          style: TextButton.styleFrom(
                            padding: const EdgeInsets.symmetric(
                                horizontal: 8, vertical: 4),
                          ),
                        ),
                      ),

                    // Open Output Folder
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

                    // Running indicator with elapsed time
                    if (execCtrl.isRunning.value)
                      Container(
                        margin: const EdgeInsets.only(right: 12),
                        padding: const EdgeInsets.symmetric(
                            horizontal: 8, vertical: 4),
                        decoration: BoxDecoration(
                          color: const Color(0xFF10B981).withValues(alpha: 0.15),
                          borderRadius: BorderRadius.circular(6),
                          border: Border.all(
                              color: const Color(0xFF10B981)
                                  .withValues(alpha: 0.4)),
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            const SizedBox(
                              width: 9,
                              height: 9,
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
                                fontSize: 11,
                                color: Color(0xFF10B981),
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                            if (_elapsedSeconds > 0) ...[
                              const SizedBox(width: 6),
                              Container(
                                width: 1,
                                height: 10,
                                color: const Color(0xFF10B981)
                                    .withValues(alpha: 0.4),
                              ),
                              const SizedBox(width: 6),
                              Text(
                                _elapsedLabel,
                                style: const TextStyle(
                                  fontSize: 11,
                                  color: Color(0xFF6EE7B7),
                                  fontWeight: FontWeight.w500,
                                ),
                              ),
                            ],
                          ],
                        ),
                      ),

                    // ── Copy to clipboard (fix #9) ──────────────────────
                    IconButton(
                      onPressed: () {
                        if (showNodeLogs) {
                          _copyToClipboard(selectedNode.logs);
                        } else {
                          _copyToClipboard(execCtrl.log.toList());
                        }
                      },
                      icon: const Icon(Icons.copy, size: 14),
                      color: const Color(0xFF94A3B8),
                      tooltip: 'Copy logs to clipboard',
                      padding: EdgeInsets.zero,
                      constraints: const BoxConstraints(),
                    ),

                    const SizedBox(width: 12),

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
                child: Stack(
                  children: [
                    showNodeLogs
                        ? _buildNodeLogs(selectedNode)
                        : _buildPipelineLogs(),
                    
                    // Floating "Scroll to bottom" button if auto-scroll is paused
                    if (!_shouldAutoScroll)
                      Positioned(
                        right: 20,
                        bottom: 20,
                        child: FloatingActionButton.small(
                          onPressed: () {
                            setState(() => _shouldAutoScroll = true);
                            _scrollToBottom(showNodeLogs ? _nodeScrollCtrl : _pipelineScrollCtrl);
                          },
                          backgroundColor: const Color(0xFF6366F1),
                          child: const Icon(Icons.arrow_downward, size: 18),
                        ),
                      ),
                  ],
                ),
              ),
            ],
          ),
        ),
      );
    });
  }

  Widget _buildNodeLogs(PipelineNode node) {
    return GetBuilder<PipelineController>(
      id: node.id,
      builder: (_) {
        // Auto-scroll when new logs arrive (fix #8)
        _scrollToBottom(_nodeScrollCtrl);

        if (node.logs.isEmpty) {
          return Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                const SizedBox(
                  width: 28,
                  height: 28,
                  child: CircularProgressIndicator(
                    strokeWidth: 2.5,
                    valueColor: AlwaysStoppedAnimation<Color>(Color(0xFF6366F1)),
                  ),
                ),
                const SizedBox(height: 16),
                const Text(
                  'Container is running...',
                  style: TextStyle(
                    color: Color(0xFF94A3B8),
                    fontSize: 13,
                    fontWeight: FontWeight.w500,
                  ),
                ),
                const SizedBox(height: 6),
                Text(
                  'Elapsed: $_elapsedLabel',
                  style: const TextStyle(
                    color: Color(0xFF6EE7B7),
                    fontSize: 12,
                    fontFamily: 'monospace',
                  ),
                ),
                const SizedBox(height: 10),
                const Text(
                  'Logs will appear here when the container produces output.',
                  style: TextStyle(color: Color(0xFF475569), fontSize: 11),
                  textAlign: TextAlign.center,
                ),
              ],
            ),
          );
        }

        return ListView.builder(
          controller: _nodeScrollCtrl,
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
      // Auto-scroll when new logs arrive (fix #8)
      _scrollToBottom(_pipelineScrollCtrl);

      if (execCtrl.log.isEmpty) {
        return const Center(
          child: Text(
            'No execution logs yet. Click "Execute" to run the pipeline.',
            style: TextStyle(color: Color(0xFF64748B), fontSize: 12),
          ),
        );
      }

      return ListView.builder(
        controller: _pipelineScrollCtrl,
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
