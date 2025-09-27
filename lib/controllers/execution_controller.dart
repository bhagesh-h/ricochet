import 'package:get/get.dart';
import '../models/pipeline_node.dart';
import 'pipeline_controller.dart';

class ExecutionController extends GetxController {
  final log = <String>[].obs;
  final isRunning = false.obs;

  void runPipeline() async {
    if (isRunning.value) return;

    log.clear();
    isRunning.value = true;
    final pipelineCtrl = Get.find<PipelineController>();

    log.add('🚀 Pipeline execution started');
    log.add('📊 Found ${pipelineCtrl.nodes.length} blocks');
    log.add('🔗 Found ${pipelineCtrl.connections.length} connections');
    log.add('');

    for (var node in pipelineCtrl.nodes) {
      pipelineCtrl.setNodeStatus(node.id, BlockStatus.running);
      
      log.add('⚡ Executing: ${node.title}');
      log.add('   📂 Category: ${node.category.name}');
      
      for (var param in node.parameters) {
        if (param.value != null) {
          log.add('   ⚙️ ${param.label}: ${param.value}');
        }
      }

      await Future.delayed(Duration(milliseconds: 800 + (node.parameters.length * 300)));

      final success = DateTime.now().millisecond % 10 != 0;
      
      if (success) {
        pipelineCtrl.setNodeStatus(node.id, BlockStatus.success);
        log.add('   ✅ Completed successfully');
        log.add('   📁 Output: ${node.title.toLowerCase()}_result.txt');
      } else {
        pipelineCtrl.setNodeStatus(node.id, BlockStatus.failed);
        log.add('   ❌ Execution failed');
        log.add('   🚨 Error: Processing timeout');
        break;
      }
      
      log.add('');
    }

    final allSuccess = pipelineCtrl.nodes.every((n) => n.status == BlockStatus.success);
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
}