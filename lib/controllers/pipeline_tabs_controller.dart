import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:path/path.dart' as p;
import 'package:uuid/uuid.dart';
import '../models/pipeline_file.dart';
import '../models/pipeline_template.dart';
import '../services/workspace_service.dart';
import 'pipeline_controller.dart';
import 'execution_controller.dart';
import 'home_controller.dart';

class PipelineTabsController extends GetxController {
  final WorkspaceService _workspaceService = WorkspaceService();
  var tabs = <PipelineFile>[].obs;
  var activeTabId = Rxn<String>();
  Timer? _autoSaveTimer;

  PipelineFile? get currentPipeline {
    if (activeTabId.value == null) return null;
    return tabs.firstWhereOrNull((t) => t.id == activeTabId.value);
  }

  @override
  void onInit() {
    super.onInit();

    // Bind execution logs to tab changes
    Future.microtask(() {
      try {
        final executionController = Get.find<ExecutionController>();
        ever(activeTabId, (id) => executionController.clearLogsAndSwitchToActiveTab(id));
      } catch (e) {
        print("ExecutionController not yet initialized: $e");
      }
    });

    // Fix #12: Restore previous session or create a blank tab
    _restoreLastSession();
  }

  /// Restore tabs from disk on startup. If no saved pipelines found, start blank.
  Future<void> _restoreLastSession() async {
    try {
      final recent = await _workspaceService.listRecentPipelines();
      if (recent.isEmpty) {
        await createNewTab();
        return;
      }

      for (final item in recent) {
        final id = const Uuid().v4();
        final tab = PipelineFile(
          id: id,
          name: item['name']!,
          folderPath: item['folderPath']!,
        );
        tabs.add(tab);
      }

      // Switch to the first tab (most recent)
      if (tabs.isNotEmpty) {
        switchTab(tabs.first.id);
      }
    } catch (e) {
      print('Session restore failed, starting fresh: $e');
      await createNewTab();
    }
  }

  Future<void> createNewTab() async {
    final id = const Uuid().v4();
    final folderName = 'Untitled Pipeline ${tabs.length + 1}';
    final folderPath = await _workspaceService.createPipelineFolder(folderName);
    
    final newTab = PipelineFile(
      id: id,
      name: folderName,
      folderPath: folderPath,
    );
    tabs.add(newTab);
    switchTab(id);
  }

  void triggerAutoSave() {
    _autoSaveTimer?.cancel();
    _autoSaveTimer = Timer(const Duration(seconds: 2), _saveActiveTabToDisk);
  }

  void markActiveTabDirty() {
    final tab = currentPipeline;
    if (tab != null && !tab.hasUnsavedChanges) {
      tab.hasUnsavedChanges = true;
      tabs.refresh();
    }
  }

  Future<void> _saveActiveTabToDisk() async {
    final tab = currentPipeline;
    if (tab == null) return;
    
    // Sync latest canvas state into PipelineFile
    final pipelineCtrl = Get.find<PipelineController>();
    pipelineCtrl.saveStateToPipelineFile(tab);
    
    final jsonData = jsonEncode(tab.toJson());
    final filePath = p.join(tab.folderPath, 'pipeline.json');
    await File(filePath).writeAsString(jsonData);
    
    tab.hasUnsavedChanges = false;
    tabs.refresh();
    print('💾 Auto-saved: ${tab.name}');
  }

  Future<void> _loadTabFromDisk(PipelineFile tab) async {
    final filePath = p.join(tab.folderPath, 'pipeline.json');
    final file = File(filePath);
    if (!await file.exists()) return;

    try {
      final jsonStr = await file.readAsString();
      final data = jsonDecode(jsonStr) as Map<String, dynamic>;
      final loaded = PipelineFile.fromJson(data);
      tab.nodes = loaded.nodes;
      tab.connections = loaded.connections;
    } catch (e) {
      print('⚠️ Failed to load pipeline.json: $e');
    }
  }

  void switchTab(String id) {
    if (activeTabId.value == id) return;
    
    // Auto-save the current tab's state before switching (if active)
    final prevTab = currentPipeline;
    if (prevTab != null) {
      Get.find<PipelineController>().saveStateToPipelineFile(prevTab);
      _saveActiveTabToDisk(); // immediate save before switching
      _autoSaveTimer?.cancel();
    }
    
    activeTabId.value = id;
    
    // Load the new tab's data
    final tab = currentPipeline;
    if (tab != null) {
      _loadTabFromDisk(tab).then((_) {
        Get.find<PipelineController>().loadPipelineData(tab);
      });
    }
  }

