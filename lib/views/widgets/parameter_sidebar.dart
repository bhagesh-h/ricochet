// views/widgets/parameter_sidebar.dart
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:get/get.dart';
import 'package:file_picker/file_picker.dart';
import 'package:path/path.dart' as p;
import 'package:Ricochet/models/pipeline_node.dart';
import '../../controllers/pipeline_controller.dart';
import '../../controllers/docker_search_controller.dart';
import '../../services/workspace_service.dart';
import '../../models/docker_image.dart';
import 'dart:io';
import 'dart:convert';

class ParameterSidebar extends StatefulWidget {
  final PipelineNode node;
  const ParameterSidebar({Key? key, required this.node}) : super(key: key);

  @override
  State<ParameterSidebar> createState() => _ParameterSidebarState();
}

class _ParameterSidebarState extends State<ParameterSidebar> {
  late PipelineController controller;
  double _width = 350.0;

  // One TextEditingController per param key, so variable-chip insertion works.
  final Map<String, TextEditingController> _textControllers = {};

  TextEditingController _ctrlFor(String key, String? initial) {
    return _textControllers.putIfAbsent(
        key, () => TextEditingController(text: initial ?? ''));
  }

  @override
  void initState() {
    super.initState();
    controller = Get.find<PipelineController>();
  }

