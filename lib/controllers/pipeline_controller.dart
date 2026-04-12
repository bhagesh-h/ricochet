import 'package:get/get.dart';
import 'package:uuid/uuid.dart';
import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';
import '../controllers/docker_search_controller.dart';
import '../models/pipeline_node.dart';
import '../models/pipeline_file.dart';
import '../models/pipeline_template.dart';
import '../models/docker_pull_progress.dart';
import '../services/docker_service.dart';
import '../services/workspace_service.dart';
import '../services/docker_compose_export_service.dart';
import 'pipeline_tabs_controller.dart';
import 'dart:async';
import 'dart:convert';
import 'dart:io';
import '../utils/shell_utils.dart';
import 'package:path/path.dart' as path;

class PipelineController extends GetxController {
  final DockerService _dockerService = DockerService();
  final WorkspaceService _workspaceService = WorkspaceService();
  final DockerComposeExportService _exportService =
      DockerComposeExportService();

  var nodes = <PipelineNode>[].obs;
  var connections = <Connection>[].obs;
  var selectedNode = Rxn<String>();
  var selectedConnectionId = Rxn<String>();
  var cycleConnectionIds = <String>[].obs;

  /// Incremented each time [loadTemplate] finishes populating the canvas.
  /// The canvas widget listens to this and calls _fitToNodes() so the user
  /// always sees the full template immediately — regardless of where the
  /// template coordinates happen to be in the virtual canvas.
  final fitViewRequest = 0.obs;

  void deselectAll() {
    selectNode(null);
    selectConnection(null);
  }

  // Undo/Redo Stacks keyed by tab ID
  final Map<String, List<String>> _undoStacks = {};
  final Map<String, List<String>> _redoStacks = {};
  String? _currentTabId;

  @override
  void onInit() {
    super.onInit();
    // Canvas starts empty - users can drag blocks from sidebar
  }

  void loadPipelineData(PipelineFile tab) {
    _currentTabId = tab.id;

    // Create new objects so they are distinct
    nodes.value = tab.nodes
        .map((n) => PipelineNode.fromJson(n.toJson()))
        .toList();
    connections.value = tab.connections
        .map((c) => Connection.fromJson(c.toJson()))
        .toList();
    selectedNode.value = null;
    selectedConnectionId.value = null;

    _saveHistoryState();
    fitViewRequest.value++;

    // Initialize undo stack if empty
    if (!_undoStacks.containsKey(tab.id)) {
      _undoStacks[tab.id] = [];
      _redoStacks[tab.id] = [];
      _saveHistoryState();
    }
  }

  void saveStateToPipelineFile(PipelineFile tab) {
    tab.nodes = nodes.map((n) => PipelineNode.fromJson(n.toJson())).toList();
    tab.connections = connections
        .map((c) => Connection.fromJson(c.toJson()))
        .toList();
  }

  void _saveHistoryState({bool isUndo = false}) {
    // Refresh cycle detection (fix #2.3)
    cycleConnectionIds.value = getCycleConnections();

    if (_currentTabId == null) return;
    final tabId = _currentTabId!;

    final currentState = jsonEncode({
      'nodes': nodes.map((n) => n.toJson()).toList(),
      'connections': connections.map((c) => c.toJson()).toList(),
    });

    final stack = _undoStacks[tabId];
    if (stack != null) {
      if (stack.isEmpty || stack.last != currentState) {
        stack.add(currentState);
      }
    }

    if (!isUndo && _redoStacks.containsKey(tabId)) {
      _redoStacks[tabId]!.clear();
    }

    // Notify TabsController to debounce-save to disk + mark tab dirty
    Future.microtask(() {
      if (Get.isRegistered<PipelineTabsController>()) {
        final tabsCtrl = Get.find<PipelineTabsController>();
        tabsCtrl.markActiveTabDirty();
        tabsCtrl.triggerAutoSave();
      }
    });
  }

  void undo() {
    if (_currentTabId == null) return;
    final undoStack = _undoStacks[_currentTabId!] ?? [];
    final redoStack = _redoStacks[_currentTabId!] ?? [];

    if (undoStack.length > 1) {
      redoStack.add(undoStack.removeLast());
      _loadStateFromJson(undoStack.last);
    }
  }

  void redo() {
    if (_currentTabId == null) return;
    final undoStack = _undoStacks[_currentTabId!] ?? [];
    final redoStack = _redoStacks[_currentTabId!] ?? [];

    if (redoStack.isNotEmpty) {
      final stateToRestore = redoStack.removeLast();
      undoStack.add(stateToRestore);
      _loadStateFromJson(stateToRestore);
    }
  }

  void _loadStateFromJson(String jsonString) {
    try {
      final data = jsonDecode(jsonString) as Map<String, dynamic>;
      final nodesList = (data['nodes'] as List)
          .map((n) => PipelineNode.fromJson(n))
          .toList();
      final connectionsList = (data['connections'] as List)
          .map((c) => Connection.fromJson(c))
          .toList();

      nodes.value = nodesList;
      connections.value = connectionsList;
      selectedNode.value = null;
    } catch (e) {
      print('Error loading state from history: $e');
    }
  }

  void addNode(String nodeType, Offset position) {
    // Check if this is a Docker image (starts with "docker:") (fix #10)
    if (nodeType.startsWith('docker:')) {
      final fullName = nodeType.substring(7); // Remove "docker:" prefix
      
      final colonIdx = fullName.indexOf(':');
      final imageName = colonIdx >= 0 ? fullName.substring(0, colonIdx) : fullName;
      final providedTag = colonIdx >= 0 ? fullName.substring(colonIdx + 1) : null;
      
      // If no tag is provided, default to 'latest' temporarily but trigger auto-discovery
      final initialTag = providedTag ?? 'latest';
      final node = _createDockerNode(imageName, position, tag: initialTag);
      
      // Mark as auto-selected initially so _resolveSmartTag can overwrite it
      if (providedTag == null) {
         final tagParam = node.parameters.firstWhereOrNull((p) => p.key == 'tag');
         if (tagParam != null) tagParam.isAuto = true;
      }
      
      nodes.add(node);
      
      // Asynchronously find the "smart" default tag if not provided
      if (providedTag == null) {
        _resolveSmartTag(node.id, imageName);
      }
    } else {
      final node = _createNodeFromType(nodeType, position);
      nodes.add(node);
    }
    _saveHistoryState();
  }

  String _sanitizeNodeName(String raw) {
    return raw.replaceAll(RegExp(r'[\s:;\"' + "'" + r']+'), '_');
  }

  Future<void> _resolveSmartTag(String nodeId, String imageName) async {
    try {
      final searchCtrl = Get.find<DockerSearchController>();
      final smartTag = await searchCtrl.getSmartDefaultTag(imageName);

      // RACECONDITION GUARD: Check if node still exists and its image matches
      final node = nodes.firstWhereOrNull((n) => n.id == nodeId);
      if (node == null) return;
      if (node.dockerImage != imageName) return;

      final paramIdx = node.parameters.indexWhere((p) => p.key == 'tag');
      if (paramIdx == -1) return;

      // ELITE LOCK: If user manually changed the tag during fetch, DO NOT OVERWRITE
      if (!node.parameters[paramIdx].isAuto) {
        print('🔒 Tag for $imageName was manually modified. Resolution aborted.');
        return;
      }

      // Update the node's tag parameter
      node.parameters[paramIdx].value = smartTag;
      node.parameters[paramIdx].isAuto = true; // Still owned by system
      
      // Re-trigger validation
      _checkAndPullImage(node);
      update([node.id]);
    } catch (e) {
      print('⚠️ Failed to resolve smart tag for $imageName: $e');
    }
  }

