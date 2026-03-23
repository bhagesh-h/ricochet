// views/widgets/parameter_sidebar.dart
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:get/get.dart';
import 'package:file_picker/file_picker.dart';
import 'package:Ricochet/models/pipeline_node.dart';
import '../../controllers/pipeline_controller.dart';
import '../../controllers/docker_search_controller.dart';
import '../../models/docker_image.dart';

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
    }
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
                      'Your upstream file is available as \$INPUT_FILE inside the container.\n'
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

            // ── Clickable variable chips ───────────────────────────────────
            Wrap(
              spacing: 6,
              runSpacing: 4,
              children: [
                _varChip(
                  r'$INPUT_FILE',
                  'Upstream file — the output of the connected node',
                  Icons.input_rounded,
                  const Color(0xFF8B5CF6),
                  () => insertVar(r'$INPUT_FILE'),
                ),
                _varChip(
                  '/outputs/',
                  'Output directory — results are saved here',
                  Icons.output_rounded,
                  const Color(0xFF10B981),
                  () => insertVar('/outputs/'),
                ),
                _varChip(
                  '/inputs/',
                  'Input files directory — all mounted input files',
                  Icons.folder_open_rounded,
                  const Color(0xFF3B82F6),
                  () => insertVar('/inputs/'),
                ),
              ],
            ),
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
    if (img.contains('bwa')) return r'bwa mem ref.fa $INPUT_FILE > /outputs/aligned.sam';
    if (img.contains('samtools')) return r'samtools view -bS $INPUT_FILE -o /outputs/out.bam';
    if (img.contains('trimmomatic')) {
      return r'trimmomatic SE $INPUT_FILE /outputs/trimmed.fq SLIDINGWINDOW:4:20 MINLEN:36';
    }
    if (img.contains('multiqc')) return r'multiqc /inputs/ -o /outputs/';
    if (img.contains('star')) {
      return r'STAR --runThreadN 8 --readFilesIn $INPUT_FILE --outFileNamePrefix /outputs/';
    }
    if (img.contains('gatk')) {
      return r'gatk HaplotypeCaller -I $INPUT_FILE -O /outputs/variants.vcf';
    }
    if (img.contains('kallisto')) {
      return r'kallisto quant -i index.idx -o /outputs/ $INPUT_FILE';
    }
    if (img.contains('hisat')) {
      return r'hisat2 -x genome -U $INPUT_FILE -S /outputs/aligned.sam';
    }
    if (img.contains('picard')) {
      return r'picard MarkDuplicates I=$INPUT_FILE O=/outputs/dedup.bam M=/outputs/dup_metrics.txt';
    }
    if (img.contains('bowtie')) {
      return r'bowtie2 -x genome -U $INPUT_FILE -S /outputs/aligned.sam';
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
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        child: Container(
          width: 400,
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

class _AddParameterFormState extends State<AddParameterForm> {
  final _labelController = TextEditingController();
  final _keyController = TextEditingController();
  ParameterType _selectedType = ParameterType.text;
  
  BlockParameter? _selectedDefaultParam;
  List<BlockParameter> _missingDefaults = [];

  @override
  void initState() {
    super.initState();
    final ctrl = Get.find<PipelineController>();
    final activeNode = ctrl.nodes.firstWhereOrNull((n) => n.id == widget.nodeId);
    if (activeNode != null) {
      _missingDefaults = ctrl.getMissingDefaultParameters(activeNode);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        if (_missingDefaults.isNotEmpty) ...[
          DropdownButtonFormField<BlockParameter?>(
            value: _selectedDefaultParam,
            isExpanded: true,
            decoration: const InputDecoration(labelText: 'Restore Default Parameter'),
            items: [
              const DropdownMenuItem(value: null, child: Text("Create Custom Parameter...")),
              ..._missingDefaults.map((p) => DropdownMenuItem(value: p, child: Text(p.label)))
            ],
            onChanged: (v) {
              setState(() {
                _selectedDefaultParam = v;
                if (v != null) {
                  _labelController.text = v.label;
                  _keyController.text = v.key;
                  _selectedType = v.type;
                } else {
                  _labelController.clear();
                  _keyController.clear();
                  _selectedType = ParameterType.text;
                }
              });
            },
          ),
          const SizedBox(height: 16),
          const Divider(),
          const SizedBox(height: 8),
        ],
        TextFormField(controller: _labelController, decoration: const InputDecoration(labelText: 'Label')),
        TextFormField(controller: _keyController, decoration: const InputDecoration(labelText: 'Key')),
        DropdownButtonFormField<ParameterType>(
          value: _selectedType,
          items: ParameterType.values.map((t) => DropdownMenuItem(value: t, child: Text(t.name))).toList(),
          onChanged: (v) => setState(() => _selectedType = v!),
        ),
        const SizedBox(height: 20),
        ElevatedButton(
          onPressed: () {
            if (_keyController.text.trim().isEmpty) return;
            Get.find<PipelineController>().addNodeParameter(widget.nodeId, BlockParameter(
              key: _keyController.text.trim(), 
              label: _labelController.text.trim().isEmpty ? _keyController.text.trim() : _labelController.text.trim(), 
              type: _selectedType,
            ));
            Get.back();
          },
          style: ElevatedButton.styleFrom(
            backgroundColor: widget.primaryColor,
            foregroundColor: Colors.white,
          ),
          child: const Text('Add Parameter'),
        ),
      ],
    );
  }
}
