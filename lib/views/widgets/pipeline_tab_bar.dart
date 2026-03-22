import 'package:flutter/material.dart';
import 'package:get/get.dart';
import '../../controllers/pipeline_tabs_controller.dart';
import '../../models/pipeline_file.dart';

class PipelineTabBar extends StatelessWidget {
  const PipelineTabBar({Key? key}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    final tabsCtrl = Get.find<PipelineTabsController>();

    return Container(
      height: 48,
      decoration: const BoxDecoration(
        color: Color(0xFF1E293B), // Dark slate suitable for a technical app
      ),
      child: Row(
        children: [
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
            icon: const Icon(Icons.add, color: Colors.white),
            tooltip: 'New Pipeline',
            onPressed: () => tabsCtrl.createNewTab(),
          ),
          const SizedBox(width: 8),
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