  @override
  void dispose() {
    for (final c in _textControllers.values) {
      c.dispose();
    }
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        MouseRegion(
          cursor: SystemMouseCursors.resizeLeftRight,
          child: GestureDetector(
            onHorizontalDragUpdate: (details) {
              setState(() {
                _width = (_width - details.delta.dx).clamp(280.0, 700.0);
              });
            },
            child: Container(
              width: 6,
              color: Colors.transparent,
            ),
          ),
        ),
        SizedBox(
          width: _width,
          child: Container(
            decoration: const BoxDecoration(
        color: Colors.white,
        border: Border(left: BorderSide(color: Color(0xFFE2E8F0))),
        boxShadow: [
          BoxShadow(
            color: Color(0x08000000),
            blurRadius: 12,
            offset: Offset(-4, 0),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Header
          Container(
            padding: const EdgeInsets.all(20),
            decoration: BoxDecoration(
              color: widget.node.backgroundColor,
              border: const Border(bottom: BorderSide(color: Color(0xFFE2E8F0))),
            ),
            child: Row(
              children: [
                Container(
                  width: 40,
                  height: 40,
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(color: widget.node.primaryColor.withOpacity(0.2)),
                  ),
                  child: Icon(widget.node.icon, color: widget.node.primaryColor, size: 20),
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        widget.node.title,
                        style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w700, color: Color(0xFF0F172A)),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        widget.node.description,
                        style: const TextStyle(fontSize: 14, color: Color(0xFF64748B)),
                      ),
                    ],
                  ),
                ),
                IconButton(
                  onPressed: () {
                    controller.deleteNode(widget.node.id);
                    controller.selectNode(null);
                  },
                  icon: const Icon(Icons.delete_outline, color: Color(0xFFEF4444), size: 20),
                  tooltip: 'Delete block',
                ),
                IconButton(
                  onPressed: () => controller.selectNode(null),
                  icon: const Icon(Icons.close, color: Color(0xFF64748B), size: 20),
                ),
              ],
            ),
          ),
          // Parameters section
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Padding(
                  padding: const EdgeInsets.all(20),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      const Expanded(
                        child: Text(
                          'Parameters',
                          style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600, color: Color(0xFF0F172A)),
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                      if (widget.node.category != BlockCategory.input && widget.node.category != BlockCategory.output)
                        ElevatedButton.icon(
                          onPressed: () => _showAddParameterDialog(context),
                          icon: const Icon(Icons.add, size: 16),
                          label: const Text('Add'),
                          style: ElevatedButton.styleFrom(
                            backgroundColor: widget.node.primaryColor,
                            foregroundColor: Colors.white,
                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(6)),
                          ),
                        ),
                    ],
                  ),
                ),
                Expanded(
                  child: ListView.builder(
                    padding: const EdgeInsets.symmetric(horizontal: 20),
                    itemCount: widget.node.parameters.length + 1,
                    itemBuilder: (context, index) {
                      if (index == widget.node.parameters.length) {
                        return _buildExportSettings();
                      }
                      final param = widget.node.parameters[index];
                      return _buildParameterItem(param, index);
                    },
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    ),
  ),
],
);
}

  Widget _buildParameterItem(BlockParameter param, int index) {
    final canDelete = widget.node.category != BlockCategory.input && widget.node.category != BlockCategory.output;

    return Container(
      margin: const EdgeInsets.only(bottom: 16),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: const Color(0xFFF8FAFC),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: const Color(0xFFE2E8F0)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                param.label,
                style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w600, color: Color(0xFF374151)),
              ),
              if (canDelete)
                IconButton(
                  onPressed: () => controller.removeNodeParameter(widget.node.id, index),
                  icon: const Icon(Icons.delete_outline, size: 16),
                  style: IconButton.styleFrom(foregroundColor: const Color(0xFFEF4444)),
                ),
            ],
          ),
          const SizedBox(height: 12),
          _buildParameterInput(param),
        ],
      ),
    );
  }

  Widget _buildParameterInput(BlockParameter param) {
    switch (param.type) {
      case ParameterType.text:
        if (param.key == 'tag' && widget.node.dockerImage != null) {
          return _buildTagPicker(param);
        }
        if (param.key == 'command' || param.key == 'docker_command') {
          return _buildCommandInput(param);
        }
        return TextFormField(
          initialValue: param.value?.toString() ?? '',
          decoration: _inputDecoration(param.placeholder ?? 'Enter ${param.label.toLowerCase()}'),
          onChanged: (value) => controller.updateNodeParameter(widget.node.id, param.key, value),
        );

      case ParameterType.numeric:
        return TextFormField(
          initialValue: param.value?.toString() ?? '',
          keyboardType: TextInputType.number,
          inputFormatters: [FilteringTextInputFormatter.digitsOnly],
          decoration: _inputDecoration('Enter number'),
          onChanged: (value) {
            final numValue = int.tryParse(value) ?? 0;
            controller.updateNodeParameter(widget.node.id, param.key, numValue);
          },
        );

      case ParameterType.dropdown:
        return DropdownButtonFormField<String>(
          value: param.value?.toString(),
          decoration: _inputDecoration('Select ${param.label.toLowerCase()}'),
          items: param.options?.map((option) {
            return DropdownMenuItem<String>(value: option, child: Text(option));
          }).toList(),
          onChanged: (value) => controller.updateNodeParameter(widget.node.id, param.key, value),
        );

      case ParameterType.toggle:
        return Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(param.value == true ? 'Enabled' : 'Disabled', style: const TextStyle(fontSize: 14, color: Color(0xFF64748B))),
            Switch(
              value: param.value == true,
              activeColor: widget.node.primaryColor,
              onChanged: (value) => controller.updateNodeParameter(widget.node.id, param.key, value),
            ),
          ],
        );

      case ParameterType.file:
        return GestureDetector(
          onTap: () => _showFileSelector(param),
          child: Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              border: Border.all(color: const Color(0xFFD1D5DB)),
              borderRadius: BorderRadius.circular(6),
              color: Colors.white,
            ),
            child: Row(
              children: [
                Icon(Icons.folder_outlined, color: widget.node.primaryColor, size: 20),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    param.value?.toString() ?? 'Select file...',
                    style: TextStyle(fontSize: 14, color: param.value != null ? const Color(0xFF374151) : const Color(0xFF9CA3AF)),
                  ),
                ),
                const Icon(Icons.keyboard_arrow_down, color: Color(0xFF9CA3AF), size: 20),
              ],
            ),
          ),
        );

      case ParameterType.multiFile:
        return _buildMultiFileInput(param);
    }
  }

  // ── Generic multi-file input (1‥N files, any format) ──────────────────────

  /// Coerce stored value (null | List | legacy-String) into List<String>.
  List<String> _filesFromParam(BlockParameter param) {
    if (param.value == null) return [];
    if (param.value is List) {
      return (param.value as List)
          .map((e) => e.toString())
          .where((s) => s.isNotEmpty)
          .toList();
    }
    final s = param.value.toString();
    return s.isNotEmpty ? [s] : [];
  }

  Color _slotColor(int index) {
    const colors = [
      Color(0xFF3B82F6), Color(0xFF8B5CF6), Color(0xFF10B981),
      Color(0xFFF59E0B), Color(0xFFEF4444), Color(0xFF06B6D4),
    ];
    return colors[index % colors.length];
  }

  String _slotLabel(int index, int totalCount) {
    if (totalCount == 2 && index == 0) return 'File 1 · R1 / Forward';
    if (totalCount == 2 && index == 1) return 'File 2 · R2 / Reverse';
    return 'File ${index + 1}';
  }

  Widget _buildMultiFileInput(BlockParameter param) {
    final files = _filesFromParam(param);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        if (files.isEmpty)
          _multiFileSlot(
            index: 0, filePath: null, totalCount: 0,
            color: widget.node.primaryColor,
            onTap: () => _pickFileForSlot(param, null),
            onRemove: null,
          )
        else
          ...files.asMap().entries.map((e) => Padding(
            padding: const EdgeInsets.only(bottom: 8),
            child: _multiFileSlot(
              index: e.key, filePath: e.value, totalCount: files.length,
              color: _slotColor(e.key),
              onTap: () => _pickFileForSlot(param, e.key),
              onRemove: () {
                final updated = List<String>.from(files)..removeAt(e.key);
                controller.updateNodeParameter(widget.node.id, param.key, updated);
              },
            ),
          )).toList(),
        const SizedBox(height: 8),
        GestureDetector(
          onTap: () => _pickFileForSlot(param, null),
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 9),
            decoration: BoxDecoration(
              border: Border.all(color: widget.node.primaryColor.withOpacity(0.35)),
              borderRadius: BorderRadius.circular(8),
              color: widget.node.primaryColor.withOpacity(0.04),
            ),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(Icons.add_rounded, size: 15, color: widget.node.primaryColor),
                const SizedBox(width: 6),
                Text(
                  files.isEmpty ? 'Select File' : 'Add Another File',
                  style: TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w600,
                    color: widget.node.primaryColor,
                  ),
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }

  Widget _multiFileSlot({
    required int index,
    required String? filePath,
    required int totalCount,
    required Color color,
    required VoidCallback onTap,
    required VoidCallback? onRemove,
  }) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
        decoration: BoxDecoration(
          border: Border.all(
            color: filePath != null ? color.withOpacity(0.5) : const Color(0xFFD1D5DB),
          ),
          borderRadius: BorderRadius.circular(8),
          color: filePath != null ? color.withOpacity(0.04) : Colors.white,
        ),
        child: Row(
          children: [
            Container(
              width: 30, height: 30,
              decoration: BoxDecoration(
                color: color.withOpacity(0.12),
                borderRadius: BorderRadius.circular(6),
              ),
              child: Icon(
                filePath != null ? Icons.description_rounded : Icons.add_rounded,
                color: color, size: 15,
              ),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    _slotLabel(index, totalCount),
                    style: TextStyle(fontSize: 11, fontWeight: FontWeight.w600, color: color),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    (filePath != null ? p.basename(filePath) : null) ?? 'Tap to select file...',
                    style: TextStyle(
                      fontSize: 12,
                      color: filePath != null ? const Color(0xFF374151) : const Color(0xFF9CA3AF),
                    ),
                    overflow: TextOverflow.ellipsis,
                  ),
                ],
              ),
            ),
            if (onRemove != null)
              Tooltip(
                message: 'Remove file',
                child: InkWell(
                  onTap: onRemove,
                  borderRadius: BorderRadius.circular(12),
                  child: const Padding(
                    padding: EdgeInsets.all(4),
                    child: Icon(Icons.close_rounded, size: 15, color: Color(0xFF94A3B8)),
                  ),
                ),
              )
            else
              Icon(Icons.keyboard_arrow_down_rounded, color: color.withOpacity(0.4), size: 18),
          ],
        ),
      ),
    );
  }

  Future<List<String>> _getHistoricalFiles() async {
    final workspaceService = WorkspaceService();
    final recentPipelines = await workspaceService.listRecentPipelines();
    final usedFiles = <String>{};

    for (final p in recentPipelines) {
      final jsonPath = p['folderPath']! + Platform.pathSeparator + 'pipeline.json';
      final file = File(jsonPath);
      if (await file.exists()) {
        try {
          final content = await file.readAsString();
          final data = jsonDecode(content);
          final nodes = data['nodes'] as List?;
          if (nodes != null) {
            for (final node in nodes) {
              final params = node['parameters'] as List?;
              if (params != null) {
                for (final param in params) {
                  if (param['type'] == 'multiFile' && param['value'] is List) {
                    for (final v in param['value']) {
                      final pathStr = v.toString();
                      if (pathStr.isNotEmpty) usedFiles.add(pathStr);
                    }
                  } else if (param['key'] == 'file_path') {
                    final pathStr = param['value']?.toString() ?? '';
                    if (pathStr.isNotEmpty) usedFiles.add(pathStr);
                  }
                }
              }
            }
          }
        } catch (_) {}
      }
    }

    final existingFiles = <String>[];
    for (final p in usedFiles) {
      if (await File(p).exists()) {
        existingFiles.add(p);
      }
    }
    return existingFiles;
  }

  void _pickFileForSlot(BlockParameter param, int? slotIndex) {
    final current = _filesFromParam(param);

    void applyFile(String path) {
      final updated = List<String>.from(current);
      if (slotIndex == null || slotIndex >= updated.length) {
        updated.add(path);
      } else {
        updated[slotIndex] = path;
      }
      controller.updateNodeParameter(widget.node.id, param.key, updated);
    }

    Get.bottomSheet(
      Container(
        padding: const EdgeInsets.symmetric(vertical: 20),
        decoration: const BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
          boxShadow: [BoxShadow(color: Colors.black12, blurRadius: 10, spreadRadius: 2)],
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 40, height: 4,
              margin: const EdgeInsets.only(bottom: 20),
              decoration: BoxDecoration(color: Colors.grey[300], borderRadius: BorderRadius.circular(2)),
            ),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 20),
              child: Row(
                children: [
                  Icon(Icons.folder_open_rounded, color: widget.node.primaryColor),
                  const SizedBox(width: 12),
                  Text(
                    slotIndex == null ? 'Add Input File' : 'Replace File ${slotIndex + 1}',
                    style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: Color(0xFF1E293B)),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 20),
            ListTile(
              leading: Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: widget.node.primaryColor.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Icon(Icons.computer_rounded, color: widget.node.primaryColor, size: 20),
              ),
              title: const Text('Browse Local Disk', style: TextStyle(fontWeight: FontWeight.w600)),
              subtitle: const Text('Select any input file from your computer'),
              trailing: const Icon(Icons.chevron_right_rounded),
              onTap: () async {
                Get.back();
                try {
                  final result = await FilePicker.platform.pickFiles(
                    type: FileType.any, allowMultiple: false);
                  if (result != null && result.files.single.path != null) {
                    applyFile(result.files.single.path!);
                  }
                } catch (e) {
                  Get.snackbar('Error', 'Could not open file picker: $e',
                      snackPosition: SnackPosition.BOTTOM);
                }
              },
            ),
            const Divider(height: 32, indent: 20, endIndent: 20),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
              child: Align(
                alignment: Alignment.centerLeft,
                child: Text(
                  'Previously Used Files',
                  style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold,
                      color: Colors.grey[500], letterSpacing: 1.1),
                ),
              ),
            ),
            FutureBuilder<List<String>>(
              future: _getHistoricalFiles(),
              builder: (context, snapshot) {
                if (snapshot.connectionState == ConnectionState.waiting) {
                  return const Padding(
                    padding: EdgeInsets.all(20),
                    child: Center(child: CircularProgressIndicator(strokeWidth: 2)),
                  );
                }
                
                final files = snapshot.data ?? [];
                if (files.isEmpty) {
                  return Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
                    child: Text('No historical files found.', style: TextStyle(color: Colors.grey[500], fontStyle: FontStyle.italic)),
                  );
                }

                return ConstrainedBox(
                  constraints: BoxConstraints(maxHeight: MediaQuery.of(context).size.height * 0.4),
                  child: ListView.builder(
                    shrinkWrap: true,
                    physics: const BouncingScrollPhysics(),
                    itemCount: files.length,
                    itemBuilder: (context, index) {
                      final filePath = files[index];
                      String name = filePath.split('/').last;
                      if (Platform.isWindows) {
                         name = name.split('\\').last;
                      }
                      return ListTile(
                        leading: const Icon(Icons.description_outlined, color: Color(0xFF94A3B8), size: 20),
                        title: Text(name, style: const TextStyle(color: Color(0xFF334155))),
                        subtitle: Text(filePath, style: const TextStyle(fontSize: 11, color: Colors.black45)),
                        onTap: () { applyFile(filePath); Get.back(); },
                      );
                    },
                  ),
                );
              },
            ),
            const SizedBox(height: 20),
          ],
        ),
      ),
    );
  }

  // ── Dynamic input-variable chips  (connection-aware) ────────────────────────
  //
  // Scans all incoming connections to this node, flattens every file each
  // upstream node contributes, then generates the correct shell variable names:
  //   • 1 total slot  → $INPUT_FILE
  //   • N total slots → $INPUT_FILE_1, $INPUT_FILE_2, …
  // Tooltips show the upstream node name AND the file that variable resolves to.
  Wrap _buildDynamicInputChips(void Function(String) insertVar) {
    final incomingConns = controller.connections
        .where((c) => c.toNodeId == widget.node.id)
        .toList();

    final List<String> slotNodeNames = [];
    final List<String?> slotFileNames = [];

    for (final conn in incomingConns) {
      final upstream =
          controller.nodes.firstWhereOrNull((n) => n.id == conn.fromNodeId);
      if (upstream == null) continue;

      final multiParam = upstream.parameters
          .where((p) => p.type == ParameterType.multiFile)
          .firstOrNull;

      if (multiParam != null) {
        final files = _filesFromParam(multiParam);
        if (files.isEmpty) {
          slotNodeNames.add(upstream.title);
          slotFileNames.add(null);
        } else {
          for (final f in files) {
            slotNodeNames.add(upstream.title);
            slotFileNames.add(p.basename(f));
          }
        }
      } else {
        final fileParam = upstream.parameters
            .where((p) => p.type == ParameterType.file && p.value != null)
            .firstOrNull;
        slotNodeNames.add(upstream.title);
        slotFileNames.add(fileParam?.value != null ? p.basename(fileParam!.value.toString()) : null);
      }
    }

    const chipColors = [
      Color(0xFF8B5CF6), Color(0xFF3B82F6), Color(0xFF10B981),
      Color(0xFFF59E0B), Color(0xFFEF4444), Color(0xFF06B6D4),
    ];
    const chipIcons = [
      Icons.looks_one_rounded, Icons.looks_two_rounded, Icons.looks_3_rounded,
      Icons.looks_4_rounded, Icons.looks_5_rounded, Icons.looks_6_rounded,
    ];

    final List<Widget> inputChips = [];

    if (slotNodeNames.isEmpty) {
      inputChips.add(_varChip(
        r'$INPUT_FILE', 'Output of the upstream connected node',
        Icons.input_rounded, const Color(0xFF8B5CF6),
        () => insertVar(r'$INPUT_FILE'),
      ));
    } else if (slotNodeNames.length == 1) {
      final fn = slotFileNames[0];
      final tip = fn != null
          ? 'From "${slotNodeNames[0]}" → $fn'
          : 'From "${slotNodeNames[0]}" (no file selected yet)';
      inputChips.add(_varChip(
        r'$INPUT_FILE', tip,
        Icons.input_rounded, const Color(0xFF8B5CF6),
        () => insertVar(r'$INPUT_FILE'),
      ));
    } else {
      for (int i = 0; i < slotNodeNames.length; i++) {
        final varName = '\$INPUT_FILE_${i + 1}';
        final fn = slotFileNames[i];
        final tip = fn != null
            ? 'File ${i + 1} — from "${slotNodeNames[i]}" → $fn'
            : 'File ${i + 1} — from "${slotNodeNames[i]}"';
        final color = chipColors[i % chipColors.length];
        final icon = i < chipIcons.length ? chipIcons[i] : Icons.insert_drive_file_rounded;
        inputChips.add(_varChip(varName, tip, icon, color, () => insertVar(varName)));
      }
      inputChips.add(_varChip(
        r'$INPUT_FILE',
        r'Alias for $INPUT_FILE_1 — first file (backward compat)',
        Icons.input_rounded, const Color(0xFF94A3B8),
        () => insertVar(r'$INPUT_FILE'),
      ));
    }

    return Wrap(
      spacing: 6,
      runSpacing: 4,
      children: [
        ...inputChips,
        _varChip('/outputs/', 'Output directory — write all results here',
            Icons.output_rounded, const Color(0xFF10B981), () => insertVar('/outputs/')),
        _varChip('/inputs/', 'Mounted input directory — all raw files',
            Icons.folder_open_rounded, const Color(0xFF64748B), () => insertVar('/inputs/')),
      ],
        );
  }

  // ── Smart Command Editor ────────────────────────────────────────────────────
  Widget _buildCommandInput(BlockParameter param) {
    final tCtrl = _ctrlFor(param.key, param.value?.toString());
    final example = _exampleCommandFor(widget.node.dockerImage ?? '');

    void insertVar(String variable) {
      final sel = tCtrl.selection;
      final text = tCtrl.text;
      final start = sel.isValid && sel.start >= 0 ? sel.start : text.length;
      final end = sel.isValid && sel.end >= 0 ? sel.end : text.length;
      final newText = text.replaceRange(start, end, variable);
      tCtrl.value = TextEditingValue(
        text: newText,
        selection: TextSelection.collapsed(offset: start + variable.length),
      );
      controller.updateNodeParameter(widget.node.id, param.key, newText);
    }

    return StatefulBuilder(
      builder: (context, localSetState) {
        final nowEmpty = tCtrl.text.trim().isEmpty;
        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // ── Info banner (only when command is empty) ──────────────────
            if (nowEmpty) ...[
              Container(
                padding: const EdgeInsets.all(12),
                margin: const EdgeInsets.only(bottom: 10),
                decoration: BoxDecoration(
                  color: const Color(0xFFEFF6FF),
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: const Color(0xFF93C5FD)),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Row(
                      children: [
                        Icon(Icons.lightbulb_outline_rounded, size: 14, color: Color(0xFF3B82F6)),
                        SizedBox(width: 6),
                        Text(
                          'How commands work',
                          style: TextStyle(fontSize: 12, fontWeight: FontWeight.w700, color: Color(0xFF1D4ED8)),
                        ),
                      ],
                    ),
                    const SizedBox(height: 6),
                    const Text(
                      'Upstream files are injected as shell variables:\n'
                      '• \$INPUT_FILE — single upstream file (or alias for \$INPUT_FILE_1)\n'
                      '• \$INPUT_FILE_1, \$INPUT_FILE_2, … — multi-file / multi-port inputs\n'
                      'Write all results to /outputs/ — Ricochet maps this to your workspace.',
                      style: TextStyle(fontSize: 11.5, color: Color(0xFF1E40AF), height: 1.5),
                    ),
                    if (example.isNotEmpty) ...[
                      const SizedBox(height: 10),
                      GestureDetector(
                        onTap: () {
                          tCtrl.text = example;
                          controller.updateNodeParameter(widget.node.id, param.key, example);
                          localSetState(() {});
                        },
                        child: Container(
                          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 7),
                          decoration: BoxDecoration(
                            color: const Color(0xFF1D4ED8),
                            borderRadius: BorderRadius.circular(6),
                          ),
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              const Icon(Icons.play_circle_outline_rounded, color: Colors.white, size: 14),
                              const SizedBox(width: 6),
                              Flexible(
                                child: Text(
                                  example,
                                  style: const TextStyle(
                                    fontSize: 11,
                                    color: Colors.white,
                                    fontFamily: 'monospace',
                                  ),
                                  overflow: TextOverflow.ellipsis,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                    ],
                  ],
                ),
              ),
            ],

            // ── Multi-line monospace command field ────────────────────────
            TextField(
              controller: tCtrl,
              minLines: 2,
              maxLines: 6,
              style: const TextStyle(
                fontFamily: 'monospace',
                fontSize: 13,
                color: Color(0xFF0F172A),
              ),
              decoration: InputDecoration(
                hintText: example.isNotEmpty
                    ? example
                    : r'e.g. mytool -i $INPUT_FILE -o /outputs/result.txt',
                hintStyle: const TextStyle(
                  color: Color(0xFFBDBDBD),
                  fontSize: 12,
                  fontFamily: 'monospace',
                ),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(6),
                  borderSide: const BorderSide(color: Color(0xFFD1D5DB)),
                ),
                enabledBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(6),
                  borderSide: const BorderSide(color: Color(0xFFD1D5DB)),
                ),
                focusedBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(6),
                  borderSide: BorderSide(color: widget.node.primaryColor, width: 1.5),
                ),
                contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                filled: true,
                fillColor: Colors.white,
              ),
              onChanged: (value) {
                controller.updateNodeParameter(widget.node.id, param.key, value);
                if (nowEmpty != value.trim().isEmpty) localSetState(() {});
              },
            ),
            const SizedBox(height: 8),

            // ── Dynamic variable chips (connection-aware) ──────────────────
            _buildDynamicInputChips(insertVar),
          ],
        );
      },
    );
  }

  Widget _varChip(
      String label, String tooltip, IconData icon, Color color, VoidCallback onTap) {
    return Tooltip(
      message: tooltip,
      waitDuration: const Duration(milliseconds: 300),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(20),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
          decoration: BoxDecoration(
            color: color.withOpacity(0.08),
            borderRadius: BorderRadius.circular(20),
            border: Border.all(color: color.withOpacity(0.35)),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(icon, size: 11, color: color),
              const SizedBox(width: 4),
              Text(
                label,
                style: TextStyle(
                  fontSize: 11,
                  color: color,
                  fontFamily: 'monospace',
                  fontWeight: FontWeight.w600,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  /// Returns a tool-specific example command string based on the Docker image name.
  String _exampleCommandFor(String dockerImage) {
    final img = dockerImage.toLowerCase();
    if (img.contains('fastqc')) return r'fastqc $INPUT_FILE --outdir /outputs/';
    if (img.contains('fastp')) return r'fastp -i $INPUT_FILE -o /outputs/out.fq.gz';
    if (img.contains('bwa')) return r'bwa mem /ref/genome.fa $INPUT_FILE_1 $INPUT_FILE_2 > /outputs/aligned.sam';
    if (img.contains('samtools')) return r'samtools view -bS $INPUT_FILE -o /outputs/out.bam';
    if (img.contains('trimmomatic')) {
      return r'trimmomatic PE $INPUT_FILE_1 $INPUT_FILE_2 /outputs/trimmed_1.fq.gz /outputs/trimmed_2.fq.gz SLIDINGWINDOW:4:20 MINLEN:36';
    }
    if (img.contains('multiqc')) return r'multiqc /inputs/ -o /outputs/';
    if (img.contains('star')) {
      return r'STAR --runThreadN 8 --readFilesIn $INPUT_FILE_1 $INPUT_FILE_2 --outFileNamePrefix /outputs/';
    }
    if (img.contains('gatk')) {
      return r'gatk HaplotypeCaller -I $INPUT_FILE -O /outputs/variants.vcf';
    }
    if (img.contains('kallisto')) {
      return r'kallisto quant -i index.idx -o /outputs/ $INPUT_FILE';
    }
    if (img.contains('hisat')) {
      return r'hisat2 -x genome -1 $INPUT_FILE_1 -2 $INPUT_FILE_2 -S /outputs/aligned.sam';
    }
    if (img.contains('picard')) {
      return r'picard MarkDuplicates I=$INPUT_FILE O=/outputs/dedup.bam M=/outputs/dup_metrics.txt';
    }
    if (img.contains('bowtie')) {
      return r'bowtie2 -x genome -1 $INPUT_FILE_1 -2 $INPUT_FILE_2 -S /outputs/aligned.sam';
    }
    if (img.contains('subread') || img.contains('featurecounts')) {
      return r'featureCounts -a genes.gtf -o /outputs/counts.txt $INPUT_FILE';
    }
    return '';
  }

  // ── Tag Picker ──────────────────────────────────────────────────────────────
  Widget _buildTagPicker(BlockParameter param) {
    final searchCtrl = Get.find<DockerSearchController>();
    final currentValue = param.value?.toString() ?? 'latest';

    return FutureBuilder<TagFetchResult>(
      future: searchCtrl.getImageTags(widget.node.dockerImage!, all: true),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting && !snapshot.hasData) {
          return Padding(
            padding: const EdgeInsets.symmetric(vertical: 8),
            child: Row(
              children: [
                const SizedBox(width: 14, height: 14, child: CircularProgressIndicator(strokeWidth: 2)),
                const SizedBox(width: 12),
                Text('Fetching tags...', style: TextStyle(color: Colors.grey[600], fontSize: 13)),
              ],
            ),
          );
        }

        final result = snapshot.data;
        if (result?.status == TagFetchStatus.failed) {
          return Text('Failed to load tags', style: TextStyle(color: Colors.red[400], fontSize: 12));
        }

        if (result?.status == TagFetchStatus.empty) {
          return Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'No tags available for this image. You can manually specify a tag.',
                style: TextStyle(color: Colors.amber[800], fontSize: 11, fontWeight: FontWeight.w500),
              ),
              const SizedBox(height: 8),
              TextFormField(
                initialValue: currentValue,
                decoration: _inputDecoration('e.g. latest, v1.0'),
                onChanged: (value) => controller.updateNodeParameter(widget.node.id, param.key, value),
              ),
            ],
          );
        }

        final List<String> tags = result?.tags.map((t) => t.name).toList() ?? [];
        
        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Container(
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(6),
                border: Border.all(color: const Color(0xFFD1D5DB)),
              ),
              child: DropdownButtonHideUnderline(
                child: DropdownButton<String>(
                  value: tags.contains(currentValue) ? currentValue : null,
                  hint: Text(currentValue, style: const TextStyle(fontSize: 14)),
                  isExpanded: true,
                  padding: const EdgeInsets.symmetric(horizontal: 12),
                  icon: const Icon(Icons.arrow_drop_down, color: Color(0xFF64748B)),
                  items: [
                    ...tags.map((tag) => DropdownMenuItem(
                      value: tag, 
                      child: Text(tag, style: const TextStyle(fontSize: 14))
                    )),
                    if (!tags.contains(currentValue))
                      DropdownMenuItem(
                        value: currentValue, 
                        child: Text(currentValue, style: const TextStyle(fontSize: 14, color: Colors.blue))
                      ),
                  ],
                  onChanged: (value) {
                    if (value != null) {
                      controller.updateNodeParameter(widget.node.id, param.key, value);
                    }
                  },
                ),
              ),
            ),
            const SizedBox(height: 4),
            Row(
              children: [
                Icon(
                  param.isAuto ? Icons.bolt : Icons.person_outline,
                  size: 12,
                  color: param.isAuto ? Colors.amber[700] : Colors.grey[600],
                ),
                const SizedBox(width: 4),
                Text(
                  param.isAuto ? 'Auto-selected' : 'Manual override',
                  style: TextStyle(
                    fontSize: 11,
                    fontWeight: FontWeight.w500,
                    color: param.isAuto ? Colors.amber[800] : Colors.grey[600],
                  ),
                ),
              ],
            ),
          ],
        );
      },
    );
  }

  Widget _buildExportSettings() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const SizedBox(height: 24),
        const Text('Export Settings', style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600, color: Color(0xFF0F172A))),
        const SizedBox(height: 16),
        Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: const Color(0xFFF8FAFC),
            borderRadius: BorderRadius.circular(8),
            border: Border.all(color: const Color(0xFFE2E8F0)),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text('Output File Name (Optional)', style: TextStyle(fontSize: 14, fontWeight: FontWeight.w600, color: Color(0xFF374151))),
              const SizedBox(height: 8),
              TextFormField(
                initialValue: widget.node.outputFileName ?? '',
                decoration: _inputDecoration('e.g., results.csv'),
                onChanged: (value) {
                  setState(() => widget.node.outputFileName = value.isEmpty ? null : value);
                },
              ),
              const SizedBox(height: 16),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  const Text('Is Aggregator Node', style: TextStyle(fontSize: 14, fontWeight: FontWeight.w600, color: Color(0xFF374151))),
                  Switch(
                    value: widget.node.isAggregator,
                    activeColor: widget.node.primaryColor,
                    onChanged: (value) => setState(() => widget.node.isAggregator = value),
                  ),
                ],
              ),
            ],
          ),
        ),
        const SizedBox(height: 24),
      ],
    );
  }

  InputDecoration _inputDecoration(String hintText) {
    return InputDecoration(
      hintText: hintText,
      hintStyle: const TextStyle(color: Color(0xFF9CA3AF), fontSize: 14),
      border: OutlineInputBorder(borderRadius: BorderRadius.circular(6), borderSide: const BorderSide(color: Color(0xFFD1D5DB))),
      enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(6), borderSide: const BorderSide(color: Color(0xFFD1D5DB))),
      focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(6), borderSide: BorderSide(color: widget.node.primaryColor)),
      contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      filled: true,
      fillColor: Colors.white,
    );
  }

  void _showAddParameterDialog(BuildContext context) {
    Get.dialog(
      Dialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        child: Container(
          width: 480,
          padding: const EdgeInsets.all(24),
          child: AddParameterForm(nodeId: widget.node.id, primaryColor: widget.node.primaryColor),
        ),
      ),
    );
  }

  void _showFileSelector(BlockParameter param) async {
    final sampleFiles = ['sample.fasta', 'ref.fa', 'reads.fastq', 'variants.vcf'];
    
    Get.bottomSheet(
      Container(
        padding: const EdgeInsets.symmetric(vertical: 20),
        decoration: const BoxDecoration(
          color: Colors.white, 
          borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
          boxShadow: [BoxShadow(color: Colors.black12, blurRadius: 10, spreadRadius: 2)],
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 40,
              height: 4,
              margin: const EdgeInsets.only(bottom: 20),
              decoration: BoxDecoration(color: Colors.grey[300], borderRadius: BorderRadius.circular(2)),
            ),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 20),
              child: Row(
                children: [
                  Icon(Icons.folder_open_rounded, color: widget.node.primaryColor),
                  const SizedBox(width: 12),
                  Text('Select ${param.label}', style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: Color(0xFF1E293B))),
                ],
              ),
            ),
            const SizedBox(height: 20),
            ListTile(
              leading: Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(color: widget.node.primaryColor.withOpacity(0.1), borderRadius: BorderRadius.circular(8)),
                child: Icon(Icons.computer_rounded, color: widget.node.primaryColor, size: 20),
              ),
              title: const Text('Browse Local Disk', style: TextStyle(fontWeight: FontWeight.w600)),
              subtitle: const Text('Select a real file from your computer'),
              trailing: const Icon(Icons.chevron_right_rounded),
              onTap: () async {
                Get.back();
                try {
                  FilePickerResult? result = await FilePicker.platform.pickFiles(
                    type: FileType.any,
                    allowMultiple: false,
                  );

                  if (result != null && result.files.single.path != null) {
                    controller.updateNodeParameter(widget.node.id, param.key, result.files.single.path!);
                  }
                } catch (e) {
                  Get.snackbar('Error', 'Could not open file picker: $e', snackPosition: SnackPosition.BOTTOM);
                }
              },
            ),
            const Divider(height: 32, indent: 20, endIndent: 20),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
              child: Align(
                alignment: Alignment.centerLeft,
                child: Text('Sample Bioinformatics Data', style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: Colors.grey[500], letterSpacing: 1.1)),
              ),
            ),
            ...sampleFiles.map((file) => ListTile(
              leading: const Icon(Icons.description_outlined, color: Color(0xFF94A3B8), size: 20),
              title: Text(file, style: const TextStyle(color: Color(0xFF334155))),
              onTap: () {
                controller.updateNodeParameter(widget.node.id, param.key, file);
                Get.back();
              },
            )),
            const SizedBox(height: 20),
          ],
        ),
      ),
    );
  }
}

