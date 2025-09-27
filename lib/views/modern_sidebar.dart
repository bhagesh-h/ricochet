import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:n8n_application_2/views/modern_canvas.dart';

import '../controllers/execution_controller.dart';

class ModernSidebar extends StatelessWidget {
  const ModernSidebar({Key? key}) : super(key: key);

  final List<Map<String, dynamic>> tools = const [
    {
      'name': 'FastQC',
      'category': 'Quality Control',
      'description': 'Assess sequencing data quality',
      'icon': Icons.analytics_rounded,
      'color': Color(0xFF10B981),
      'bgColor': Color(0xFFF0FDF4),
    },
    {
      'name': 'Trimmomatic',
      'category': 'Data Processing',
      'description': 'Trim and filter reads',
      'icon': Icons.content_cut_rounded,
      'color': Color(0xFF8B5CF6),
      'bgColor': Color(0xFFFAF5FF),
    },
    {
      'name': 'BWA',
      'category': 'Alignment',
      'description': 'Align sequences to reference',
      'icon': Icons.compare_arrows_rounded,
      'color': Color(0xFF8B5CF6),
      'bgColor': Color(0xFFFAF5FF),
    },
    {
      'name': 'Variant Caller',
      'category': 'Analysis',
      'description': 'Identify genetic variants',
      'icon': Icons.search_rounded,
      'color': Color(0xFF10B981),
      'bgColor': Color(0xFFF0FDF4),
    },
  ];

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 320,
      decoration: const BoxDecoration(
        color: Colors.white,
        border: Border(
          right: BorderSide(color: Color(0xFFE2E8F0)),
        ),
        boxShadow: [
          BoxShadow(
            color: Color(0x08000000),
            blurRadius: 12,
            offset: Offset(4, 0),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Header
          Container(
            padding: const EdgeInsets.all(24),
            decoration: const BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
                colors: [
                  Color(0xFFF8FAFC),
                  Color(0xFFE2E8F0),
                ],
              ),
              border: Border(
                bottom: BorderSide(color: Color(0xFFE2E8F0)),
              ),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.all(8),
                      decoration: BoxDecoration(
                        gradient: const LinearGradient(
                          colors: [Color(0xFF6366F1), Color(0xFF8B5CF6)],
                        ),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: const Icon(
                        Icons.biotech,
                        color: Colors.white,
                        size: 20,
                      ),
                    ),
                    const SizedBox(width: 12),
                    const Text(
                      'Tools',
                      style: TextStyle(
                        fontSize: 20,
                        fontWeight: FontWeight.w700,
                        color: Color(0xFF0F172A),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 8),
                Text(
                  'Drag and drop bioinformatics tools to build your pipeline',
                  style: TextStyle(
                    fontSize: 14,
                    color: Colors.grey[600],
                    height: 1.4,
                  ),
                ),
              ],
            ),
          ),
          // Tools list
          Expanded(
            child: ListView.builder(
              padding: const EdgeInsets.all(16),
              itemCount: tools.length,
              itemBuilder: (context, index) {
                final tool = tools[index];
                return Container(
                  margin: const EdgeInsets.only(bottom: 12),
                  child: Draggable<String>(
                    data: tool['name'],
                    feedback: Material(
                      elevation: 12,
                      borderRadius: BorderRadius.circular(16),
                      child: _buildToolCard(tool, isDragging: true),
                    ),
                    childWhenDragging: _buildToolCard(tool, isGhost: true),
                    child: _buildToolCard(tool),
                  ),
                );
              },
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildToolCard(Map<String, dynamic> tool, {bool isDragging = false, bool isGhost = false}) {
    return Container(
      width: isDragging ? 280 : double.infinity,
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: isGhost ? const Color(0xFFF1F5F9) : Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: isGhost 
              ? const Color(0xFFE2E8F0) 
              : (tool['color'] as Color).withOpacity(0.2),
          width: 1,
        ),
        boxShadow: isDragging
            ? [
                BoxShadow(
                  color: Colors.black.withOpacity(0.15),
                  blurRadius: 20,
                  offset: const Offset(0, 8),
                ),
              ]
            : [
                BoxShadow(
                  color: Colors.black.withOpacity(0.04),
                  blurRadius: 8,
                  offset: const Offset(0, 2),
                ),
              ],
      ),
      child: Row(
        children: [
          // Icon container
          Container(
            width: 48,
            height: 48,
            decoration: BoxDecoration(
              color: isGhost 
                  ? const Color(0xFFE2E8F0) 
                  : (tool['bgColor'] as Color),
              borderRadius: BorderRadius.circular(12),
              border: Border.all(
                color: isGhost 
                    ? const Color(0xFFCBD5E1) 
                    : (tool['color'] as Color).withOpacity(0.2),
              ),
            ),
            child: Icon(
              tool['icon'],
              color: isGhost 
                  ? const Color(0xFF94A3B8) 
                  : (tool['color'] as Color),
              size: 24,
            ),
          ),
          const SizedBox(width: 16),
          // Content
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  tool['name'],
                  style: TextStyle(
                    fontWeight: FontWeight.w700,
                    fontSize: 16,
                    color: isGhost 
                        ? const Color(0xFF94A3B8) 
                        : const Color(0xFF0F172A),
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  tool['category'],
                  style: TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w500,
                    color: isGhost 
                        ? const Color(0xFFCBD5E1) 
                        : (tool['color'] as Color),
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  tool['description'],
                  style: TextStyle(
                    fontSize: 13,
                    color: isGhost 
                        ? const Color(0xFFCBD5E1) 
                        : const Color(0xFF64748B),
                    height: 1.3,
                  ),
                ),
              ],
            ),
          ),
          // Drag indicator
          if (!isGhost)
            Container(
              padding: const EdgeInsets.all(4),
              decoration: BoxDecoration(
                color: (tool['color'] as Color).withOpacity(0.1),
                borderRadius: BorderRadius.circular(6),
              ),
              child: Icon(
                Icons.drag_indicator,
                color: (tool['color'] as Color),
                size: 16,
              ),
            ),
        ],
      ),
    );
  }
}

