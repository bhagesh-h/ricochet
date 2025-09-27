import 'package:get/get.dart';
import 'package:uuid/uuid.dart';
import '../models/pipeline_node.dart';
import 'dart:ui';

class PipelineController extends GetxController {
  var nodes = <PipelineNode>[].obs;
  var connections = <Connection>[].obs;
  var selectedNode = Rxn<String>();

  @override
  void onInit() {
    super.onInit();
    _initializeDefaultBlocks();
  }

  void _initializeDefaultBlocks() {
    // Input block - only file selection parameters
    final inputBlock = PipelineNode(
      id: 'input-default',
      title: 'Input Data',
      description: 'Upload your data files',
      position: const Offset(100, 150),
      category: BlockCategory.input,
      iconCodePoint: '0xe2c7', // download icon
      parameters: [
        BlockParameter(
          key: 'file_path',
          label: 'Select File',
          type: ParameterType.file,
          placeholder: 'Choose file from your computer',
          required: true,
        ),
      ],
      outputPorts: ['data'],
    );

    // Output block - only file export parameters
    final outputBlock = PipelineNode(
      id: 'output-default',
      title: 'Output Results',
      description: 'Export processed data',
      position: const Offset(800, 150),
      category: BlockCategory.output,
      iconCodePoint: '0xe2c6', // upload icon
      parameters: [
        BlockParameter(
          key: 'output_name',
          label: 'Output Filename',
          type: ParameterType.text,
          value: 'results',
          placeholder: 'Enter filename',
        ),
        BlockParameter(
          key: 'format',
          label: 'Export Format',
          type: ParameterType.dropdown,
          options: ['JSON', 'CSV', 'TXT', 'HTML', 'PDF'],
          value: 'JSON',
        ),
      ],
      inputPorts: ['result'],
    );

    nodes.addAll([inputBlock, outputBlock]);
  }

  void addNode(String nodeType, Offset position) {
    final node = _createNodeFromType(nodeType, position);
    nodes.add(node);
  }

  PipelineNode _createNodeFromType(String type, Offset position) {
    final id = const Uuid().v4();
    
    switch (type) {
      case 'FastQC':
        return PipelineNode(
          id: id,
          title: 'FastQC',
          description: 'Quality control for sequencing data',
          position: position,
          category: BlockCategory.analysis,
          iconCodePoint: '0xe1b8', // analytics icon
          parameters: [
            BlockParameter(
              key: 'threads',
              label: 'Number of Threads',
              type: ParameterType.numeric,
              value: 4,
              placeholder: 'Enter number of threads',
            ),
            BlockParameter(
              key: 'kmer_size',
              label: 'K-mer Size',
              type: ParameterType.numeric,
              value: 7,
              placeholder: 'Enter k-mer size',
            ),
            BlockParameter(
              key: 'format',
              label: 'Output Format',
              type: ParameterType.dropdown,
              options: ['HTML', 'JSON', 'XML'],
              value: 'HTML',
            ),
            BlockParameter(
              key: 'enable_adapters',
              label: 'Check Adapters',
              type: ParameterType.toggle,
              value: true,
            ),
          ],
        );

      case 'Trimmomatic':
        return PipelineNode(
          id: id,
          title: 'Trimmomatic',
          description: 'Trim and filter sequencing reads',
          position: position,
          category: BlockCategory.processing,
          iconCodePoint: '0xe14e', // content_cut icon
          parameters: [
            BlockParameter(
              key: 'leading_quality',
              label: 'Leading Quality',
              type: ParameterType.numeric,
              value: 3,
              placeholder: 'Minimum quality for leading bases',
            ),
            BlockParameter(
              key: 'trailing_quality',
              label: 'Trailing Quality',
              type: ParameterType.numeric,
              value: 3,
              placeholder: 'Minimum quality for trailing bases',
            ),
            BlockParameter(
              key: 'window_size',
              label: 'Window Size',
              type: ParameterType.numeric,
              value: 4,
              placeholder: 'Sliding window size',
            ),
            BlockParameter(
              key: 'required_quality',
              label: 'Required Quality',
              type: ParameterType.numeric,
              value: 15,
              placeholder: 'Average quality required',
            ),
            BlockParameter(
              key: 'min_length',
              label: 'Minimum Length',
              type: ParameterType.numeric,
              value: 36,
              placeholder: 'Minimum read length',
            ),
          ],
        );

      case 'BWA':
        return PipelineNode(
          id: id,
          title: 'BWA Aligner',
          description: 'Align sequences against reference',
          position: position,
          category: BlockCategory.processing,
          iconCodePoint: '0xe8d5', // compare_arrows icon
          parameters: [
            BlockParameter(
              key: 'algorithm',
              label: 'Algorithm',
              type: ParameterType.dropdown,
              options: ['mem', 'aln', 'bwasw'],
              value: 'mem',
            ),
            BlockParameter(
              key: 'threads',
              label: 'Threads',
              type: ParameterType.numeric,
              value: 8,
              placeholder: 'Number of threads',
            ),
            BlockParameter(
              key: 'min_seed_length',
              label: 'Min Seed Length',
              type: ParameterType.numeric,
              value: 19,
              placeholder: 'Minimum seed length',
            ),
            BlockParameter(
              key: 'band_width',
              label: 'Band Width',
              type: ParameterType.numeric,
              value: 100,
              placeholder: 'Band width for banded alignment',
            ),
          ],
        );

      case 'Variant Caller':
        return PipelineNode(
          id: id,
          title: 'Variant Caller',
          description: 'Call genetic variants from alignments',
          position: position,
          category: BlockCategory.analysis,
          iconCodePoint: '0xe8b6', // search icon
          parameters: [
            BlockParameter(
              key: 'caller_type',
              label: 'Caller Type',
              type: ParameterType.dropdown,
              options: ['GATK HaplotypeCaller', 'FreeBayes', 'SAMtools', 'VarScan'],
              value: 'GATK HaplotypeCaller',
            ),
            BlockParameter(
              key: 'min_base_quality',
              label: 'Min Base Quality',
              type: ParameterType.numeric,
              value: 20,
              placeholder: 'Minimum base quality score',
            ),
            BlockParameter(
              key: 'min_mapping_quality',
              label: 'Min Mapping Quality',
              type: ParameterType.numeric,
              value: 20,
              placeholder: 'Minimum mapping quality',
            ),
            BlockParameter(
              key: 'ploidy',
              label: 'Ploidy',
              type: ParameterType.numeric,
              value: 2,
              placeholder: 'Sample ploidy',
            ),
            BlockParameter(
              key: 'emit_ref_confidence',
              label: 'Emit Reference Confidence',
              type: ParameterType.toggle,
              value: false,
            ),
          ],
        );

      default:
        return PipelineNode(
          id: id,
          title: type,
          description: 'Custom processing block',
          position: position,
          category: BlockCategory.processing,
          iconCodePoint: '0xe8b8', // settings icon
          parameters: [
            BlockParameter(
              key: 'custom_param_1',
              label: 'Parameter 1',
              type: ParameterType.text,
              placeholder: 'Enter custom parameter',
            ),
            BlockParameter(
              key: 'custom_param_2',
              label: 'Parameter 2',
              type: ParameterType.numeric,
              value: 1,
              placeholder: 'Enter numeric value',
            ),
          ],
        );
    }
  }

