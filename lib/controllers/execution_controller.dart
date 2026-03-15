import 'package:flutter/material.dart';
import 'package:get/get.dart';
import '../models/pipeline_node.dart';
import 'pipeline_controller.dart';

class ExecutionController extends GetxController {
  final log = <String>[].obs;
  final isRunning = false.obs;
  final showPanel = false.obs;
  final panelHeight = 250.0.obs;

  void setPanelHeight(double height) {
    // Clamp height between min and max values
    panelHeight.value = height.clamp(100.0, 600.0);
  }

  void runPipeline() async {
    if (isRunning.value) return;

    log.clear();
    isRunning.value = true;
    showPanel.value = true; // Show panel when running
    final pipelineCtrl = Get.find<PipelineController>();

    log.add('🚀 Pipeline execution started');
    log.add('📊 Found ${pipelineCtrl.nodes.length} blocks');
    log.add('🔗 Found ${pipelineCtrl.connections.length} connections');
    log.add('');

    // 1. Determine execution order (Topological Sort)
    List<PipelineNode> executionOrder;
    try {
      executionOrder = pipelineCtrl.getExecutionOrder();
      log.add(
          '📋 Execution order determined: ${executionOrder.map((n) => n.title).join(' -> ')}');
    } catch (e) {
      log.add('❌ Pipeline execution failed');
      log.add('🚨 Error: ${e.toString().replaceAll('Exception: ', '')}');

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

      isRunning.value = false;
      return;
    }

    log.add('');

    // Map to store output file paths: nodeId -> filePath
    final nodeOutputs = <String, String>{};

    // 2. Execute nodes in order
    for (var node in executionOrder) {
      pipelineCtrl.setNodeStatus(node.id, BlockStatus.running);

      log.add('⚡ Executing: ${node.title}');
      log.add('   📂 Category: ${node.category.name}');

      for (var param in node.parameters) {
        if (param.value != null && param.value.toString().isNotEmpty) {
          log.add('   ⚙️ ${param.label}: ${param.value}');
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
          log.add(
              '   📥 Input from ${pipelineCtrl.nodes.firstWhere((n) => n.id == upstreamNodeId).title}');
        }
      }

      // Execute the node using the real pipeline controller logic
      await pipelineCtrl.executeNode(node.id, inputFiles: inputFiles);

      // Check status after execution
      if (node.status == BlockStatus.success) {
        log.add('   ✅ Completed successfully');

        // Get real output file path
        final outputParam = node.parameters.firstWhereOrNull(
          (p) => p.key == '_output_file',
        );

        if (outputParam?.value != null) {
          final path = outputParam!.value.toString();
          log.add('   📁 Output: $path');

          // Store output for downstream nodes
          nodeOutputs[node.id] = path;
        }
      } else {
        log.add('   ❌ Execution failed');
        // Add last few lines of error logs if available
        final errorLogs = node.logs
            .where((l) => l.contains('STDERR') || l.contains('Error'))
            .take(3);
        for (final err in errorLogs) {
          log.add('   $err');
        }

        // Stop pipeline on failure
        log.add('');
        log.add(
            '⚠️ Pipeline execution stopped due to failure in ${node.title}');
        isRunning.value = false;
        return;
      }

      log.add('');
    }

    final allSuccess =
        pipelineCtrl.nodes.every((n) => n.status == BlockStatus.success);
    if (allSuccess) {
      log.add('🎉 Pipeline completed successfully!');
      log.add('📈 All blocks executed without errors');
    } else {
      log.add('⚠️ Pipeline execution stopped due to errors');
    }

    isRunning.value = false;
  }

  void clearLog() {
    log.clear();
  }

  void togglePanel() {
    showPanel.value = !showPanel.value;
  }
}