  /// Duplicate a node — deep copy via JSON, new UUID, offset position. (fix #13)
  void duplicateNode(String id) {
    final original = nodes.firstWhereOrNull((n) => n.id == id);
    if (original == null) return;

    final json = original.toJson();
    json['id'] = const Uuid().v4();
    json['title'] = _sanitizeNodeName('${original.title}_copy');
    // Offset by 30px so it doesn't stack exactly on top
    final pos = original.position;
    json['position'] = {'dx': pos.dx + 30, 'dy': pos.dy + 30};
    // Reset runtime state
    json['status'] = 'idle';
    json['logs'] = <String>[];
    json['downloadProgress'] = 0.0;
    json['downloadStatus'] = '';

    final copy = PipelineNode.fromJson(json);
    nodes.add(copy);
    _saveHistoryState();

    // Pull image for the copy too if it's a Docker node
    if (copy.dockerImage != null) {
      _checkAndPullImage(copy);
    }
  }

  PipelineNode _createNodeFromType(String type, Offset position) {
    final id = const Uuid().v4();

    switch (type) {
      case 'Input':
        return PipelineNode(
          id: id,
          title: _sanitizeNodeName('Input Data'),
          description: 'Upload your data files',
          position: position,
          category: BlockCategory.input,
          iconCodePoint: '0xe2c7',
          parameters: [
            BlockParameter(
              key: 'files',
              label: 'Input Files',
              type: ParameterType.multiFile,
              value: <String>[],
            ),
          ],
          outputPorts: ['data'],
        );

      case 'Output':
        return PipelineNode(
          id: id,
          title: _sanitizeNodeName('Output Results'),
          description: 'Export processed data',
          position: position,
          category: BlockCategory.output,
          iconCodePoint: '0xe2c6',
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

      case 'FastQC':
        return PipelineNode(
          id: id,
          title: _sanitizeNodeName('staphb/fastqc'),
          description: 'Quality control for sequencing data',
          position: position,
          category: BlockCategory.analysis,
          iconCodePoint: '0xe1b8', // analytics icon
          dockerImage: 'staphb/fastqc',
          parameters: [
            BlockParameter(
              key: 'tag',
              label: 'Image Tag',
              type: ParameterType.text,
              value: 'latest',
            ),
            BlockParameter(
              key: 'threads',
              label: 'Number of Threads',
              type: ParameterType.numeric,
              value: 4,
            ),
            BlockParameter(
              key: 'format',
              label: 'Output Format',
              type: ParameterType.dropdown,
              options: ['fastqc', 'casava', 'nanooomore'],
              value: 'fastqc',
            ),
            BlockParameter(
              key: 'command',
              label: 'Command',
              type: ParameterType.text,
              value: r'fastqc $INPUT_FILE --outdir /outputs/',
              placeholder: 'Command to run inside container',
            ),
          ],
        );

      case 'Trimmomatic':
        return PipelineNode(
          id: id,
          title: _sanitizeNodeName('staphb/trimmomatic'),
          description: 'Trim and filter sequencing reads',
          position: position,
          category: BlockCategory.processing,
          iconCodePoint: '0xe14e', // content_cut icon
          dockerImage: 'staphb/trimmomatic',
          parameters: [
            BlockParameter(
              key: 'tag',
              label: 'Image Tag',
              type: ParameterType.text,
              value: 'latest',
            ),
            BlockParameter(
              key: 'threads',
              label: 'Threads',
              type: ParameterType.numeric,
              value: 4,
            ),
            BlockParameter(
              key: 'leading_quality',
              label: 'Leading Quality',
              type: ParameterType.numeric,
              value: 3,
            ),
            BlockParameter(
              key: 'trailing_quality',
              label: 'Trailing Quality',
              type: ParameterType.numeric,
              value: 3,
            ),
            BlockParameter(
              key: 'window_size',
              label: 'Window Size',
              type: ParameterType.numeric,
              value: 4,
            ),
            BlockParameter(
              key: 'min_length',
              label: 'Minimum Length',
              type: ParameterType.numeric,
              value: 36,
            ),
            BlockParameter(
              key: 'command',
              label: 'Command',
              type: ParameterType.text,
              value: r'trimmomatic PE $INPUT_FILE_1 $INPUT_FILE_2 '
                  r'/outputs/trimmed_1.fq.gz /outputs/trimmed_2.fq.gz '
                  r'LEADING:3 TRAILING:3 SLIDINGWINDOW:4:15 MINLEN:36',
              placeholder: 'Command to run inside container',
            ),
          ],
        );

      case 'BWA':
        return PipelineNode(
          id: id,
          title: _sanitizeNodeName('staphb/bwa'),
          description: 'Align sequences against reference',
          position: position,
          category: BlockCategory.processing,
          iconCodePoint: '0xe8d5', // compare_arrows icon
          dockerImage: 'staphb/bwa',
          parameters: [
            BlockParameter(
              key: 'tag',
              label: 'Image Tag',
              type: ParameterType.text,
              value: 'latest',
            ),
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
            ),
            BlockParameter(
              key: 'command',
              label: 'Command',
              type: ParameterType.text,
              value: r'bwa mem /ref/genome.fa $INPUT_FILE_1 $INPUT_FILE_2 -o /outputs/aligned.sam',
              placeholder: 'Command to run inside container',
            ),
          ],
        );

      case 'STAR':
        return PipelineNode(
          id: id,
          title: _sanitizeNodeName('staphb/star'),
          description: 'Spliced alignment to reference',
          position: position,
          category: BlockCategory.processing,
          iconCodePoint: '0xe0e3', // biotech icon
          dockerImage: 'staphb/star',
          parameters: [
            BlockParameter(
              key: 'tag',
              label: 'Image Tag',
              type: ParameterType.text,
              value: 'latest',
            ),
            BlockParameter(
              key: 'threads',
              label: 'Threads',
              type: ParameterType.numeric,
              value: 8,
            ),
            BlockParameter(
              key: 'run_mode',
              label: 'Run Mode',
              type: ParameterType.dropdown,
              options: ['alignReads', 'genomeGenerate'],
              value: 'alignReads',
            ),
            BlockParameter(
              key: 'command',
              label: 'Command',
              type: ParameterType.text,
              value: r'STAR --runMode alignReads --genomeDir /ref '
                  r'--readFilesIn $INPUT_FILE_1 $INPUT_FILE_2 --outFileNamePrefix /outputs/',
              placeholder: 'Command to run inside container',
            ),
          ],
        );

      case 'Samtools':
        return PipelineNode(
          id: id,
          title: _sanitizeNodeName('staphb/samtools'),
          description: 'Process SAM/BAM alignments',
          position: position,
          category: BlockCategory.processing,
          iconCodePoint: '0xeb43', // transform icon
          dockerImage: 'staphb/samtools',
          parameters: [
            BlockParameter(
              key: 'tag',
              label: 'Image Tag',
              type: ParameterType.text,
              value: 'latest',
            ),
            BlockParameter(
              key: 'command',
              label: 'Command',
              type: ParameterType.dropdown,
              options: ['view', 'sort', 'index', 'flagstat', 'stats'],
              value: 'view',
            ),
            BlockParameter(
              key: 'threads',
              label: 'Threads',
              type: ParameterType.numeric,
              value: 4,
            ),
          ],
        );

      default:
        return PipelineNode(
          id: id,
          title: _sanitizeNodeName(type),
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

  PipelineNode _createDockerNode(
    String imageName,
    Offset position, {
    String tag = 'latest',
  }) {
    final id = const Uuid().v4();

    final node = PipelineNode(
      id: id,
      title: _sanitizeNodeName(imageName),
      description: '',
      position: position,
      category: BlockCategory.processing,
      iconCodePoint: '0xe1d4', // storage icon
      dockerImage: imageName,
      status: BlockStatus.checking, // Start with checking status
      parameters: [
        BlockParameter(
          key: 'image',
          label: 'Docker Image',
          type: ParameterType.text,
          value: imageName,
          placeholder: 'Docker image name',
          required: true,
        ),
        BlockParameter(
          key: 'tag',
          label: 'Image Tag',
          type: ParameterType.text,
          value: tag,
          placeholder: 'e.g. latest, 3.11, 0.23.4',
        ),
        BlockParameter(
          key: 'command',
          label: 'Command',
          type: ParameterType.text,
          value: _getDefaultCommand(imageName),
          placeholder: 'Command to run inside container',
        ),
        BlockParameter(
          key: 'volumes',
          label: 'Volume Mounts',
          type: ParameterType.text,
          placeholder: '-v /host/path:/container/path',
        ),
        BlockParameter(
          key: 'environment',
          label: 'Environment Variables',
          type: ParameterType.text,
          placeholder: '-e VAR=value',
        ),
        BlockParameter(
          key: 'ports',
          label: 'Port Mapping',
          type: ParameterType.text,
          placeholder: '-p 8080:80',
        ),
      ],
    );

    // Check and pull image asynchronously
    _checkAndPullImage(node);

    return node;
  }

  /// Returns a pre-filled default command for well-known bioinformatics images
  /// so that newly-dropped nodes are immediately runnable without the user
  /// having to remember the tool's syntax.  Returns [null] for unrecognised
  /// images so the field stays blank and shows the placeholder text instead of
  /// a confusing generic example.
  static String? _getDefaultCommand(String imageName) {
    final lower = imageName.toLowerCase();
    if (lower.contains('fastqc')) {
      return 'fastqc \$INPUT_FILE --outdir /outputs/';
    }
    if (lower.contains('trimmomatic')) {
      return r'trimmomatic PE $INPUT_FILE_1 $INPUT_FILE_2 '
          r'/outputs/trimmed_1.fq.gz /outputs/trimmed_2.fq.gz '
          r'LEADING:3 TRAILING:3 SLIDINGWINDOW:4:15 MINLEN:36';
    }
    if (lower.contains('bwa')) {
      return r'bwa mem /ref/genome.fa $INPUT_FILE_1 $INPUT_FILE_2 -o /outputs/aligned.sam';
    }
    if (lower.contains('samtools')) {
      return 'samtools view -bS \$INPUT_FILE -o /outputs/output.bam';
    }
    if (lower.contains('star')) {
      return r'STAR --runMode alignReads --genomeDir /ref '
          r'--readFilesIn $INPUT_FILE_1 $INPUT_FILE_2 --outFileNamePrefix /outputs/';
    }
    if (lower.contains('gatk')) {
      return 'gatk HaplotypeCaller -I \$INPUT_FILE -O /outputs/variants.vcf';
    }
    if (lower.contains('multiqc')) {
      return 'multiqc /inputs/ -o /outputs/';
    }
    if (lower.contains('hisat')) {
      return r'hisat2 -x /ref/index -1 $INPUT_FILE_1 -2 $INPUT_FILE_2 -S /outputs/aligned.sam';
    }
    if (lower.contains('bowtie')) {
      return r'bowtie2 -x /ref/index -1 $INPUT_FILE_1 -2 $INPUT_FILE_2 -S /outputs/aligned.sam';
    }
    if (lower.contains('kallisto')) {
      return 'kallisto quant -i /ref/index.idx -o /outputs/ \$INPUT_FILE';
    }
    if (lower.contains('salmon')) {
      return 'salmon quant -i /ref/index -l A -r \$INPUT_FILE -p 4 -o /outputs/';
    }
    if (lower.contains('cutadapt')) {
      return 'cutadapt -o /outputs/trimmed.fastq.gz \$INPUT_FILE';
    }
    if (lower.contains('fastp')) {
      return 'fastp -i \$INPUT_FILE -o /outputs/trimmed.fastq.gz';
    }
    if (lower.contains('python')) {
      return 'python /scripts/analysis.py --input \$INPUT_FILE --output /outputs/result.txt';
    }
    if (lower.contains('r-base') || lower.contains('bioconductor')) {
      return 'Rscript /scripts/analysis.R --input \$INPUT_FILE --outdir /outputs/';
    }
    // Unknown image — leave blank so the placeholder guides the user
    return null;
  }

  /// Get the full image name including tag (e.g. python:3.11)
  String getFullImageName(PipelineNode node) {
    if (node.dockerImage == null) return '';
    
    final tagParam = node.parameters.firstWhereOrNull((p) => p.key == 'tag');
    final tag = tagParam?.value?.toString().trim() ?? 'latest';
    
    // If the image name already contains a colon, it might already have a tag
    if (node.dockerImage!.contains(':')) {
      return node.dockerImage!;
    }
    
    return '${node.dockerImage}:$tag';
  }

  /// Check if Docker image exists locally, pull if not
  Future<void> _checkAndPullImage(PipelineNode node) async {
    final fullImage = getFullImageName(node);
    if (fullImage.isEmpty) return;

    try {
      // Check if image exists locally
      final exists = await _dockerService.imageExists(fullImage);

      if (exists) {
        // Image is cached
        node.status = BlockStatus.ready;
        node.isImageLocal = true;
        node.failureScope = NodeFailureScope.none;
        node.downloadStatus = 'Image ready';
        update();
        print('✅ Image ${node.dockerImage} is already cached');
      } else {
        // Need to pull image
        node.status = BlockStatus.downloading;
        node.downloadProgress = 0.0;
        node.failureScope = NodeFailureScope.none;
        node.downloadStatus = 'Starting download...';
        update([node.id]); // Update only this node

        print('📥 Pulling image $fullImage...');

        // Listen to pull progress stream
        await for (final progress in _dockerService.pullImage(
          fullImage,
        )) {
          node.downloadProgress = progress.percentage;
          node.downloadStatus = progress.message;

          if (progress.status == PullStatus.complete) {
            node.status = BlockStatus.ready;
            node.isImageLocal = true;
            node.failureScope = NodeFailureScope.none;
          } else if (progress.status == PullStatus.error) {
            node.status = BlockStatus.error;
            node.failureScope = NodeFailureScope.imagePull;
          }

          update([node.id]); // Update only this node
        }
      }
    } catch (e) {
      node.status = BlockStatus.error;
      node.failureScope = NodeFailureScope.imagePull;
      node.downloadStatus = 'Error: $e';
      update([node.id]); // Update only this node
    }
  }

  /// Retry downloading a Docker image for a node
  Future<void> retryDownload(String nodeId) async {
    final node = nodes.firstWhereOrNull((n) => n.id == nodeId);
    if (node == null || node.dockerImage == null) return;

    // Reset status and progress
    node.status = BlockStatus.checking;
    node.downloadProgress = 0.0;
    node.downloadStatus = 'Retrying download...';
    node.executionStatus = null;
    node.failureScope = NodeFailureScope.none;
    node.isImageLocal = false;
    update([node.id]);

    // Retry the image pull
    await _checkAndPullImage(node);
  }

  /// Executes a single node
  Future<void> executeNode(
    String nodeId, {
    Map<String, String>? inputFiles,
    Map<String, String>? upstreamOutputs,
    Map<String, List<String>>? upstreamInputs,
    String? pipelineName,
  }) async {
    final node = nodes.firstWhereOrNull((n) => n.id == nodeId);
    if (node == null) return;

    // Reset execution-facing state for this run
    node.executionStatus = null;
    if (node.status != BlockStatus.downloading) {
      node.failureScope = NodeFailureScope.none;
    }

    // ─── Special handling: Input node (file picker — no Docker container) ──────
    if (node.category == BlockCategory.input) {
      setNodeStatus(nodeId, BlockStatus.running);
      node.logs.clear();
      update([nodeId]);

      // Collect selected files.  New nodes use 'files' (ParameterType.multiFile,
      // List<String>); old saved files may still use legacy 'file_path' (String).
      final List<String> selectedFiles;
      {
        final multiParam = node.parameters
            .firstWhereOrNull((p) => p.type == ParameterType.multiFile);
        if (multiParam != null && multiParam.value is List) {
          selectedFiles = (multiParam.value as List)
              .map((e) => e.toString().trim())
              .where((s) => s.isNotEmpty)
              .toList();
        } else {
          // Legacy fallback: single file_path string param
          final fileParam =
              node.parameters.firstWhereOrNull((p) => p.key == 'file_path');
          final fp = fileParam?.value?.toString().trim() ?? '';
          selectedFiles = fp.isNotEmpty ? [fp] : [];
        }
      }

      if (selectedFiles.isEmpty) {
        node.logs.add(
            '[ERROR] No file selected. Open the Input node parameters and choose a file.');
        node.executionStatus = 'Input node is not configured: no file selected.';
        node.failureScope = NodeFailureScope.configuration;
        setNodeStatus(nodeId, BlockStatus.failed);
        update([nodeId]);
        return;
      }

      // Validate every selected file exists on disk.
      for (final filePath in selectedFiles) {
        final inputFile = File(filePath);
        if (!await inputFile.exists()) {
          node.logs.add('[ERROR] File not found: $filePath');
          node.logs
              .add('[ERROR] Make sure the path is correct and the file exists.');
          node.executionStatus = 'Input file was not found on disk.';
          node.failureScope = NodeFailureScope.configuration;
          setNodeStatus(nodeId, BlockStatus.failed);
          update([nodeId]);
          return;
        }
      }

      // Log info + sanity-check for each file.
      for (final filePath in selectedFiles) {
        final inputFile = File(filePath);
        final fileBytes = await inputFile.length();
        final sizeKb = (fileBytes / 1024).toStringAsFixed(1);
        node.logs.add('[SYSTEM] Input file: $filePath');
        node.logs.add('[SYSTEM] File size : $sizeKb KB ($fileBytes bytes)');

        // Sanity check: FASTQ/FASTQ.gz files must be at least a few KB.
        final ext = filePath.toLowerCase();
        final isBioSeqFile = ext.endsWith('.fastq') ||
            ext.endsWith('.fastq.gz') ||
            ext.endsWith('.fq') ||
            ext.endsWith('.fq.gz') ||
            ext.endsWith('.bam') ||
            ext.endsWith('.sam') ||
            ext.endsWith('.vcf') ||
            ext.endsWith('.vcf.gz');
        if (isBioSeqFile && fileBytes < 500) {
          node.logs.add(
              '[WARNING] ⚠️  File is suspiciously small ($fileBytes bytes) for a biological sequence file.');
          node.logs.add(
              '[WARNING]    This usually means the download failed or the file is empty.');
          node.logs.add(
              '[WARNING]    Re-download the file and verify it is a valid ${ext.contains("fastq") ? "FASTQ" : "sequence"} file before running.');
        }
      }
      node.logs.add('[SYSTEM] Passing file path(s) to downstream nodes via volume mount.');

      // Register output paths.  Use the first file as '_output_file' (backward
      // compat with the single-path downstream mechanism) plus '_output_file_N'
      // entries so callers that understand N-file output can retrieve all of them.
      node.parameters.removeWhere(
          (p) => p.key == '_output_file' || RegExp(r'^_output_file_\d+$').hasMatch(p.key));
      for (int i = 0; i < selectedFiles.length; i++) {
        node.parameters.add(BlockParameter(
          key: '_output_file_${i + 1}',
          label: 'Output File ${i + 1}',
          type: ParameterType.text,
          value: selectedFiles[i],
        ));
      }
      node.parameters.add(BlockParameter(
        key: '_output_file',
        label: 'Output File',
        type: ParameterType.text,
        value: selectedFiles[0],
      ));

      node.executionStatus = selectedFiles.length == 1
          ? 'Input file prepared successfully.'
          : '${selectedFiles.length} input files prepared successfully.';
      node.failureScope = NodeFailureScope.none;
      setNodeStatus(nodeId, BlockStatus.success);
      update([nodeId]);
      return;
    }

    // ─── Special handling: Output node (save / label result — no container) ───
    if (node.category == BlockCategory.output) {
      setNodeStatus(nodeId, BlockStatus.running);
      node.logs.clear();
      update([nodeId]);

      if (inputFiles == null || inputFiles.isEmpty) {
        node.logs.add(
            '[ERROR] Output node received no data. Connect it to an upstream node.');
        node.executionStatus = 'Output node received no upstream input.';
        node.failureScope = NodeFailureScope.configuration;
        setNodeStatus(nodeId, BlockStatus.failed);
        update([nodeId]);
        return;
      }

      node.logs.add('[SYSTEM] Output node received ${inputFiles.length} input(s):');
      for (final entry in inputFiles.entries) {
        node.logs.add('[SYSTEM]   [${entry.key}] → ${entry.value}');
      }

      // Pass through the first input path so the pipeline can chain further
      final firstPath = inputFiles.values.first;
      final existingOut =
          node.parameters.firstWhereOrNull((p) => p.key == '_output_file');
      if (existingOut != null) {
        existingOut.value = firstPath;
      } else {
        node.parameters.add(BlockParameter(
          key: '_output_file',
          label: 'Output File',
          type: ParameterType.text,
          value: firstPath,
        ));
      }

      node.executionStatus = 'Output node resolved pipeline output successfully.';
      node.failureScope = NodeFailureScope.none;
      setNodeStatus(nodeId, BlockStatus.success);
      update([nodeId]);
      return;
    }

    // ─── Docker container nodes ───────────────────────────────────────────────
    final fullImage = getFullImageName(node);
    if (fullImage.isEmpty) {
      // Surface the error to the node log so it appears in the Execution Console
      node.logs.add('[ERROR] No Docker image specified for "${node.title}".');
      node.logs.add(
          '[ERROR] Set the Docker Image field in the node parameters, then re-run.');
      node.executionStatus = 'Docker image is not configured for this node.';
      node.failureScope = NodeFailureScope.configuration;
      setNodeStatus(nodeId, BlockStatus.failed);
      update([nodeId]);
      return;
    }

    try {
      setNodeStatus(nodeId, BlockStatus.running);
      node.failureScope = NodeFailureScope.none;

      // Clear previous logs
      node.logs.clear();
      update([node.id]);

      // Create staging output directory
      final stagingDir = await _workspaceService.createStagingDirectory(node.title);
      final outputFilePath = path.join(stagingDir.path, 'output.txt');
      final outputFile = File(outputFilePath);
      final outputSink = outputFile.openWrite();

      // Parse parameters (fix #1.2: Robust Arg Parsing)
      var commandParam = node.parameters
          .firstWhereOrNull((p) => p.key == 'command')
          ?.value
          ?.toString();

      var volumesParam = node.parameters
          .firstWhereOrNull((p) => p.key == 'volumes')
          ?.value
          ?.toString();

      var envParam = node.parameters
          .firstWhereOrNull((p) => p.key == 'environment')
          ?.value
          ?.toString();

      // ─── Resolve Custom .out and .in Variable Expressions ─────────────────
      final stringReplacements = <String, String>{};
      final additionalVolumes = <String>[];
      
      if (upstreamOutputs != null) {
        upstreamOutputs.forEach((title, hostPath) {
          final name = hostPath.split(Platform.pathSeparator).last;
          final containerPath = '/inputs/$name';
          stringReplacements['$title.out.'] = '$containerPath/';
          stringReplacements['$title.out'] = containerPath;
        });
      }

      if (upstreamInputs != null) {
        upstreamInputs.forEach((title, hostPaths) {
          int count = 1;
          for (final hostPath in hostPaths) {
            final isDirectory = FileSystemEntity.isDirectorySync(hostPath);
            final name = hostPath.split(Platform.pathSeparator).last;
            
            String containerPath;
            if (isDirectory) {
               containerPath = '/inputs/upstream_${title}_in_${count}_$name';
            } else {
               // Mount raw files inside an isolated context mapping folder specifically for this port
               containerPath = '/inputs/upstream_${title}_in_$count/$name';
            }
            
            var normalizedHostPath = hostPath;
            if (Platform.isWindows && normalizedHostPath.length >= 2 && normalizedHostPath[1] == ':') {
               final drive = normalizedHostPath[0].toLowerCase();
               final rest = normalizedHostPath.substring(2).replaceAll('\\', '/');
               normalizedHostPath = '/$drive$rest';
            }
            additionalVolumes.add('$normalizedHostPath:$containerPath:ro');
            
            if (count == 1) {
              stringReplacements['$title.in.'] = '$containerPath/';
              stringReplacements['$title.in'] = containerPath;
            }
            stringReplacements['$title.in_$count.'] = '$containerPath/';
            stringReplacements['$title.in_$count'] = containerPath;
            count++;
          }
        });
      }

      void applyReplacements(void Function(String) updater, String? original) {
        if (original == null) return;
        var modified = original;
        stringReplacements.forEach((key, value) {
          modified = modified.replaceAll(key, value);
        });
        updater(modified);
      }

      applyReplacements((v) => commandParam = v, commandParam);
      applyReplacements((v) => volumesParam = v, volumesParam);
      applyReplacements((v) => envParam = v, envParam);

      List<String> command = [];
      if (commandParam != null && commandParam!.isNotEmpty) {
        final parts = ShellUtils.splitArguments(commandParam!);
        command = ['sh', '-c', parts.join(' ')];
      }

      final volumes = volumesParam != null
          ? ShellUtils.splitArguments(volumesParam!)
          : <String>[];

      final normalizedVolumes = volumes.map((v) {
        if (!Platform.isWindows) return v;
        final parts = v.split(':');
        if (parts.length >= 2 && parts[0].length == 1) {
          final drive = parts[0].toLowerCase();
          final path = parts[1].replaceAll('\\', '/');
          return '/$drive$path:${parts.sublist(2).join(':')}';
        }
        return v.replaceAll('\\', '/');
      }).toList();

      normalizedVolumes.addAll(additionalVolumes);

      final environment = envParam != null
          ? ShellUtils.splitArguments(envParam!)
          : <String>[];

      final portsParam = node.parameters
          .firstWhereOrNull((p) => p.key == 'ports')
          ?.value
          ?.toString();
      final ports = portsParam != null
          ? ShellUtils.splitArguments(portsParam)
          : <String>[];

      // Add input files to volumes and environment
      if (inputFiles != null) {
        bool firstInput = true;
        int fileIndex = 0;  // for INPUT_FILE_N numbering
        inputFiles.forEach((portName, filePath) {
          var hostPath = filePath;
          // Windows path normalisation
          if (Platform.isWindows &&
              hostPath.length >= 2 &&
              hostPath[1] == ':') {
            final drive = hostPath[0].toLowerCase();
            final rest = hostPath.substring(2).replaceAll('\\', '/');
            hostPath = '/$drive$rest';
          }

          final isDirectory =
              FileSystemEntity.isDirectorySync(filePath);

          if (isDirectory) {
            // Upstream Docker tool output dir → mount as /inputs/<dirName>
            final dirName = filePath.split(Platform.pathSeparator).last;
            final containerPath = '/inputs/$dirName';
            normalizedVolumes.add('$hostPath:$containerPath:ro');
            environment.add(
                'INPUT_${portName.toUpperCase()}_DIR=$containerPath');
            if (firstInput) {
              environment.add('INPUT_DIR=$containerPath');
            }
          } else {
            // Raw file (e.g. from Input node) → mount as /inputs/<fileName>
            final fileName = filePath.split(Platform.pathSeparator).last;
            final containerPath = '/inputs/$fileName';
            normalizedVolumes.add('$hostPath:$containerPath:ro');
            environment
                .add('INPUT_${portName.toUpperCase()}=$containerPath');
            // Numbered alias: $INPUT_FILE_1, $INPUT_FILE_2, … (matches chips)
            fileIndex++;
            environment.add('INPUT_FILE_$fileIndex=$containerPath');
            if (firstInput &&
                environment.every((e) => !e.startsWith('INPUT_FILE='))) {
              // $INPUT_FILE = first file (backward compat for single-input commands)
              environment.add('INPUT_FILE=$containerPath');
            }
          }
          firstInput = false;
        });
      }

      // Auto-mount /outputs/ so tools that write files (FastQC, MultiQC, etc.)
      // have a writable directory that maps back to the workspace node folder.
      final outputDir = File(outputFilePath).parent;
      if (!await outputDir.exists()) {
        await outputDir.create(recursive: true);
      }
      var hostOutputPath = outputDir.path;
      if (Platform.isWindows &&
          hostOutputPath.length >= 2 &&
          hostOutputPath[1] == ':') {
        final drive = hostOutputPath[0].toLowerCase();
        final rest = hostOutputPath.substring(2).replaceAll('\\', '/');
        hostOutputPath = '/$drive$rest';
      }
      normalizedVolumes.add('$hostOutputPath:/outputs');
      environment.add('OUTPUT_DIR=/outputs');

      // Fix #1.1: Platform flags for Apple Silicon
      final platformInfo = await _dockerService.getPlatformInfo();
      String? platformFlag;
      if (platformInfo.needsPlatformEmulation) {
        platformFlag = platformInfo.dockerPlatformFlag;
      }

      // Build and log the exact docker command so users can debug
      // (written to node logs before the container starts)
      final previewVolumes = normalizedVolumes.map((v) => '-v $v').join(' ');
      final previewEnv = environment.map((e) => '-e $e').join(' ');
      final previewCmd = command.isNotEmpty ? command.join(' ') : '(no command — using image entrypoint)';
      node.logs.add('[SYSTEM] ─── Docker command ───────────────────────────');
      node.logs.add('[SYSTEM] Image   : $fullImage');
      node.logs.add('[SYSTEM] Volumes : $previewVolumes');
      node.logs.add('[SYSTEM] Env     : $previewEnv');
      node.logs.add('[SYSTEM] Command : $previewCmd');
      node.logs.add('[SYSTEM] ────────────────────────────────────────────────');
      update([nodeId]);

      final process = await _dockerService.runContainer(
        image: fullImage,
        containerName: node.id,
        platform: platformFlag,
        command: command,
        volumes: normalizedVolumes,
        environment: environment,
        ports: ports,
      );

      // Stream logs and write to file.
      // IMPORTANT: Use Completers to track when each stream is fully drained.
      // Never close the sink until both onDone callbacks have fired — otherwise
      // the last chunks buffered by the Dart event loop are lost and output.txt
      // ends up as zero bytes even when the process produced output.
      final stdoutDone = Completer<void>();
      final stderrDone = Completer<void>();

      process.stdout.transform(utf8.decoder).listen(
        (data) {
          final lines = data.split('\n').where((l) => l.isNotEmpty);
          for (final line in lines) {
            print('🐳 [${node.title}] STDOUT: $line');
            node.logs.add('[STDOUT] $line');
            outputSink.writeln(line);
          }
          update([node.id]);
        },
        onDone: () {
          if (!stdoutDone.isCompleted) stdoutDone.complete();
        },
        onError: (Object e) {
          print('⚠️ [${node.title}] STDOUT stream error: $e');
          if (!stdoutDone.isCompleted) stdoutDone.complete();
        },
        cancelOnError: false,
      );

      process.stderr.transform(utf8.decoder).listen(
        (data) {
          final lines = data.split('\n').where((l) => l.isNotEmpty);
          for (final line in lines) {
            print('⚠️ [${node.title}] STDERR: $line');
            node.logs.add('[STDERR] $line');
            outputSink.writeln('[ERROR] $line');
          }
          update([node.id]);
        },
        onDone: () {
          if (!stderrDone.isCompleted) stderrDone.complete();
        },
        onError: (Object e) {
          print('⚠️ [${node.title}] STDERR stream error: $e');
          if (!stderrDone.isCompleted) stderrDone.complete();
        },
        cancelOnError: false,
      );

      final exitCode = await process.exitCode
          .timeout(
            const Duration(minutes: 120),
            onTimeout: () {
              node.logs.add(
                '[ERROR] ⏰ Execution timed out after 120 minutes.'
              );
              node.logs.add(
                '[ERROR]    The container was stopped automatically.'
              );
              node.logs.add(
                '[ERROR]    If your data needs more time, check that your command is correct'
              );
              node.logs.add(
                '[ERROR]    and that it reads from \$INPUT_FILE, not from stdin.'
              );
              _dockerService.stopContainer(node.id);
              return 124; // Standard timeout exit code
            },
          );

      // Wait for both stream listeners to fully drain before touching the sink.
      // Give up to 30 seconds for any residual buffered output to arrive after
      // the process exits — this is intentionally generous because large tools
      // (FastQC, BWA) can flush megabytes of final output right at exit.
      await Future.wait([stdoutDone.future, stderrDone.future])
          .timeout(
            const Duration(seconds: 30),
            onTimeout: () {
              print('⚠️ [${node.title}] Stream drain timed out — closing sink anyway');
              if (!stdoutDone.isCompleted) stdoutDone.complete();
              if (!stderrDone.isCompleted) stderrDone.complete();
              return [];
            },
          );

      // Now it is safe to flush and close — all writes have been committed.
      await outputSink.flush();
      await outputSink.close();

      // ── Finalize Output (Deduplication / Versioning) ──
      node.logs.add('[SYSTEM] Finalizing results...');
      update([node.id]);
      
      final finalOutputPath = await _workspaceService.finalizeNodeOutput(
        stagingPath: stagingDir.path,
        pipelineName: pipelineName ?? 'Current Pipeline',
        nodeName: node.title,
        explicitOverridePath: node.outputDirectory,
      );
      
      final finalOutputFilePath = path.join(finalOutputPath, 'output.txt');
      print('🏁 Node ${node.title} finished with exit code $exitCode');
      print('📁 Final output path: $finalOutputPath');

      // Update node parameters with the final path for downstream tools
      final outputParam = node.parameters.firstWhereOrNull(
        (p) => p.key == '_output_file',
      );
      if (outputParam != null) {
        outputParam.value = finalOutputFilePath;
      } else {
        node.parameters.add(
          BlockParameter(
            key: '_output_file',
            label: 'Output File',
            type: ParameterType.text,
            value: finalOutputFilePath,
          ),
        );
      }
      
      // Update node logs with the final path
      node.logs.add('[SYSTEM] Results finalized at: $finalOutputPath');
      if (finalOutputPath != stagingDir.path) {
          node.logs.add('[SYSTEM] (Results were identical to a previous run or moved to a stable path)');
      }

      if (exitCode == 0) {
        node.status = BlockStatus.success;
        node.executionStatus = 'Execution completed successfully.';
        node.failureScope = NodeFailureScope.none;
      } else {
        // If manually stopped, it might have a specific exit code (e.g. 137)
        // For now just mark as failed if not 0
        node.status = BlockStatus.failed;
        node.executionStatus = 'Execution failed (exit code $exitCode).';
        node.failureScope = NodeFailureScope.execution;
      }
      update([node.id]);
    } catch (e) {
      print('❌ Error executing node: $e');
      node.status = BlockStatus.error;
      node.executionStatus = 'Execution error: $e';
      node.failureScope = NodeFailureScope.execution;
      update([node.id]);
    }
  }

  /// Stop a running node
  Future<void> stopNode(String nodeId) async {
    final node = nodes.firstWhereOrNull((n) => n.id == nodeId);
    if (node == null) return;

    try {
      if (node.status == BlockStatus.downloading && node.dockerImage != null) {
        print('🛑 Stopping pull for node ${node.title}...');
        await _dockerService.stopPull(node.dockerImage!);
        node.downloadStatus = 'Pull canceled by user';
        node.failureScope = NodeFailureScope.canceled;
      } else if (node.status == BlockStatus.running) {
        print('🛑 Stopping container for node ${node.title}...');
        await _dockerService.stopContainer(node.id);
        node.logs.add('[SYSTEM] Execution stopped by user');
        node.executionStatus = 'Execution canceled by user.';
        node.failureScope = NodeFailureScope.canceled;
      }

      node.status = BlockStatus.failed;
      update([node.id]);
    } catch (e) {
      print('❌ Error stopping node: $e');
      node.logs.add('[SYSTEM] Error stopping: $e');
      update([node.id]);
    }
  }

  /// Returns a list of connection IDs that are part of a cycle
  List<String> getCycleConnections() {
    final cycleConnections = <String>{};
    final visited = <String>{}; // Nodes visited in any DFS traversal
    final recStack = <String>{}; // Nodes currently in the recursion stack (current path)
    final pathNodeIds = <String>[]; // Track node IDs in the current DFS path
    final pathConnectionIds = <String>[]; // Track connection IDs in the current DFS path

    void dfs(String nodeId) {
      visited.add(nodeId);
      recStack.add(nodeId);
      pathNodeIds.add(nodeId);

      final outgoing = connections.where((c) => c.fromNodeId == nodeId).toList();
      for (final conn in outgoing) {
        pathConnectionIds.add(conn.id); // Add connection to path before exploring

        if (!visited.contains(conn.toNodeId)) {
          // Node not visited yet, recurse
          dfs(conn.toNodeId);
        } else if (recStack.contains(conn.toNodeId)) {
          // Cycle detected! conn.toNodeId is an ancestor in the current path.
          // The cycle consists of the back-edge (conn.id) and all connections
          // in pathConnectionIds from the point where conn.toNodeId was entered
          // into the path, up to the current connection.

          // Add the back-edge itself
          cycleConnections.add(conn.id);

          // Find the index of conn.toNodeId in pathNodeIds
          final cycleStartIndex = pathNodeIds.indexOf(conn.toNodeId);

          // Add all connections from that point in pathConnectionIds
          for (int i = cycleStartIndex; i < pathConnectionIds.length; i++) {
            cycleConnections.add(pathConnectionIds[i]);
          }
        }
        pathConnectionIds.removeLast(); // Remove connection from path after exploring
      }

      recStack.remove(nodeId); // Remove from recursion stack when leaving node
      pathNodeIds.removeLast(); // Remove node from path when leaving
    }

    // Iterate over all nodes to ensure all disconnected components are checked
    for (var node in nodes) {
      if (!visited.contains(node.id)) {
        dfs(node.id);
      }
    }

    return cycleConnections.toList();
  }

  /// Returns the nodes in topological order (execution order).
  /// Throws an exception if a cycle is detected.
  List<PipelineNode> getExecutionOrder() {
    // 1. Build adjacency list and in-degree map
    final inDegree = <String, int>{};
    final adjacencyList = <String, List<String>>{};

    // Initialize for all nodes
    for (var node in nodes) {
      inDegree[node.id] = 0;
      adjacencyList[node.id] = [];
    }

    // Populate from connections
    for (var connection in connections) {
      // Ensure nodes still exist (in case of deletion)
      if (inDegree.containsKey(connection.toNodeId) &&
          inDegree.containsKey(connection.fromNodeId)) {
        adjacencyList[connection.fromNodeId]!.add(connection.toNodeId);
        inDegree[connection.toNodeId] = inDegree[connection.toNodeId]! + 1;
      }
    }

    // 2. Initialize queue with nodes having in-degree 0
    final queue = <String>[];
    inDegree.forEach((nodeId, degree) {
      if (degree == 0) {
        queue.add(nodeId);
      }
    });

    // 3. Process queue (Kahn's algorithm)
    final sortedNodeIds = <String>[];
    while (queue.isNotEmpty) {
      final u = queue.removeAt(0);
      sortedNodeIds.add(u);

      if (adjacencyList.containsKey(u)) {
        for (var v in adjacencyList[u]!) {
          inDegree[v] = inDegree[v]! - 1;
          if (inDegree[v] == 0) {
            queue.add(v);
          }
        }
      }
    }

    // 4. Check for cycles
    if (sortedNodeIds.length != nodes.length) {
      throw Exception('Cycle detected in pipeline! Please remove loops.');
    }

    // 5. Map IDs back to PipelineNode objects
    return sortedNodeIds
        .map((id) => nodes.firstWhere((n) => n.id == id))
        .toList();
  }

  /// Export pipeline as Docker-Compose ZIP
  Future<void> exportPipelineAsDockerCompose() async {
    if (nodes.isEmpty) {
      Get.snackbar(
        'Export Failed',
        'The canvas is empty. Add nodes to export a pipeline.',
        snackPosition: SnackPosition.BOTTOM,
        backgroundColor: const Color(0xFFEF4444),
        colorText: const Color(0xFFFFFFFF),
      );
      return;
    }

    final safeContext = Get.context;

    try {
      // Show progress dialog using standard Flutter showDialog to avoid GetX router desync
      showDialog(
        context: Get.overlayContext!,
        barrierDismissible: false,
        builder: (context) => const Dialog(
          child: Padding(
            padding: EdgeInsets.all(24.0),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                CircularProgressIndicator(),
                SizedBox(height: 16),
                Text(
                  'Generating Docker-Compose Export...',
                  style: TextStyle(fontWeight: FontWeight.w600),
                ),
              ],
            ),
          ),
        ),
      );

      // Validate cycles and format before generating
      final sortedNodes = getExecutionOrder();
      
      // Get the pipeline name
      final tabsCtrl = Get.find<PipelineTabsController>();
      final pipelineName = tabsCtrl.currentPipeline?.name ?? 'Ricochet-Pipeline';

      // Generate the ZIP
      final zipBytes = await _exportService.generateExportZip(
        sortedNodes,
        connections,
        pipelineName,
      );

      final timestamp = DateTime.now()
          .toIso8601String()
          .replaceAll(':', '-')
          .split('.')[0];
      final safeName = pipelineName.replaceAll(RegExp(r'[^a-zA-Z0-9_\-]'), '_');
      final filepath = await _workspaceService.saveExportZip(
        zipBytes,
        '${safeName}_export_$timestamp.zip',
      );

      // Close dialog safely
      Navigator.of(Get.overlayContext!).pop();

      // Show success using native Flutter to bypass GetX's overlay unmount bugs
      if (safeContext != null && safeContext.mounted) {
        ScaffoldMessenger.of(safeContext).showSnackBar(
          SnackBar(
            content: Text('Pipeline exported to $filepath'),
            backgroundColor: const Color(0xFF10B981),
            behavior: SnackBarBehavior.floating,
            action: SnackBarAction(
              label: 'OPEN',
              textColor: Colors.white,
              onPressed: () async {
                final uri = Uri.file(File(filepath).parent.path);
                if (await canLaunchUrl(uri)) {
                  await launchUrl(uri);
                }
              },
            ),
          ),
        );
      }
    } catch (e) {
      Navigator.of(Get.overlayContext!).pop();
      
      if (safeContext != null && safeContext.mounted) {
        ScaffoldMessenger.of(safeContext).showSnackBar(
          SnackBar(
            content: Text('Could not generate export: $e'),
            backgroundColor: Colors.red.shade600,
            behavior: SnackBarBehavior.floating,
          ),
        );
      }
    }
  }

  /// Opens the output directory in the file explorer
  Future<void> openOutputDirectory() async {
    try {
      String pathToOpen;
      
      try {
        final tabsCtrl = Get.find<PipelineTabsController>();
        final activeTab = tabsCtrl.currentPipeline;
        if (activeTab != null) {
          final pipelineFolder = await _workspaceService.createPipelineFolder(activeTab.name);
          pathToOpen = pipelineFolder;
        } else {
           pathToOpen = await _workspaceService.getWorkspacePath();
        }
      } catch (e) {
         pathToOpen = await _workspaceService.getWorkspacePath();
      }

      if (Platform.isMacOS) {
        await Process.run('open', [pathToOpen]);
      } else if (Platform.isWindows) {
        await Process.run('explorer', [pathToOpen]);
      } else if (Platform.isLinux) {
        await Process.run('xdg-open', [pathToOpen]);
      }

      print('📂 Opened directory: $pathToOpen');
    } catch (e) {
      print('❌ Error opening directory: $e');
    }
  }

  void updateNodePosition(String id, Offset newPosition) {
    final index = nodes.indexWhere((node) => node.id == id);
    if (index != -1) {
      nodes[index].position = newPosition;
      nodes.refresh(); // reactive UI update only — no history save here
    }
  }

  /// Called on drag-end only — writes a single undo snapshot and triggers auto-save.
  void finalizeNodeDrag(String id) {
    if (nodes.any((n) => n.id == id)) {
      _saveHistoryState(); // one write per drag, not per pixel
    }
  }

  void selectNode(String? nodeId) {
    selectedNode.value = nodeId;
    if (nodeId != null) {
      selectedConnectionId.value = null;
    }
    // Update node selection state
    for (var node in nodes) {
      node.isSelected = node.id == nodeId;
    }
    nodes.refresh();
  }

  void selectConnection(String? connectionId) {
    selectedConnectionId.value = connectionId;
    if (connectionId != null) {
      selectNode(null); // Deselect nodes
    }
  }

  void addConnection(
    String fromId,
    String toId, {
    String? fromPort,
    String? toPort,
  }) {
    if (fromId != toId && !_connectionExists(fromId, toId)) {
      final connection = Connection(
        id: const Uuid().v4(),
        fromNodeId: fromId,
        toNodeId: toId,
        fromPort: fromPort ?? 'output',
        toPort: toPort ?? 'input',
      );
      connections.add(connection);
      _saveHistoryState();
    }
  }

  void deleteConnection(String connectionId) {
    connections.removeWhere((c) => c.id == connectionId);
    if (selectedConnectionId.value == connectionId) {
      selectedConnectionId.value = null;
    }
    _saveHistoryState();
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
        param.isAuto = false; // Mark as manual override
        nodes.refresh();
        _saveHistoryState();

        // If image or tag changed, re-verify image (fix #10)
        if (paramKey == 'image' || paramKey == 'tag') {
          if (paramKey == 'image') node.dockerImage = value.toString();
          _checkAndPullImage(node);
        }
      }
    }
  }

  void addNodeParameter(String nodeId, BlockParameter parameter) {
    final node = nodes.firstWhereOrNull((n) => n.id == nodeId);
    if (node != null) {
      node.parameters.add(parameter);
      nodes.refresh();
      _saveHistoryState();
    }
  }

  void removeNodeParameter(String nodeId, int index) {
    final node = nodes.firstWhereOrNull((n) => n.id == nodeId);
    if (node != null && index >= 0 && index < node.parameters.length) {
      node.parameters.removeAt(index);
      nodes.refresh();
      _saveHistoryState();
    }
  }

  void deleteNode(String id) {
    if (id == 'input-default' || id == 'output-default') return;

    nodes.removeWhere((n) => n.id == id);
    connections.removeWhere((c) => c.fromNodeId == id || c.toNodeId == id);

    if (selectedNode.value == id) {
      selectedNode.value = null;
    }
    _saveHistoryState();
  }

  void clearAll() {
    nodes.clear();
    connections.clear();
    selectedNode.value = null;
    // Don't initialize default blocks - give users a truly blank canvas
    _saveHistoryState();
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
  /// Generates a dummy node to fetch original default parameters that are missing from the active node.
  List<BlockParameter> getMissingDefaultParameters(PipelineNode activeNode) {
    PipelineNode dummy;
    if (activeNode.dockerImage != null && activeNode.title == activeNode.dockerImage) {
        dummy = _createDockerNode(activeNode.dockerImage!, Offset.zero, tag: 'latest');
    } else {
        String type = activeNode.title;
        if (type == 'BWA Aligner') type = 'BWA';
        else if (type == 'STAR Aligner') type = 'STAR';
        else if (type == 'Input Data') type = 'Input';
        else if (type == 'Output Results') type = 'Output';
        dummy = _createNodeFromType(type, Offset.zero);
    }
    
    final currentKeys = activeNode.parameters.map((p) => p.key).toSet();
    return dummy.parameters.where((p) => !currentKeys.contains(p.key)).toList();
  }

  // ─── Template loading ────────────────────────────────────────────────────────

  /// Populate the current tab's canvas from a [PipelineTemplate].
  /// Creates all nodes and wires the defined connections in one atomic batch.
  void loadTemplate(PipelineTemplate template, {String? tabId}) {
    // Establish tab context so _saveHistoryState and undo/redo work correctly.
    if (tabId != null) {
      _currentTabId = tabId;
      _undoStacks.putIfAbsent(tabId, () => []);
      _redoStacks.putIfAbsent(tabId, () => []);
    }

    nodes.clear();
    connections.clear();
    selectedNode.value = null;
    cycleConnectionIds.clear();

    final createdNodes = <PipelineNode>[];
    for (final def in template.nodes) {
      final PipelineNode node;
      if (def.nodeType.startsWith('docker:')) {
        final fullName = def.nodeType.substring(7);
        final colonIdx = fullName.indexOf(':');
        final imageName =
            colonIdx >= 0 ? fullName.substring(0, colonIdx) : fullName;
        final tag =
            colonIdx >= 0 ? fullName.substring(colonIdx + 1) : 'latest';
        node = _createDockerNode(imageName, def.position, tag: tag);
      } else {
        node = _createNodeFromType(def.nodeType, def.position);
      }
      for (final entry in def.parameterOverrides.entries) {
        final param =
            node.parameters.firstWhereOrNull((p) => p.key == entry.key);
        if (param != null) param.value = entry.value;
      }
      nodes.add(node);
      createdNodes.add(node);
    }

    for (final conn in template.connections) {
      if (conn.fromIndex < createdNodes.length &&
          conn.toIndex < createdNodes.length) {
        final from = createdNodes[conn.fromIndex];
        final to = createdNodes[conn.toIndex];
        connections.add(Connection(
          id: const Uuid().v4(),
          fromNodeId: from.id,
          toNodeId: to.id,
          fromPort:
              from.outputPorts.isNotEmpty ? from.outputPorts.first : 'output',
          toPort:
              to.inputPorts.isNotEmpty ? to.inputPorts.first : 'input',
        ));
      }
    }

    _saveHistoryState();

    // Signal the canvas to fit the view so the user sees all template nodes
    // immediately without having to click "Fit Workflow" manually.
    fitViewRequest.value++;
  }
}
