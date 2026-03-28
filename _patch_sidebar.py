#!/usr/bin/env python3
"""Patch parameter_sidebar.dart: replace pairedFile block with multiFile generic N-file implementation."""

FILEPATH = 'lib/views/widgets/parameter_sidebar.dart'

with open(FILEPATH, 'r', encoding='utf-8') as f:
    content = f.read()

START = '  // ── Paired FASTQ input (R1 + R2) ───────────────────────────────────────────'
END   = '  // ── Smart Command Editor ────────────────────────────────────────────────────'

si = content.find(START)
ei = content.find(END)
assert si != -1, 'start marker not found'
assert ei != -1, 'end marker not found'
print(f'Block: lines {content[:si].count(chr(10))+1}–{content[:ei].count(chr(10))+1}')

NEW_BLOCK = r"""  // ── Generic multi-file input (1‥N files, any format) ──────────────────────

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
                    filePath?.split('/').last ?? 'Tap to select file...',
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

  void _pickFileForSlot(BlockParameter param, int? slotIndex) {
    final sampleFiles = [
      'reads_1.fastq.gz', 'reads_2.fastq.gz',
      'reference.fa', 'genome.fasta',
      'alignments.bam', 'variants.vcf',
      'transcriptome.gtf', 'results.csv',
    ];
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
                  'Sample Files',
                  style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold,
                      color: Colors.grey[500], letterSpacing: 1.1),
                ),
              ),
            ),
            ...sampleFiles.map((file) => ListTile(
              leading: const Icon(Icons.description_outlined, color: Color(0xFF94A3B8), size: 20),
              title: Text(file, style: const TextStyle(color: Color(0xFF334155))),
              onTap: () { applyFile(file); Get.back(); },
            )),
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
            slotFileNames.add(f.split('/').last);
          }
        }
      } else {
        final fileParam = upstream.parameters
            .where((p) => p.type == ParameterType.file && p.value != null)
            .firstOrNull;
        slotNodeNames.add(upstream.title);
        slotFileNames.add(fileParam?.value?.toString().split('/').last);
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

"""  # NEW_BLOCK ends – the subsequent "// ── Smart Command Editor" marker follows

content = content[:si] + NEW_BLOCK + content[ei:]

with open(FILEPATH, 'w', encoding='utf-8') as f:
    f.write(content)

print('Done. File written successfully.')
