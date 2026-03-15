import 'package:flutter/material.dart';
import 'package:get/get.dart';
import '../models/pipeline_node.dart';
import 'pipeline_controller.dart';

class ExecutionController extends GetxController {
  final log = <String>[].obs;
  final isRunning = false.obs;
  final showPanel = false.obs;
  final panelHeight = 250.0.obs;

  final Map<String, List<String>> _logsByTab = {};
  final Map<String, bool> _isRunningByTab = {};
  String? _currentTabId;

  void clearLogsAndSwitchToActiveTab(String? tabId) {
    if (tabId == null) return;
    
    if (_currentTabId != null) {
      _logsByTab[_currentTabId!] = List.from(log);
      _isRunningByTab[_currentTabId!] = isRunning.value;
    }
    
    _currentTabId = tabId;
    log.clear();
    
    if (_logsByTab.containsKey(tabId)) {
      log.addAll(_logsByTab[tabId]!);
    }
    isRunning.value = _isRunningByTab[tabId] ?? false;
  }

  void _addLog(String tabId, String message) {
    if (!_logsByTab.containsKey(tabId)) {
      _logsByTab[tabId] = [];
    }
    _logsByTab[tabId]!.add(message);
    
    if (_currentTabId == tabId) {
      log.add(message);
    }
  }

  void _setRunning(String tabId, bool running) {
    _isRunningByTab[tabId] = running;
    if (_currentTabId == tabId) {
      isRunning.value = running;
    }
  }

  void setPanelHeight(double height) {
    // Clamp height between min and max values
    panelHeight.value = height.clamp(100.0, 600.0);
  }

  /// Validates the pipeline before execution.
  /// Returns a list of human-readable issues. Empty list = valid.
  List<String> validatePipeline() {
    final pipelineCtrl = Get.find<PipelineController>();
    final errors = <String>[];

    // 1. Empty canvas
    if (pipelineCtrl.nodes.isEmpty) {
      errors.add('🚫 Canvas is empty. Add at least one node before executing.');
      return errors; // No point checking further
    }

    // 2. Docker nodes with no command set
    for (final node in pipelineCtrl.nodes) {
      if (node.dockerImage != null) {
        final commandParam = node.parameters
            .firstWhereOrNull((p) => p.key == 'command');
        final command = commandParam?.value?.toString().trim() ?? '';
        if (command.isEmpty) {
          errors.add('⚠️ Node "${node.title}": Command field is empty.');
        }
        // Check image still set
        final imageParam = node.parameters
            .firstWhereOrNull((p) => p.key == 'image');
        final image = imageParam?.value?.toString().trim() ?? '';
        if (image.isEmpty) {
          errors.add('⚠️ Node "${node.title}": Docker Image field is empty.');
        }
      }
    }

    // 3. Disconnected nodes (only flag in multi-node pipeline)
    if (pipelineCtrl.nodes.length > 1) {
      for (final node in pipelineCtrl.nodes) {
        final hasAnyConnection = pipelineCtrl.connections.any(
          (c) => c.fromNodeId == node.id || c.toNodeId == node.id,
        );
        if (!hasAnyConnection) {
          errors.add('🔗 Node "${node.title}" is not connected to any other node.');
        }
      }
    }

    return errors;
  }

