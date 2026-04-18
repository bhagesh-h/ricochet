import 'package:get/get.dart';
import '../services/workspace_service.dart';
import 'pipeline_tabs_controller.dart';
import '../models/pipeline_template.dart';
import '../views/widgets/about_dialog.dart';

enum AppView { home, editor }

class HomeController extends GetxController {
  final _workspaceService = WorkspaceService();

  final appView = AppView.home.obs;
  final recentPipelines = <Map<String, String>>[].obs;
  final isLoadingRecent = true.obs;

  @override
  void onInit() {
    super.onInit();
    loadRecent();
  }

  @override
  void onReady() {
    super.onReady();
    Get.dialog(const ModernAboutDialog(), barrierDismissible: false);
  }

  Future<void> loadRecent() async {
    isLoadingRecent.value = true;
    recentPipelines.value = await _workspaceService.listRecentPipelines();
    isLoadingRecent.value = false;
  }

  /// Navigate back to the Home screen and refresh the Recent list.
  void goHome() {
    appView.value = AppView.home;
    loadRecent();
  }

  /// Navigate to the editor (no-op if already there).
  void openEditor() => appView.value = AppView.editor;

  /// Create a brand-new blank tab and open the editor.
  Future<void> openBlankPipeline() async {
    await Get.find<PipelineTabsController>().createNewTab();
    openEditor();
  }

  /// Open an existing pipeline from the recent list and switch to the editor.
  Future<void> openRecentPipeline(Map<String, String> item) async {
    await Get.find<PipelineTabsController>().importPipeline(item['folderPath']!);
    openEditor();
  }

  /// Load [template] as a new tab and switch to the editor.
  Future<void> openTemplate(PipelineTemplate template) async {
    await Get.find<PipelineTabsController>().openFromTemplate(template);
    openEditor();
  }
}