  void closeTab(String id) {
    final tab = tabs.firstWhereOrNull((t) => t.id == id);
    if (tab == null) return;

    void _doClose() {
      tabs.removeWhere((t) => t.id == id);
      if (tabs.isEmpty) {
        activeTabId.value = null;
        Get.find<PipelineController>().clearAll();
        Get.find<HomeController>().goHome();
      } else if (activeTabId.value == id) {
        switchTab(tabs.last.id);
      }
    }

    Get.dialog(
      AlertDialog(
        title: const Text('Close Session'),
        content: Text('Do you want to save "${tab.name}" for later? \n\nIf you discard it, this pipeline session will be permanently deleted and will not appear when you restart.'),
        actions: [
          TextButton(
            onPressed: () => Get.back(),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: Colors.red.shade600),
            onPressed: () async {
              Get.back(); // close dialog
              final dir = Directory(tab.folderPath);
              if (await dir.exists()) {
                await dir.delete(recursive: true); // physically delete so it won't show on restart
              }
              _doClose();
            },
            child: const Text('Discard', style: TextStyle(color: Colors.white)),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFF6366F1)),
            onPressed: () {
              Get.back();
              // Auto-save logic already persists it, but we can enforce it:
              if (activeTabId.value == id) {
                _saveActiveTabToDisk();
              }
              _doClose();
            },
            child: const Text('Save & Close', style: TextStyle(color: Colors.white)),
          ),
        ],
      ),
    );
  }

  Future<void> renameTab(String id, String newName) async {
    final tab = tabs.firstWhereOrNull((t) => t.id == id);
    if (tab == null || tab.name == newName || newName.trim().isEmpty) return;

    final parentDir = Directory(tab.folderPath).parent;
    final sanitizedName = newName.replaceAll(RegExp(r'[^a-zA-Z0-9_\s-]'), '_').trim();
    final newFolderPath = p.join(parentDir.path, sanitizedName);
    
    if (await Directory(newFolderPath).exists()) {
      Get.snackbar('Name Conflict', 'A pipeline folder with that name already exists.',
          snackPosition: SnackPosition.BOTTOM);
      return; 
    }

    try {
      await Directory(tab.folderPath).rename(newFolderPath);
      tab.name = sanitizedName;
      tab.folderPath = newFolderPath; // mutable now
      tabs.refresh();
    } catch (e) {
      print('Failed to rename directory: $e');
    }
  }

  /// Open an existing pipeline folder as a new tab.
  Future<void> importPipeline(String folderPath) async {
    final result = await _workspaceService.importPipelineFromFolder(folderPath);
    if (result == null) {
      Get.snackbar(
        'No Pipeline Found',
        'This folder does not contain a pipeline.json file.',
        snackPosition: SnackPosition.BOTTOM,
      );
      return;
    }
    
    final folderName = p.basename(folderPath);
    final id = const Uuid().v4();
    final newTab = PipelineFile(
      id: id,
      name: folderName,
      folderPath: folderPath,
    );
    tabs.add(newTab);
    switchTab(id);
  }

  /// Show recent pipelines from disk and allow user to open one.
  Future<void> showOpenRecentDialog() async {
    final recent = await _workspaceService.listRecentPipelines();
    if (recent.isEmpty) {
      Get.snackbar('No Recent Pipelines', 'No saved pipelines found in your workspace.',
          snackPosition: SnackPosition.BOTTOM);
      return;
    }

    Get.dialog(
      AlertDialog(
        title: const Text('Open Recent Pipeline'),
        content: SizedBox(
          width: 400,
          child: ListView.separated(
            shrinkWrap: true,
            itemCount: recent.length,
            separatorBuilder: (_, __) => const Divider(),
            itemBuilder: (context, idx) {
              final item = recent[idx];
              return ListTile(
                leading: const Icon(Icons.folder_open, color: Color(0xFF6366F1)),
                title: Text(item['name']!),
                subtitle: Text(item['folderPath']!, maxLines: 1, overflow: TextOverflow.ellipsis,
                    style: const TextStyle(fontSize: 11)),
                onTap: () {
                  Get.back();
                  importPipeline(item['folderPath']!);
                },
              );
            },
          ),
        ),
        actions: [
          TextButton(onPressed: () => Get.back(), child: const Text('Cancel')),
        ],
      ),
    );
  }

  // ── Template ────────────────────────────────────────────────────────────────

  /// Create a new tab pre-populated with [template]'s nodes and connections.
  ///
  /// We deliberately DO NOT call [switchTab] here because [switchTab] schedules
  /// `_loadTabFromDisk(tab).then(loadPipelineData)` asynchronously.  Since the
  /// new tab has no pipeline.json yet, that `.then` callback would fire on the
  /// next event-loop tick with an empty node list — wiping whatever
  /// [loadTemplate] already drew on the canvas (the classic Future race).
  ///
  /// Instead we replicate only the parts of [switchTab] that are safe:
  ///  1. Save & cancel auto-save for the previous tab.
  ///  2. Set activeTabId directly (no disk-load scheduled).
  ///  3. Call loadTemplate to populate the canvas synchronously.
  ///  4. Immediately flush to disk so the tab has a pipeline.json from birth.
  Future<void> openFromTemplate(PipelineTemplate template) async {
    final id = const Uuid().v4();
    final folderPath =
        await _workspaceService.createPipelineFolder(template.name);
    final newTab = PipelineFile(
      id: id,
      name: p.basename(folderPath),
      folderPath: folderPath,
    );
    tabs.add(newTab);

    // ── Save previous tab before leaving it ──────────────────────────────────
    final prevTab = currentPipeline;
    if (prevTab != null) {
      Get.find<PipelineController>().saveStateToPipelineFile(prevTab);
      _autoSaveTimer?.cancel();
      // Fire-and-forget — we don't await so we don't block the UI.
      _saveActiveTabToDisk();
    }

    // ── Activate the new tab WITHOUT scheduling a disk-load ──────────────────
    activeTabId.value = id;

    // ── Populate the canvas synchronously from the template ──────────────────
    final pipelineCtrl = Get.find<PipelineController>();
    pipelineCtrl.loadTemplate(template, tabId: id);

    // ── Persist to disk immediately so it survives tab-switches / restarts ───
    pipelineCtrl.saveStateToPipelineFile(newTab);
    final jsonData = jsonEncode(newTab.toJson());
    final filePath = p.join(newTab.folderPath, 'pipeline.json');
    await File(filePath).writeAsString(jsonData);
    newTab.hasUnsavedChanges = false;
    tabs.refresh();
  }
}
