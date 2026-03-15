// views/widgets/parameter_sidebar.dart
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:get/get.dart';
import 'package:bioflow/models/pipeline_node.dart';
import '../../controllers/pipeline_controller.dart';

class ParameterSidebar extends StatefulWidget {
  final PipelineNode node;
  const ParameterSidebar({Key? key, required this.node}) : super(key: key);

  @override
  State<ParameterSidebar> createState() => _ParameterSidebarState();
}

class _ParameterSidebarState extends State<ParameterSidebar> {
  late PipelineController controller; // Declare controller here

  @override
  void initState() {
    super.initState();
    controller = Get.find<PipelineController>(); // Initialize controller
  }

  @override
  Widget build(BuildContext context) {
    final controller = Get.find<PipelineController>();

    return Container(
        width: 350,
        decoration: const BoxDecoration(
          color: Colors.white,
          border: Border(
            left: BorderSide(color: Color(0xFFE2E8F0)),
          ),
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
                border: Border(
                  bottom: BorderSide(color: const Color(0xFFE2E8F0)),
                ),
              ),
              child: Row(
                children: [
                  Container(
                    width: 40,
                    height: 40,
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(
                          color: widget.node.primaryColor.withOpacity(0.2)),
                    ),
                    child: Icon(
                      widget.node.icon,
                      color: widget.node.primaryColor,
                      size: 20,
                    ),
                  ),
                  const SizedBox(width: 16),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          widget.node.title,
                          style: const TextStyle(
                            fontSize: 18,
                            fontWeight: FontWeight.w700,
                            color: Color(0xFF0F172A),
                          ),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          widget.node.description,
                          style: const TextStyle(
                            fontSize: 14,
                            color: Color(0xFF64748B),
                          ),
                        ),
                      ],
                    ),
                  ),
                  IconButton(
                    onPressed: () {
                      controller.deleteNode(widget.node.id);
                      controller.selectNode(null);
                    },
                    icon: const Icon(
                      Icons.delete_outline,
                      color: Color(0xFFEF4444),
                      size: 20,
                    ),
                    tooltip: 'Delete block',
                    style: IconButton.styleFrom(
                      backgroundColor: Colors.white,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(6),
                      ),
                    ),
                  ),
                  const SizedBox(width: 8),
                  IconButton(
                    onPressed: () => controller.selectNode(null),
                    icon: const Icon(
                      Icons.close,
                      color: Color(0xFF64748B),
                      size: 20,
                    ),
                    style: IconButton.styleFrom(
                      backgroundColor: Colors.white,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(6),
                      ),
                    ),
                  ),
                ],
              ),
            ),
            // Parameters section
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Parameters header with add button
                  Padding(
                    padding: const EdgeInsets.all(20),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        const Text(
                          'Parameters',
                          style: TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.w600,
                            color: Color(0xFF0F172A),
                          ),
                        ),
                        if (widget.node.category != BlockCategory.input &&
                            widget.node.category != BlockCategory.output)
                          ElevatedButton.icon(
                            onPressed: () => _showAddParameterDialog(context),
                            icon: const Icon(Icons.add, size: 16),
                            label: const Text('Add'),
                            style: ElevatedButton.styleFrom(
                              backgroundColor: widget.node.primaryColor,
                              foregroundColor: Colors.white,
                              padding: const EdgeInsets.symmetric(
                                  horizontal: 12, vertical: 8),
                              textStyle: const TextStyle(
                                  fontSize: 12, fontWeight: FontWeight.w600),
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(6),
                              ),
                            ),
                          ),
                      ],
                    ),
                  ),
                  // Parameters list
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
        ));
  }

  Widget _buildParameterItem(BlockParameter param, int index) {
    final controller = Get.find<PipelineController>();
    final canDelete = widget.node.category != BlockCategory.input &&
        widget.node.category != BlockCategory.output;

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
                style: const TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.w600,
                  color: Color(0xFF374151),
                ),
              ),
              if (canDelete)
                IconButton(
                  onPressed: () =>
                      controller.removeNodeParameter(widget.node.id, index),
                  icon: const Icon(Icons.delete_outline, size: 16),
                  style: IconButton.styleFrom(
                    foregroundColor: const Color(0xFFEF4444),
                    backgroundColor: Colors.white,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(4),
                    ),
                    minimumSize: const Size(32, 32),
                  ),
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
    final controller = Get.find<PipelineController>();

    switch (param.type) {
      case ParameterType.text:
        return TextFormField(
          initialValue: param.value?.toString() ?? '',
          decoration: _inputDecoration(
              param.placeholder ?? 'Enter ${param.label.toLowerCase()}'),
          onChanged: (value) =>
              controller.updateNodeParameter(widget.node.id, param.key, value),
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
            return DropdownMenuItem<String>(
              value: option,
              child: Text(option),
            );
          }).toList(),
          onChanged: (value) =>
              controller.updateNodeParameter(widget.node.id, param.key, value),
        );

      case ParameterType.toggle:
        return Container(
          padding: const EdgeInsets.symmetric(vertical: 8),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                param.value == true ? 'Enabled' : 'Disabled',
                style: const TextStyle(
                  fontSize: 14,
                  color: Color(0xFF64748B),
                ),
              ),
              Switch(
                value: param.value == true,
                activeColor: widget.node.primaryColor,
                onChanged: (value) => controller.updateNodeParameter(
                    widget.node.id, param.key, value),
              ),
            ],
          ),
        );

      case ParameterType.file:
        return GestureDetector(
          onTap: () => _showFileSelector(param),
          child: Container(
            width: double.infinity,
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              border: Border.all(color: const Color(0xFFD1D5DB)),
              borderRadius: BorderRadius.circular(6),
              color: Colors.white,
            ),
            child: Row(
              children: [
                Icon(
                  Icons.folder_outlined,
                  color: widget.node.primaryColor,
                  size: 20,
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    param.value?.toString() ?? 'Select file...',
                    style: TextStyle(
                      fontSize: 14,
                      color: param.value != null
                          ? const Color(0xFF374151)
                          : const Color(0xFF9CA3AF),
                    ),
                  ),
                ),
                const Icon(
                  Icons.keyboard_arrow_down,
                  color: Color(0xFF9CA3AF),
                  size: 20,
                ),
              ],
            ),
          ),
        );

      default:
        return const SizedBox();
    }
  }

  Widget _buildExportSettings() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const SizedBox(height: 24),
        const Text(
          'Export Settings',
          style: TextStyle(
            fontSize: 16,
            fontWeight: FontWeight.w600,
            color: Color(0xFF0F172A),
          ),
        ),
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
              const Text(
                'Output File Name (Optional)',
                style: TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.w600,
                  color: Color(0xFF374151),
                ),
              ),
              const SizedBox(height: 8),
              TextFormField(
                initialValue: widget.node.outputFileName ?? '',
                decoration: _inputDecoration('e.g., results.csv, output.fastq'),
                onChanged: (value) {
                  setState(() {
                    widget.node.outputFileName = value.isEmpty ? null : value;
                  });
                },
              ),
              const SizedBox(height: 16),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  const Text(
                    'Is Aggregator Node',
                    style: TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.w600,
                      color: Color(0xFF374151),
                    ),
                  ),
                  Switch(
                    value: widget.node.isAggregator,
                    activeColor: widget.node.primaryColor,
                    onChanged: (value) {
                      setState(() {
                        widget.node.isAggregator = value;
                      });
                    },
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
      hintStyle: const TextStyle(
        color: Color(0xFF9CA3AF),
        fontSize: 14,
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
        borderSide: BorderSide(color: widget.node.primaryColor),
      ),
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
          child: AddParameterForm(
            nodeId: widget.node.id,
            primaryColor: widget.node.primaryColor,
          ),
        ),
      ),
    );
  }

  void _showFileSelector(BlockParameter param) {
    final sampleFiles = [
      'sample_data.fasta',
      'genome_reference.fa',
      'reads_R1.fastq',
      'reads_R2.fastq',
      'variants.vcf',
      'alignment.bam',
      'quality_report.csv',
      'results.txt',
    ];

    Get.bottomSheet(
      Container(
        decoration: const BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.only(
            topLeft: Radius.circular(16),
            topRight: Radius.circular(16),
          ),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              padding: const EdgeInsets.all(20),
              decoration: const BoxDecoration(
                border: Border(bottom: BorderSide(color: Color(0xFFE2E8F0))),
              ),
              child: Row(
                children: [
                  Icon(Icons.folder_outlined, color: widget.node.primaryColor),
                  const SizedBox(width: 12),
                  Text(
                    'Select ${param.label}',
                    style: const TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  const Spacer(),
                  IconButton(
                    onPressed: () => Get.back(),
                    icon: const Icon(Icons.close),
                  ),
                ],
              ),
            ),
            SizedBox(
              height: 300,
              child: ListView.builder(
                itemCount: sampleFiles.length,
                itemBuilder: (context, index) {
                  final file = sampleFiles[index];
                  return ListTile(
                    leading: Icon(
                      Icons.description_outlined,
                      color: widget.node.primaryColor,
                    ),
                    title: Text(file),
                    onTap: () {
                      controller.updateNodeParameter(
                        widget.node.id,
                        param.key,
                        file,
                      );
                      Get.back();
                    },
                  );
                },
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class AddParameterForm extends StatefulWidget {
  final String nodeId;
  final Color primaryColor;

  const AddParameterForm({
    Key? key,
    required this.nodeId,
    required this.primaryColor,
  }) : super(key: key);

  @override
  State<AddParameterForm> createState() => _AddParameterFormState();
}

class _AddParameterFormState extends State<AddParameterForm> {
  final _labelController = TextEditingController();
  final _keyController = TextEditingController();
  ParameterType _selectedType = ParameterType.text;

  @override
  void dispose() {
    _labelController.dispose();
    _keyController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Icon(Icons.add_circle_outline, color: widget.primaryColor),
            const SizedBox(width: 12),
            const Text(
              'Add Parameter',
              style: TextStyle(
                fontSize: 20,
                fontWeight: FontWeight.w700,
              ),
            ),
          ],
        ),
        const SizedBox(height: 24),
        TextFormField(
          controller: _labelController,
          decoration: const InputDecoration(
            labelText: 'Parameter Label',
            hintText: 'e.g., Threads, Quality Score',
            border: OutlineInputBorder(),
          ),
          onChanged: (value) {
            final key =
                value.toLowerCase().replaceAll(RegExp(r'[^a-z0-9]'), '_');
            _keyController.text = key;
          },
        ),
        const SizedBox(height: 16),
        TextFormField(
          controller: _keyController,
          decoration: const InputDecoration(
            labelText: 'Parameter Key',
            hintText: 'e.g., threads, quality_score',
            border: OutlineInputBorder(),
          ),
        ),
        const SizedBox(height: 16),
        DropdownButtonFormField<ParameterType>(
          value: _selectedType,
          decoration: const InputDecoration(
            labelText: 'Parameter Type',
            border: OutlineInputBorder(),
          ),
          items: ParameterType.values.map((type) {
            return DropdownMenuItem(
              value: type,
              child: Text(_getTypeDisplayName(type)),
            );
          }).toList(),
          onChanged: (value) {
            if (value != null) {
              setState(() => _selectedType = value);
            }
          },
        ),
        const SizedBox(height: 24),
        Row(
          mainAxisAlignment: MainAxisAlignment.end,
          children: [
            TextButton(
              onPressed: () => Get.back(),
              child: const Text('Cancel'),
            ),
            const SizedBox(width: 12),
            ElevatedButton(
              onPressed: _addParameter,
              style: ElevatedButton.styleFrom(
                backgroundColor: widget.primaryColor,
                foregroundColor: Colors.white,
              ),
              child: const Text('Add Parameter'),
            ),
          ],
        ),
      ],
    );
  }

  String _getTypeDisplayName(ParameterType type) {
    switch (type) {
      case ParameterType.text:
        return 'Text Input';
      case ParameterType.numeric:
        return 'Number Input';
      case ParameterType.dropdown:
        return 'Dropdown Selection';
      case ParameterType.toggle:
        return 'Toggle Switch';
      case ParameterType.file:
        return 'File Selector';
    }
  }

  void _addParameter() {
    if (_labelController.text.isNotEmpty && _keyController.text.isNotEmpty) {
      final parameter = BlockParameter(
        key: _keyController.text,
        label: _labelController.text,
        type: _selectedType,
        placeholder: 'Enter ${_labelController.text.toLowerCase()}',
      );

      Get.find<PipelineController>().addNodeParameter(widget.nodeId, parameter);
      Get.back();
    }
  }
}
