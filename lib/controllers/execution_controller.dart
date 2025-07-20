import 'package:get/get.dart';
import 'pipeline_controller.dart';

class ExecutionController extends GetxController {
  final log = <String>[].obs;

  void runPipeline() async {
    log.clear();
    final pipelineCtrl = Get.find<PipelineController>();

    final nodes = pipelineCtrl.nodes;
    final connections = pipelineCtrl.connections;

    // Very simple linear flow simulation (no branching for now)
    List<String> visited = [];

    for (var node in nodes) {
      // Avoid duplicate execution
      if (visited.contains(node.id)) continue;
      visited.add(node.id);

      log.add('🔹 Executing ${node.title}');
      log.add('   🗂 Input: ${node.config['input'] ?? 'None'}');
      log.add('   ⚙️ Param: ${node.config['param'] ?? 'None'}');

      await Future.delayed(const Duration(milliseconds: 500)); // simulate delay

      log.add('   ✅ Output: ${node.title}_result.txt');
      log.add(''); // line break
    }

    log.add('🎉 Pipeline Execution Complete!');
  }
}