// Legacy compatibility classes
class Sidebar extends StatelessWidget {
  const Sidebar({Key? key}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return const ModernSidebar();
  }
}

class CanvasArea extends StatelessWidget {
  const CanvasArea({Key? key}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return const ModernCanvas();
  }
}
class ExecutionPanel extends StatelessWidget {
  const ExecutionPanel({Key? key}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    final ExecutionController execCtrl = Get.find();

    return Container(
      height: 200,
      decoration: const BoxDecoration(
        color: Color(0xFF0F172A),
        border: Border(
          top: BorderSide(color: Color(0xFF1E293B)),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Header
          Container(
            padding: const EdgeInsets.all(16),
            decoration: const BoxDecoration(
              color: Color(0xFF1E293B),
              border: Border(
                bottom: BorderSide(color: Color(0xFF334155)),
              ),
            ),
            child: SizedBox( // 👈 Wrap Row in SizedBox to provide bounded width
              width: double.infinity,
              child: Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(6),
                    decoration: BoxDecoration(
                      color: const Color(0xFF10B981).withOpacity(0.2),
                      borderRadius: BorderRadius.circular(6),
                    ),
                    child: const Icon(
                      Icons.terminal,
                      color: Color(0xFF10B981),
                      size: 16,
                    ),
                  ),
                  const SizedBox(width: 12),
                  const Text(
                    'Execution Log',
                    style: TextStyle(
                      color: Colors.white,
                      fontWeight: FontWeight.w600,
                      fontSize: 14,
                    ),
                  ),
                  const Spacer(),
                  Obx(() {
                    return execCtrl.isRunning.value
                        ? const SizedBox(
                            width: 14,
                            height: 14,
                            child: CircularProgressIndicator(
                              strokeWidth: 2,
                              valueColor: AlwaysStoppedAnimation(Color(0xFF10B981)),
                            ),
                          )
                        : IconButton(
                            onPressed: execCtrl.clearLog,
                            icon: const Icon(
                              Icons.clear_all,
                              color: Color(0xFF64748B),
                              size: 16,
                            ),
                            tooltip: 'Clear log',
                          );
                  }),
                ],
              ),
            ),
          ),
          // Log content
          Expanded(
            child: Obx(() {
              if (execCtrl.log.isEmpty) {
                return const Center(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(
                        Icons.play_circle_outline,
                        size: 32,
                        color: Color(0xFF475569),
                      ),
                      SizedBox(height: 8),
                      Text(
                        'No execution logs yet',
                        style: TextStyle(
                          color: Color(0xFF64748B),
                          fontSize: 14,
                        ),
                      ),
                      Text(
                        'Click "Execute" to run the pipeline',
                        style: TextStyle(
                          color: Color(0xFF475569),
                          fontSize: 12,
                        ),
                      ),
                    ],
                  ),
                );
              }

              return ListView.builder(
                padding: const EdgeInsets.all(12),
                itemCount: execCtrl.log.length,
                itemBuilder: (context, index) {
                  final line = execCtrl.log[index];
                  return Padding(
                    padding: const EdgeInsets.only(bottom: 2),
                    child: Text(
                      line,
                      style: const TextStyle(
                        color: Color(0xFF10B981),
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
class TempConnection extends GetxController {
  String? sourceId;

  void setSource(String id) {
    sourceId = id;
  }

  void clear() {
    sourceId = null;
  }
}