class AddParameterForm extends StatefulWidget {
  final String nodeId;
  final Color primaryColor;
  const AddParameterForm({Key? key, required this.nodeId, required this.primaryColor}) : super(key: key);
  @override
  State<AddParameterForm> createState() => _AddParameterFormState();
}

class _AddParameterFormState extends State<AddParameterForm> with SingleTickerProviderStateMixin {
  final _labelController = TextEditingController();
  final _keyController = TextEditingController();
  ParameterType _selectedType = ParameterType.text;

  List<BlockParameter> _missingDefaults = [];
  TabController? _tabController;

  static const _typeIcons = <ParameterType, IconData>{
    ParameterType.text: Icons.text_fields_rounded,
    ParameterType.numeric: Icons.pin_rounded,
    ParameterType.dropdown: Icons.arrow_drop_down_circle_rounded,
    ParameterType.toggle: Icons.toggle_on_rounded,
    ParameterType.file: Icons.folder_rounded,
  };

  static const _typeColors = <ParameterType, Color>{
    ParameterType.text: Color(0xFF3B82F6),
    ParameterType.numeric: Color(0xFFF97316),
    ParameterType.dropdown: Color(0xFF8B5CF6),
    ParameterType.toggle: Color(0xFF10B981),
    ParameterType.file: Color(0xFF06B6D4),
  };

