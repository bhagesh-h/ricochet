import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:file_picker/file_picker.dart';
import 'package:bioflow/controllers/docker_search_controller.dart';
import 'controllers/pipeline_controller.dart';
import 'controllers/execution_controller.dart';
import 'controllers/docker_controller.dart';
import 'controllers/pipeline_tabs_controller.dart';
import 'views/pipeline_canvas.dart';
import 'views/tool_sidebar.dart';
import 'views/widgets/execution_panel.dart';
import 'views/widgets/docker_status_banner.dart';
import 'views/widgets/pipeline_tab_bar.dart';

void main() {
  // Initialize controllers before runApp
  WidgetsFlutterBinding.ensureInitialized();
  Get.put(PipelineController());
  Get.put(ExecutionController());
  Get.put(DockerSearchController());
  Get.put(DockerController());
  // PipelineTabsController must come AFTER PipelineController & ExecutionController
  Get.put(PipelineTabsController());

  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({Key? key}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    final ExecutionController execCtrl = Get.find();
    final DockerController dockerCtrl = Get.find();

    return GetMaterialApp(
      title: 'Pipeline Designer',
      theme: ThemeData(
        primarySwatch: Colors.blue,
        useMaterial3: true,
        colorScheme: ColorScheme.fromSeed(
          seedColor: const Color(0xFF6366F1),
          brightness: Brightness.light,
        ),
      ),
      home: Scaffold(
        backgroundColor: const Color(0xFFF7F8FA),
        appBar: AppBar(
          elevation: 0,
          backgroundColor: Colors.white,
          surfaceTintColor: Colors.transparent,
          title: Row(
            children: [
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  gradient: const LinearGradient(
                    colors: [Color(0xFF6366F1), Color(0xFF8B5CF6)],
                  ),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: const Icon(Icons.biotech, color: Colors.white, size: 20),
              ),
              const SizedBox(width: 12),
              const Text(
                'BioFlow',
                style: TextStyle(
                  fontWeight: FontWeight.w700,
                  color: Color(0xFF0F172A),
                  fontSize: 18,
                ),
              ),
            ],
          ),
          actions: [
            // Open Recent
            Container(
              margin: const EdgeInsets.only(right: 8),
              child: TextButton.icon(
                onPressed: () => Get.find<PipelineTabsController>().showOpenRecentDialog(),
                icon: const Icon(Icons.history, size: 18, color: Color(0xFF64748B)),
                label: const Text('Open Recent',
                    style: TextStyle(color: Color(0xFF475569), fontWeight: FontWeight.w600)),
                style: TextButton.styleFrom(
                    padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12)),
              ),
            ),
            // Import Pipeline button
            Container(
              margin: const EdgeInsets.only(right: 8),
              decoration: BoxDecoration(
                color: const Color(0xFFF1F5F9),
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: const Color(0xFFE2E8F0)),
              ),
              child: TextButton.icon(
                onPressed: () async {
                  final result = await FilePicker.platform.getDirectoryPath(
                    dialogTitle: 'Select Pipeline Folder',
                  );
                  if (result != null) {
                    Get.find<PipelineTabsController>().importPipeline(result);
                  }
                },
                icon: const Icon(Icons.folder_open, size: 18, color: Color(0xFF64748B)),
                label: const Text('Import',
                    style: TextStyle(color: Color(0xFF475569), fontWeight: FontWeight.w600)),
                style: TextButton.styleFrom(
                    padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12)),
              ),
            ),
            // Export button
            Container(
              margin: const EdgeInsets.only(right: 12),
              decoration: BoxDecoration(
                color: const Color(0xFFF1F5F9),
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: const Color(0xFFE2E8F0)),
              ),
              child: TextButton.icon(
                onPressed: () => Get.find<PipelineController>().exportPipelineAsDockerCompose(),
                icon: const Icon(Icons.download, size: 18, color: Color(0xFF64748B)),
                label: const Text(
                  'Export Docker',
                  style: TextStyle(
                    color: Color(0xFF475569),
                    fontWeight: FontWeight.w600,
                  ),
                ),
                style: TextButton.styleFrom(
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                ),
              ),
            ),
            Obx(() {
              final isDockerReady = dockerCtrl.isReady;
              return Tooltip(
                message: isDockerReady
                    ? 'Execute pipeline'
                    : 'Docker is not running. Start Docker Desktop to execute pipelines.',
                child: Container(
                  margin: const EdgeInsets.only(right: 12),
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      colors: isDockerReady
                          ? [const Color(0xFF10B981), const Color(0xFF059669)]
                          : [Colors.grey.shade400, Colors.grey.shade500],
                    ),
                    borderRadius: BorderRadius.circular(8),
                    boxShadow: isDockerReady
                        ? [
                            BoxShadow(
                              color: const Color(0xFF10B981).withOpacity(0.25),
                              blurRadius: 8,
                              offset: const Offset(0, 3),
                            ),
                          ]
                        : [],
                  ),
                  child: ElevatedButton.icon(
                    onPressed: isDockerReady ? execCtrl.runPipeline : null,
                    icon: const Icon(Icons.play_arrow, size: 18),
                    label: const Text('Execute'),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.transparent,
                      foregroundColor: Colors.white,
                      disabledBackgroundColor: Colors.transparent,
                      disabledForegroundColor: Colors.white70,
                      shadowColor: Colors.transparent,
                      padding: const EdgeInsets.symmetric(
                          horizontal: 20, vertical: 12),
                      textStyle: const TextStyle(fontWeight: FontWeight.w600),
                    ),
                  ),
                ),
              );
            }),
            Container(
              margin: const EdgeInsets.only(right: 20),
              decoration: BoxDecoration(
                color: const Color(0xFFF1F5F9),
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: const Color(0xFFE2E8F0)),
              ),
              child: IconButton(
                onPressed: () => Get.find<PipelineController>().clearAll(),
                icon: const Icon(Icons.refresh, color: Color(0xFF64748B)),
                tooltip: 'Reset Canvas',
              ),
            ),
          ],
        ),
        body: Stack(
          children: [
            Column(
              children: [
                // Docker status banner
                const DockerStatusBanner(),
                // Chrome-style Multi-Tab Bar
                const PipelineTabBar(),
                // Main content
                Expanded(
                  child: Row(
                    children: [
                      const ToolSidebar(),
                      Expanded(
                        child: const PipelineCanvas(),
                      ),
                    ],
                  ),
                ),
              ],
            ),
            // Execution Panel
            Obx(() {
              return AnimatedPositioned(
                duration: execCtrl.showPanel.value
                    ? const Duration(milliseconds: 300)
                    : const Duration(milliseconds: 200),
                curve: Curves.easeInOut,
                left: 0,
                right: 0,
                bottom: execCtrl.showPanel.value
                    ? 28
                    : -(execCtrl.panelHeight.value +
                        28), // 28 is status bar height
                height: execCtrl.panelHeight.value,
                child: const ExecutionPanel(),
              );
            }),

            // Status Bar
            Positioned(
              left: 0,
              right: 0,
              bottom: 0,
              height: 28,
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 12),
                decoration: const BoxDecoration(
                  color: Color(0xFF6366F1), // Primary color
                  border: Border(top: BorderSide(color: Color(0xFF4F46E5))),
                ),
                child: Row(
                  children: [
                    // Toggle Panel Button
                    InkWell(
                      onTap: execCtrl.togglePanel,
                      child: Obx(() => Container(
                            padding: const EdgeInsets.symmetric(
                                horizontal: 8, vertical: 4),
                            decoration: BoxDecoration(
                              color: execCtrl.showPanel.value
                                  ? Colors.white.withOpacity(0.2)
                                  : Colors.transparent,
                              borderRadius: BorderRadius.circular(4),
                            ),
                            child: Row(
                              children: [
                                Icon(
                                  execCtrl.showPanel.value
                                      ? Icons.keyboard_arrow_down
                                      : Icons.keyboard_arrow_up,
                                  size: 14,
                                  color: Colors.white,
                                ),
                                const SizedBox(width: 6),
                                const Text(
                                  'Terminal',
                                  style: TextStyle(
                                    color: Colors.white,
                                    fontSize: 12,
                                    fontWeight: FontWeight.w500,
                                  ),
                                ),
                              ],
                            ),
                          )),
                    ),
                    const VerticalDivider(
                        color: Colors.white24,
                        width: 24,
                        indent: 6,
                        endIndent: 6),
                    Obx(() {
                      if (execCtrl.isRunning.value) {
                        return const Row(
                          children: [
                            SizedBox(
                              width: 10,
                              height: 10,
                              child: CircularProgressIndicator(
                                strokeWidth: 2,
                                valueColor:
                                    AlwaysStoppedAnimation(Colors.white),
                              ),
                            ),
                            SizedBox(width: 8),
                            Text(
                              'Running Pipeline...',
                              style:
                                  TextStyle(color: Colors.white, fontSize: 11),
                            ),
                          ],
                        );
                      }
                      return const Text(
                        'Ready',
                        style: TextStyle(color: Colors.white70, fontSize: 11),
                      );
                    }),
                    const Spacer(),
                    const Text(
                      'BioFlow v1.0.0',
                      style: TextStyle(color: Colors.white54, fontSize: 11),
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
      debugShowCheckedModeBanner: false,
    );
  }
}
