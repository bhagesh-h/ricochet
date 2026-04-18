import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:file_picker/file_picker.dart';
import '../../controllers/pipeline_tabs_controller.dart';
import '../../controllers/pipeline_controller.dart';
import '../../controllers/execution_controller.dart';
import '../../controllers/docker_controller.dart';
import '../../controllers/home_controller.dart';
import '../../models/pipeline_file.dart';
import 'ricochet_logo.dart';

class PipelineTabBar extends StatelessWidget {
  const PipelineTabBar({Key? key}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    final tabsCtrl = Get.find<PipelineTabsController>();
    final execCtrl = Get.find<ExecutionController>();
    final dockerCtrl = Get.find<DockerController>();

    return Container(
      height: 48,
      decoration: const BoxDecoration(
        color: Color(0xFF1E293B), // Dark slate suitable for a technical app
      ),
      child: Row(
        children: [
          // Home / Logo Button
          InkWell(
            onTap: () => Get.find<HomeController>().goHome(),
            child: Tooltip(
              message: 'Back to Home',
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 16),
                alignment: Alignment.center,
                child: Row(
                  children: [
                    const RicochetLogo(height: 18),
                  ],
                ),
              ),
            ),
          ),
          const VerticalDivider(width: 1, color: Colors.white12, indent: 12, endIndent: 12),
          
          Expanded(
            child: Obx(
              () => ListView.builder(
                scrollDirection: Axis.horizontal,
                itemCount: tabsCtrl.tabs.length,
                itemBuilder: (context, index) {
                  final tab = tabsCtrl.tabs[index];
                  final isActive = tabsCtrl.activeTabId.value == tab.id;
                  
                  return _PipelineTabWidget(
                    tab: tab,
                    isActive: isActive,
                    onTap: () => tabsCtrl.switchTab(tab.id),
                    onClose: () => tabsCtrl.closeTab(tab.id),
                    onRename: (newName) => tabsCtrl.renameTab(tab.id, newName),
                  );
                },
              ),
            ),
          ),
          IconButton(
            icon: const Icon(Icons.add, color: Colors.white70, size: 20),
            tooltip: 'New Pipeline',
            splashRadius: 20,
            onPressed: () => tabsCtrl.createNewTab(),
          ),
          
          // Action Buttons Section
          const VerticalDivider(width: 1, color: Colors.white12, indent: 12, endIndent: 12),
          const SizedBox(width: 2),
          
          Obx(() {
            if (dockerCtrl.shouldShowAppleSiliconNotice) {
              return IconButton(
                icon: const Icon(Icons.info_outline, color: Color(0xFF3B82F6), size: 18),
                tooltip: 'Apple Silicon Info',
                splashRadius: 20,
                onPressed: () {
                  Get.dialog(
                    AlertDialog(
                      title: const Row(
                        children: [
                          Icon(Icons.info_outline, color: Color(0xFF3B82F6)),
                          SizedBox(width: 8),
                          Text('Apple Silicon Detected'),
                        ],
                      ),
                      content: Text(dockerCtrl.appleSiliconNotice),
                      actions: [
                        TextButton(
                          onPressed: () => Get.back(),
                          child: const Text('Close'),
                        ),
                      ],
                    ),
                  );
                },
              );
            }
            return const SizedBox.shrink();
          }),
          
          Tooltip(
            message: 'Open Recent Pipeline',
            child: IconButton(
              onPressed: () => tabsCtrl.showOpenRecentDialog(),
              icon: const Icon(Icons.history, color: Colors.white70, size: 18),
              splashRadius: 20,
            ),
          ),
          Tooltip(
            message: 'Import Pipeline',
            child: IconButton(
              onPressed: () async {
                final result = await FilePicker.platform.pickFiles(
                  dialogTitle: 'Select Pipeline Export (.zip, .env, or folder)',
                  type: FileType.custom,
                  allowedExtensions: ['zip', 'env', 'json'],
                );
                if (result != null && result.files.single.path != null) {
                  tabsCtrl.importPipeline(result.files.single.path!);
                }
              },
              icon: const Icon(Icons.folder_open, color: Colors.white70, size: 18),
              splashRadius: 20,
            ),
          ),
          Tooltip(
            message: 'Export Docker Compose',
            child: IconButton(
              onPressed: () => Get.find<PipelineController>().exportPipelineAsDockerCompose(),
              icon: const Icon(Icons.download, color: Colors.white70, size: 18),
              splashRadius: 20,
            ),
          ),
          const SizedBox(width: 8),
          Obx(() {
            final isDockerReady = dockerCtrl.isReady;
            return Tooltip(
              message: isDockerReady ? 'Execute pipeline' : 'Docker is not running. Start Docker Desktop to execute pipelines.',
              child: ElevatedButton.icon(
                onPressed: isDockerReady ? execCtrl.runPipeline : null,
                icon: const Icon(Icons.play_arrow, size: 16),
                label: const Text('Execute'),
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFF10B981),
                  foregroundColor: Colors.white,
                  disabledBackgroundColor: Colors.white.withOpacity(0.1),
                  disabledForegroundColor: Colors.white54,
                  padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 0),
                  minimumSize: const Size(0, 32),
                  elevation: 0,
                  textStyle: const TextStyle(fontWeight: FontWeight.w600, fontSize: 12),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(6)),
                ),
              ),
            );
          }),
          const SizedBox(width: 4),
          Tooltip(
            message: 'Reset Canvas',
            child: IconButton(
              onPressed: () => Get.find<PipelineController>().clearAll(),
              icon: const Icon(Icons.refresh, color: Colors.white54, size: 18),
              splashRadius: 20,
            ),
          ),
          const SizedBox(width: 4),
        ],
      ),
    );
  }
}