  void runPipeline() async {
    final tabId = _currentTabId;
    if (tabId == null) return;

    if (_isRunningByTab[tabId] == true) return;

    // --- Validate before running ---
    final errors = validatePipeline();
    if (errors.isNotEmpty) {
      Get.dialog(
        AlertDialog(
          title: Row(
            children: const [
              Icon(Icons.warning_amber_rounded, color: Color(0xFFF59E0B)),
              SizedBox(width: 8),
              Text('Pipeline Issues Found'),
            ],
          ),
          content: SingleChildScrollView(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                const Text(
                  'Please fix these issues before executing:',
                  style: TextStyle(fontWeight: FontWeight.w600),
                ),
                const SizedBox(height: 12),
                ...errors.map((e) => Padding(
                  padding: const EdgeInsets.only(bottom: 8),
                  child: Text(e, style: const TextStyle(fontSize: 13)),
                )),
              ],
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Get.back(),
              child: const Text('Fix Issues'),
            ),
            ElevatedButton(
              style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFFF59E0B)),
              onPressed: () { Get.back(); _doRunPipeline(tabId); },
              child: const Text('Run Anyway', style: TextStyle(color: Colors.white)),
            ),
          ],
        ),
      );
      return;
    }

    _doRunPipeline(tabId);
  }

  void _doRunPipeline(String tabId) async {
    if (_currentTabId == tabId) log.clear();
    _logsByTab[tabId] = [];
    
    _setRunning(tabId, true);
    showPanel.value = true; // Show panel when running
    final pipelineCtrl = Get.find<PipelineController>();

    _addLog(tabId, '🚀 Pipeline execution started');
    _addLog(tabId, '📊 Found ${pipelineCtrl.nodes.length} blocks');
    _addLog(tabId, '🔗 Found ${pipelineCtrl.connections.length} connections');
    _addLog(tabId, '');

    // 1. Determine execution order (Topological Sort)
    List<PipelineNode> executionOrder;
    try {
      executionOrder = pipelineCtrl.getExecutionOrder();
      _addLog(tabId,
          '📋 Execution order determined: ${executionOrder.map((n) => n.title).join(' -> ')}');
    } catch (e) {
      _addLog(tabId, '❌ Pipeline execution failed');
      _addLog(tabId, '🚨 Error: ${e.toString().replaceAll('Exception: ', '')}');

      // Show error dialog
      Get.dialog(
        AlertDialog(
          title: const Text('Pipeline Error'),
          content: Text(e.toString().replaceAll('Exception: ', '')),
          actions: [
            TextButton(
              onPressed: () => Get.back(),
              child: const Text('OK'),
            ),
          ],
        ),
      );

      _setRunning(tabId, false);
      return;
    }

    _addLog(tabId, '');

    // Map to store output file paths: nodeId -> filePath
    final nodeOutputs = <String, String>{};

    // 2. Execute nodes in order
    for (var node in executionOrder) {
      pipelineCtrl.setNodeStatus(node.id, BlockStatus.running);

      _addLog(tabId, '⚡ Executing: ${node.title}');
      _addLog(tabId, '   📂 Category: ${node.category.name}');

      for (var param in node.parameters) {
        if (param.value != null && param.value.toString().isNotEmpty) {
          _addLog(tabId, '   ⚙️ ${param.label}: ${param.value}');
        }
      }

      // Prepare input files from upstream nodes
      final inputFiles = <String, String>{};
      final upstreamConnections =
          pipelineCtrl.connections.where((c) => c.toNodeId == node.id);

      for (var connection in upstreamConnections) {
        final upstreamNodeId = connection.fromNodeId;
        if (nodeOutputs.containsKey(upstreamNodeId)) {
          // Use the port name as the key, or default to 'input'
          // If multiple inputs, we might need unique keys
          final key = connection.toPort.isNotEmpty
              ? connection.toPort
              : 'input_${upstreamNodeId.substring(0, 4)}';
          inputFiles[key] = nodeOutputs[upstreamNodeId]!;
          _addLog(tabId,
              '   📥 Input from ${pipelineCtrl.nodes.firstWhere((n) => n.id == upstreamNodeId).title}');
        }
      }

      // Execute the node using the real pipeline controller logic
      await pipelineCtrl.executeNode(node.id, inputFiles: inputFiles);

      // Check status after execution
      if (node.status == BlockStatus.success) {
        _addLog(tabId, '   ✅ Completed successfully');

        // Get real output file path
        final outputParam = node.parameters.firstWhereOrNull(
          (p) => p.key == '_output_file',
        );

        if (outputParam?.value != null) {
          final path = outputParam!.value.toString();
          _addLog(tabId, '   📁 Output: $path');

          // Store output for downstream nodes
          nodeOutputs[node.id] = path;
        }
      } else {
        _addLog(tabId, '   ❌ Execution failed');
        // Add last few lines of error logs if available
        final errorLogs = node.logs
            .where((l) => l.contains('STDERR') || l.contains('Error'))
            .take(3);
        for (final err in errorLogs) {
          _addLog(tabId, '   $err');
        }

        // Stop pipeline on failure
        _addLog(tabId, '');
        _addLog(tabId,
            '⚠️ Pipeline execution stopped due to failure in ${node.title}');
        _setRunning(tabId, false);
        return;
      }

      _addLog(tabId, '');
    }

    final allSuccess =
        pipelineCtrl.nodes.every((n) => n.status == BlockStatus.success);
    if (allSuccess) {
      _addLog(tabId, '🎉 Pipeline completed successfully!');
      _addLog(tabId, '📈 All blocks executed without errors');
    } else {
      _addLog(tabId, '⚠️ Pipeline execution stopped due to errors');
    }

    _setRunning(tabId, false);
  }

  void clearLog() {
    if (_currentTabId != null) {
      _logsByTab[_currentTabId!] = [];
    }
    log.clear();
  }

  void togglePanel() {
    showPanel.value = !showPanel.value;
  }

  /// Stop all running containers for the current tab (fix #6)
  void stopPipeline() {
    final tabId = _currentTabId;
    if (tabId == null) return;
    if (_isRunningByTab[tabId] != true) return;

    _addLog(tabId, '🛑 Stop requested by user...');

    final pipelineCtrl = Get.find<PipelineController>();
    for (final node in pipelineCtrl.nodes) {
      if (node.status == BlockStatus.running) {
        pipelineCtrl.stopNode(node.id);
      }
    }

    _addLog(tabId, '⚠️ Pipeline was stopped by user.');
    _setRunning(tabId, false);
  }
}