  @override
  void initState() {
    super.initState();
    final ctrl = Get.find<PipelineController>();
    final activeNode = ctrl.nodes.firstWhereOrNull((n) => n.id == widget.nodeId);
    if (activeNode != null) {
      _missingDefaults = ctrl.getMissingDefaultParameters(activeNode);
    }
    if (_missingDefaults.isNotEmpty) {
      _tabController = TabController(length: 2, vsync: this);
    }
  }

  @override
  void dispose() {
    _labelController.dispose();
    _keyController.dispose();
    _tabController?.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        // ── Header ──────────────────────────────────────────────
        Row(
          children: [
            Icon(Icons.tune_rounded, color: widget.primaryColor, size: 22),
            const SizedBox(width: 10),
            const Text(
              'Add Parameter',
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.w700, color: Color(0xFF0F172A)),
            ),
            const Spacer(),
            IconButton(
              icon: const Icon(Icons.close_rounded, size: 20, color: Color(0xFF64748B)),
              padding: EdgeInsets.zero,
              constraints: const BoxConstraints(),
              onPressed: () => Get.back(),
            ),
          ],
        ),
        // ── With missing defaults: tab switcher ─────────────────
        if (_missingDefaults.isNotEmpty) ...[
          const SizedBox(height: 18),
          Container(
            decoration: BoxDecoration(
              color: const Color(0xFFF1F5F9),
              borderRadius: BorderRadius.circular(10),
            ),
            padding: const EdgeInsets.all(3),
            child: TabBar(
              controller: _tabController,
              dividerColor: Colors.transparent,
              indicator: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(7),
                boxShadow: const [
                  BoxShadow(color: Color(0x18000000), blurRadius: 4, offset: Offset(0, 1)),
                ],
              ),
              indicatorSize: TabBarIndicatorSize.tab,
              labelColor: widget.primaryColor,
              unselectedLabelColor: const Color(0xFF64748B),
              labelStyle: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600),
              unselectedLabelStyle: const TextStyle(fontSize: 13, fontWeight: FontWeight.w500),
              tabs: [
                Tab(text: 'Restore Removed  (${_missingDefaults.length})'),
                const Tab(text: 'Custom Parameter'),
              ],
            ),
          ),
          const SizedBox(height: 16),
          SizedBox(
            height: 300,
            child: TabBarView(
              controller: _tabController,
              children: [_buildRestoreTab(), _buildCustomTab()],
            ),
          ),
        ] else ...[
          // ── No missing defaults: custom form only ──────────────
          const SizedBox(height: 16),
          _buildCustomTab(),
        ],
      ],
    );
  }

  // ── Restore tab: one card per missing default parameter ────────
  Widget _buildRestoreTab() {
    return ListView.separated(
      itemCount: _missingDefaults.length,
      separatorBuilder: (_, __) => const SizedBox(height: 8),
      itemBuilder: (context, i) {
        final param = _missingDefaults[i];
        final typeColor = _typeColors[param.type] ?? const Color(0xFF3B82F6);
        final typeIcon = _typeIcons[param.type] ?? Icons.text_fields_rounded;
        return Container(
          decoration: BoxDecoration(
            color: const Color(0xFFF8FAFC),
            borderRadius: BorderRadius.circular(10),
            border: Border.all(color: const Color(0xFFE2E8F0)),
          ),
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 11),
          child: Row(
            children: [
              Container(
                width: 36,
                height: 36,
                decoration: BoxDecoration(
                  color: typeColor.withOpacity(0.12),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Icon(typeIcon, color: typeColor, size: 18),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      param.label,
                      style: const TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.w600,
                        color: Color(0xFF1E293B),
                      ),
                    ),
                    const SizedBox(height: 3),
                    Row(
                      children: [
                        Text(
                          param.key,
                          style: const TextStyle(fontSize: 11, color: Color(0xFF94A3B8)),
                        ),
                        const SizedBox(width: 6),
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 1),
                          decoration: BoxDecoration(
                            color: typeColor.withOpacity(0.12),
                            borderRadius: BorderRadius.circular(4),
                          ),
                          child: Text(
                            param.type.name,
                            style: TextStyle(
                              fontSize: 10,
                              fontWeight: FontWeight.w700,
                              color: typeColor,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 10),
              ElevatedButton.icon(
                onPressed: () {
                  Get.find<PipelineController>().addNodeParameter(widget.nodeId, param);
                  Get.back();
                },
                style: ElevatedButton.styleFrom(
                  backgroundColor: typeColor,
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 15),
                  minimumSize: Size.zero,
                  tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                  textStyle: const TextStyle(fontSize: 12, fontWeight: FontWeight.w600),
                  elevation: 0,
                ),
                icon: const Icon(Icons.restore_rounded, size: 14),
                label: const Text('Restore'),
              ),
            ],
          ),
        );
      },
    );
  }

  // ── Custom tab: manual label / key / type form ─────────────────
  Widget _buildCustomTab() {
    return SingleChildScrollView(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          _styledField(controller: _labelController, label: 'Label', hint: 'e.g. Min Quality'),
          const SizedBox(height: 12),
          _styledField(controller: _keyController, label: 'Key', hint: 'e.g. min_quality'),
          const SizedBox(height: 12),
          DropdownButtonFormField<ParameterType>(
            value: _selectedType,
            decoration: InputDecoration(
              labelText: 'Type',
              labelStyle: const TextStyle(
                fontSize: 14,
                fontWeight: FontWeight.w500,
                color: Color(0xFF374151),
              ),
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(8),
                borderSide: const BorderSide(color: Color(0xFFD1D5DB)),
              ),
              enabledBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(8),
                borderSide: const BorderSide(color: Color(0xFFD1D5DB)),
              ),
              focusedBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(8),
                borderSide: BorderSide(color: widget.primaryColor),
              ),
              contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
              filled: true,
              fillColor: Colors.white,
            ),
            items: ParameterType.values
                .where((t) => t != ParameterType.multiFile)
                .map((t) => DropdownMenuItem(
                      value: t,
                      child: Row(
                        children: [
                          Icon(_typeIcons[t], size: 16, color: _typeColors[t]),
                          const SizedBox(width: 8),
                          Text(t.name, style: const TextStyle(fontSize: 14)),
                        ],
                      ),
                    ))
                .toList(),
            onChanged: (v) => setState(() => _selectedType = v!),
          ),
          const SizedBox(height: 20),
          ElevatedButton.icon(
            onPressed: () {
              if (_keyController.text.trim().isEmpty) return;
              Get.find<PipelineController>().addNodeParameter(
                widget.nodeId,
                BlockParameter(
                  key: _keyController.text.trim(),
                  label: _labelController.text.trim().isEmpty
                      ? _keyController.text.trim()
                      : _labelController.text.trim(),
                  type: _selectedType,
                ),
              );
              Get.back();
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: widget.primaryColor,
              foregroundColor: Colors.white,
              padding: const EdgeInsets.symmetric(vertical: 14),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
            ),
            icon: const Icon(Icons.add_rounded, size: 18),
            label: const Text('Add Parameter',
                style: TextStyle(fontSize: 14, fontWeight: FontWeight.w600)),
          ),
        ],
      ),
    );
  }

  TextFormField _styledField({
    required TextEditingController controller,
    required String label,
    required String hint,
  }) {
    return TextFormField(
      controller: controller,
      decoration: InputDecoration(
        labelText: label,
        hintText: hint,
        hintStyle: const TextStyle(color: Color(0xFF9CA3AF), fontSize: 14),
        labelStyle: const TextStyle(
          fontSize: 14,
          fontWeight: FontWeight.w500,
          color: Color(0xFF374151),
        ),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(8),
          borderSide: const BorderSide(color: Color(0xFFD1D5DB)),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(8),
          borderSide: const BorderSide(color: Color(0xFFD1D5DB)),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(8),
          borderSide: BorderSide(color: widget.primaryColor),
        ),
        contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
        filled: true,
        fillColor: Colors.white,
      ),
    );
  }
}