class _PipelineTabWidget extends StatefulWidget {
  final PipelineFile tab;
  final bool isActive;
  final VoidCallback onTap;
  final VoidCallback onClose;
  final Function(String) onRename;

  const _PipelineTabWidget({
    Key? key,
    required this.tab,
    required this.isActive,
    required this.onTap,
    required this.onClose,
    required this.onRename,
  }) : super(key: key);

  @override
  _PipelineTabWidgetState createState() => _PipelineTabWidgetState();
}

class _PipelineTabWidgetState extends State<_PipelineTabWidget> {
  bool _isHovering = false;

  void _showRenameDialog() {
    final controller = TextEditingController(text: widget.tab.name);
    
    Get.dialog(
      AlertDialog(
        title: const Text('Rename Pipeline'),
        content: TextField(
          controller: controller,
          decoration: const InputDecoration(
            hintText: 'Enter new pipeline name',
          ),
          autofocus: true,
          onSubmitted: (value) {
            widget.onRename(value);
            Get.back();
          },
        ),
        actions: [
          TextButton(
            onPressed: () => Get.back(),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () {
              widget.onRename(controller.text);
              Get.back();
            },
            child: const Text('Rename'),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    // Elegant indigo styles for the modern Ricochet architecture
    final bgColor = widget.isActive ? Colors.white : const Color(0xFF334155);
    final textColor = widget.isActive ? const Color(0xFF1E293B) : Colors.white70;

    return MouseRegion(
      onEnter: (_) => setState(() => _isHovering = true),
      onExit: (_) => setState(() => _isHovering = false),
      child: GestureDetector(
        onTap: widget.onTap,
        onDoubleTap: _showRenameDialog,
        onSecondaryTap: _showRenameDialog, // Right click
        child: Container(
          constraints: const BoxConstraints(minWidth: 120, maxWidth: 220),
          margin: const EdgeInsets.only(top: 8, right: 2, left: 2),
          padding: const EdgeInsets.only(left: 16, right: 8, top: 4, bottom: 4),
          decoration: BoxDecoration(
            color: _isHovering && !widget.isActive ? const Color(0xFF475569) : bgColor,
            borderRadius: const BorderRadius.vertical(top: Radius.circular(8)),
            boxShadow: widget.isActive 
              ? [const BoxShadow(color: Colors.black12, blurRadius: 4, offset: Offset(0, -2))]
              : [],
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Flexible(
                child: Text(
                  widget.tab.name,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    color: textColor,
                    fontWeight: widget.isActive ? FontWeight.bold : FontWeight.w500,
                    fontSize: 13,
                  ),
                ),
              ),
              const SizedBox(width: 4),
              if (widget.tab.hasUnsavedChanges)
                Container(
                  margin: const EdgeInsets.only(right: 6),
                  width: 8,
                  height: 8,
                  decoration: const BoxDecoration(
                    color: Colors.blueAccent,
                    shape: BoxShape.circle,
                  ),
                ),
              InkWell(
                onTap: widget.onClose,
                borderRadius: BorderRadius.circular(12),
                hoverColor: Colors.black12,
                child: Padding(
                  padding: const EdgeInsets.all(4.0),
                  child: Icon(
                    Icons.close,
                    size: 14,
                    color: widget.isActive ? Colors.black54 : Colors.white54,
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
