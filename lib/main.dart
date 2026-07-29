import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:window_manager/window_manager.dart';
import 'package:Ricochet/controllers/docker_search_controller.dart';
import 'controllers/pipeline_controller.dart';
import 'controllers/execution_controller.dart';
import 'controllers/docker_controller.dart';
import 'controllers/pipeline_tabs_controller.dart';
import 'controllers/home_controller.dart';
import 'controllers/settings_controller.dart';
import 'controllers/system_stats_controller.dart';
import 'services/pipeline_tab_runtime_store.dart';
import 'views/home_screen.dart';
import 'views/settings_page.dart';
import 'views/pipeline_canvas.dart';
import 'views/tool_sidebar.dart';
import 'views/widgets/execution_panel.dart';
import 'views/widgets/docker_status_banner.dart';
import 'views/widgets/pipeline_tab_bar.dart';
import 'views/widgets/parallel_execution_badge.dart';

void main() async {
  // Initialize controllers before runApp
  WidgetsFlutterBinding.ensureInitialized();
  await windowManager.ensureInitialized();

  WindowOptions windowOptions = const WindowOptions(
    size: Size(1280, 720),
    minimumSize: Size(960, 540),
    center: true,
    backgroundColor: Colors.transparent,
    skipTaskbar: false,
    titleBarStyle: TitleBarStyle.hidden, // Hides native OS title bar
  );
  windowManager.waitUntilReadyToShow(windowOptions, () async {
    await windowManager.show();
    await windowManager.focus();
  });

  Get.put(PipelineController());
  Get.put(ExecutionController());
  Get.put(PipelineTabRuntimeStore());
  Get.put(DockerSearchController());
  Get.put(DockerController());
  // PipelineTabsController must come AFTER PipelineController & ExecutionController
  Get.put(PipelineTabsController());
  // HomeController manages home ↔ editor navigation
  Get.put(HomeController());
  Get.put(SettingsController());
  Get.put(SystemStatsController());

  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({Key? key}) : super(key: key);

  @override
  Widget build(BuildContext context) {
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
      // ── Root: animate between Home screen and the Editor ──────────────────
      home: Obx(() {
        final homeCtrl = Get.find<HomeController>();
        final view = homeCtrl.appView.value;
        return AnimatedSwitcher(
          duration: const Duration(milliseconds: 220),
          child: switch (view) {
            AppView.home => const HomeScreen(key: ValueKey('home')),
            AppView.settings => const SettingsPage(key: ValueKey('settings')),
            AppView.editor => const _EditorScaffold(key: ValueKey('editor')),
          },
        );
      }),
      debugShowCheckedModeBanner: false,
    );
  }
}

// ─── Editor (full pipeline workspace) ────────────────────────────────────────

class _EditorScaffold extends StatelessWidget {
  const _EditorScaffold({Key? key}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    final ExecutionController execCtrl = Get.find();

    return Scaffold(
        backgroundColor: const Color(0xFFF7F8FA),
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
                    children: const [
                      ToolSidebar(),
                      Expanded(child: PipelineCanvas()),
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
                    : -(execCtrl.panelHeight.value + 28),
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
                  color: Color(0xFF6366F1),
                  border:
                      Border(top: BorderSide(color: Color(0xFF4F46E5))),
                ),
                child: Row(
                  children: [
                    // Toggle Panel Button
                    InkWell(
                      onTap: execCtrl.togglePanel,
                      child: Obx(
                        () => Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 8,
                            vertical: 4,
                          ),
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
                        ),
                      ),
                    ),
                    const VerticalDivider(
                      color: Colors.white24,
                      width: 24,
                      indent: 6,
                      endIndent: 6,
                    ),
                    Obx(() {
                      if (execCtrl.isRunning.value) {
                        final parallelActive = Get.isRegistered<SettingsController>() &&
                            Get.find<SettingsController>().isParallelRunActive.value;
                        return Row(
                          children: [
                            const SizedBox(
                              width: 10,
                              height: 10,
                              child: CircularProgressIndicator(
                                strokeWidth: 2,
                                valueColor: AlwaysStoppedAnimation(
                                    Colors.white),
                              ),
                            ),
                            const SizedBox(width: 8),
                            Text(
                              parallelActive
                                  ? 'Running pipeline (parallel)...'
                                  : 'Running Pipeline...',
                              style: const TextStyle(
                                  color: Colors.white, fontSize: 11),
                            ),
                            if (parallelActive) ...[
                              const SizedBox(width: 10),
                              const ParallelExecutionBadge(compact: true),
                            ],
                          ],
                        );
                      }
                      return const Text(
                        'Ready',
                        style:
                            TextStyle(color: Colors.white70, fontSize: 11),
                      );
                    }),
                    const Spacer(),
                    const Text(
                      'Ricochet v1.0.0',
                      style:
                          TextStyle(color: Colors.white54, fontSize: 11),
                    ),
                  ],
                ),
              ),
            ),
          ],
        ));
  }
}
