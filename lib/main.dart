import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:n8n_application_2/controllers/execution_controller.dart';
import 'package:n8n_application_2/views/execution_panel.dart';
import 'controllers/pipeline_controller.dart';
import 'views/sidebar.dart';
import 'views/canvas_area.dart';

void main() {
  Get.put(PipelineController());
  Get.put(TempConnection());
  Get.put(ExecutionController());
  runApp(const MyApp());
}


class MyApp extends StatelessWidget {
  const MyApp();

  @override
  Widget build(BuildContext context) {
    final ExecutionController execCtrl = Get.find();

    return GetMaterialApp(
      title: 'Pipeline Designer',
      home: Scaffold(
        appBar: AppBar(

          title: const Text('Pipeline Designer'),
          actions: [
  ElevatedButton.icon(
    onPressed: execCtrl.runPipeline,
    icon: const Icon(Icons.play_arrow),
    label: const Text('Run Pipeline'),
    style: ElevatedButton.styleFrom(backgroundColor: Colors.green),
  ),
  const SizedBox(width: 8),
  ElevatedButton.icon(
    onPressed: () {
      Get.find<PipelineController>().clearAll();
    },
    icon: const Icon(Icons.delete_outline),
    label: const Text('Clear All'),
    style: ElevatedButton.styleFrom(backgroundColor: Colors.red),
  ),
  const SizedBox(width: 20),
],

        ),
        body: Column(
          children: const [
            Expanded(
              child: Row(
                children: [
                  Sidebar(),
                  Expanded(child: CanvasArea()),
                ],
              ),
            ),
            ExecutionPanel(),
          ],
        ),
      ),
    );
  }
}