  void updateNodePosition(String id, Offset newPosition) {
    final index = nodes.indexWhere((node) => node.id == id);
    if (index != -1) {
      nodes[index].position = newPosition;
      nodes.refresh();
    }
  }

  void selectNode(String? nodeId) {
    selectedNode.value = nodeId;
    // Update node selection state
    for (var node in nodes) {
      node.isSelected = node.id == nodeId;
    }
    nodes.refresh();
  }

  void addConnection(String fromId, String toId, {String? fromPort, String? toPort}) {
    if (fromId != toId && !_connectionExists(fromId, toId)) {
      final connection = Connection(
        id: const Uuid().v4(),
        fromNodeId: fromId,
        toNodeId: toId,
        fromPort: fromPort ?? 'output',
        toPort: toPort ?? 'input',
      );
      connections.add(connection);
    }
  }

  bool _connectionExists(String fromId, String toId) {
    return connections.any((c) => c.fromNodeId == fromId && c.toNodeId == toId);
  }

  void updateNodeParameter(String nodeId, String paramKey, dynamic value) {
    final node = nodes.firstWhereOrNull((n) => n.id == nodeId);
    if (node != null) {
      final param = node.parameters.firstWhereOrNull((p) => p.key == paramKey);
      if (param != null) {
        param.value = value;
        nodes.refresh();
      }
    }
  }

  void addNodeParameter(String nodeId, BlockParameter parameter) {
    final node = nodes.firstWhereOrNull((n) => n.id == nodeId);
    if (node != null) {
      node.parameters.add(parameter);
      nodes.refresh();
    }
  }

  void removeNodeParameter(String nodeId, int index) {
    final node = nodes.firstWhereOrNull((n) => n.id == nodeId);
    if (node != null && index >= 0 && index < node.parameters.length) {
      node.parameters.removeAt(index);
      nodes.refresh();
    }
  }

  void deleteNode(String id) {
    if (id == 'input-default' || id == 'output-default') return;
    
    nodes.removeWhere((n) => n.id == id);
    connections.removeWhere((c) => c.fromNodeId == id || c.toNodeId == id);
    
    if (selectedNode.value == id) {
      selectedNode.value = null;
    }
  }

  void clearAll() {
    nodes.clear();
    connections.clear();
    selectedNode.value = null;
    _initializeDefaultBlocks();
  }

  void setNodeStatus(String id, BlockStatus status) {
    final node = nodes.firstWhereOrNull((n) => n.id == id);
    if (node != null) {
      node.status = status;
      nodes.refresh();
    }
  }

  // Legacy compatibility method
  void updateNodeConfig(String id, Map<String, dynamic> newConfig) {
    final node = nodes.firstWhereOrNull((n) => n.id == id);
    if (node != null) {
      newConfig.forEach((key, value) {
        updateNodeParameter(id, key, value);
      });
    }
  }
}