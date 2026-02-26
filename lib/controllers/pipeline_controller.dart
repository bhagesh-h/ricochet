import 'package:get/get.dart';
import 'package:uuid/uuid.dart';
import '../models/pipeline_node.dart';
import '../models/docker_pull_progress.dart';
import '../services/docker_service.dart';
import '../services/workspace_service.dart';
import 'dart:ui';
import 'dart:convert';
import 'dart:io';

class PipelineController extends GetxController {
  final DockerService _dockerService = DockerService();
  final WorkspaceService _workspaceService = WorkspaceService();

  var nodes = <PipelineNode>[].obs;
  var connections = <Connection>[].obs;
  var selectedNode = Rxn<String>();

  @override
  void onInit() {
    super.onInit();
    // Canvas starts empty - users can drag blocks from sidebar
  }

  void addNode(String nodeType, Offset position) {
    // Check if this is a Docker image (starts with "docker:")
    if (nodeType.startsWith('docker:')) {
      final imageName = nodeType.substring(7); // Remove "docker:" prefix
      final node = _createDockerNode(imageName, position);
      nodes.add(node);
    } else {
      final node = _createNodeFromType(nodeType, position);
      nodes.add(node);
    }
  }

  PipelineNode _createNodeFromType(String type, Offset position) {
    final id = const Uuid().v4();

    switch (type) {
      case 'Input':
        return PipelineNode(
          id: id,
          title: 'Input Data',
          description: 'Upload your data files',
          position: position,
          category: BlockCategory.input,
          iconCodePoint: '0xe2c7',
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

      case 'Output':
        return PipelineNode(
          id: id,
          title: 'Output Results',
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
              options: [
                'GATK HaplotypeCaller',
                'FreeBayes',
                'SAMtools',
                'VarScan'
              ],
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

  PipelineNode _createDockerNode(String imageName, Offset position) {
    final id = const Uuid().v4();

    final node = PipelineNode(
      id: id,
      title: imageName,
      description: 'Docker container execution',
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
          value: 'latest',
          placeholder: 'Image tag version',
        ),
        BlockParameter(
          key: 'command',
          label: 'Command',
          type: ParameterType.text,
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

  /// Check if Docker image exists locally, pull if not
  Future<void> _checkAndPullImage(PipelineNode node) async {
    if (node.dockerImage == null) return;

    try {
      // Check if image exists locally
      final exists = await _dockerService.imageExists(node.dockerImage!);

      if (exists) {
        // Image is cached
        node.status = BlockStatus.ready;
        node.isImageLocal = true;
        node.downloadStatus = 'Image ready';
        update();
        print('✅ Image ${node.dockerImage} is already cached');
      } else {
        // Need to pull image
        node.status = BlockStatus.downloading;
        node.downloadProgress = 0.0;
        node.downloadStatus = 'Starting download...';
        update([node.id]); // Update only this node

        print('📥 Pulling image ${node.dockerImage}...');

        // Listen to pull progress stream
        await for (final progress
            in _dockerService.pullImage(node.dockerImage!)) {
          node.downloadProgress = progress.percentage;
          node.downloadStatus = progress.message;

          if (progress.status == PullStatus.complete) {
            node.status = BlockStatus.ready;
            node.isImageLocal = true;
          } else if (progress.status == PullStatus.error) {
            node.status = BlockStatus.error;
          }

          update([node.id]); // Update only this node
        }
      }
    } catch (e) {
      node.downloadStatus = 'Error: $e';
      update([node.id]); // Update only this node
    }
  }

  /// Executes a single node
  Future<void> executeNode(String nodeId,
      {Map<String, String>? inputFiles}) async {
    final node = nodes.firstWhereOrNull((n) => n.id == nodeId);
    if (node == null) return;

    try {
      setNodeStatus(nodeId, BlockStatus.running);

      // Clear previous logs
      node.logs.clear();
      update([node.id]);

      // Create output file
      final outputFilePath = await _workspaceService.getNodeOutputFilePath(
        node.id,
        node.title,
        filename: 'output.txt',
      );
      final outputFile = File(outputFilePath);
      final outputSink = outputFile.openWrite();

      // Parse parameters
      final commandParam = node.parameters
          .firstWhereOrNull((p) => p.key == 'command')
          ?.value
          ?.toString();

      // Use shell wrapper for commands to handle complex syntax
      List<String> command = [];
      if (commandParam != null && commandParam.isNotEmpty) {
        // Wrap command in shell to handle pipes, redirects, etc.
        command = ['sh', '-c', commandParam];
      }

      final volumesParam = node.parameters
          .firstWhereOrNull((p) => p.key == 'volumes')
          ?.value
          ?.toString();
      final volumes =
          volumesParam?.split(' ').where((s) => s.isNotEmpty).toList() ?? [];

      final envParam = node.parameters
          .firstWhereOrNull((p) => p.key == 'environment')
          ?.value
          ?.toString();
      final environment =
          envParam?.split(' ').where((s) => s.isNotEmpty).toList() ?? [];

      final portsParam = node.parameters
          .firstWhereOrNull((p) => p.key == 'ports')
          ?.value
          ?.toString();
      final ports =
          portsParam?.split(' ').where((s) => s.isNotEmpty).toList() ?? [];

      // Add input files to volumes and environment
      if (inputFiles != null) {
        inputFiles.forEach((portName, filePath) {
          final fileName = filePath.split(Platform.pathSeparator).last;
          final containerPath = '/inputs/$fileName';

          // Mount file read-only
          volumes.add('$filePath:$containerPath:ro');

          // Add env var for the input path
          // e.g. INPUT_DATA=/inputs/data.txt
          environment.add('INPUT_${portName.toUpperCase()}=$containerPath');

          // Also add a generic INPUT_FILE var if it's the first input
          if (environment.every((e) => !e.startsWith('INPUT_FILE='))) {
            environment.add('INPUT_FILE=$containerPath');
          }
        });
      }

      final process = await _dockerService.runContainer(
        image: node.dockerImage!,
        containerName: node.id,
        command: command,
        volumes: volumes,
        environment: environment,
        ports: ports,
      );

      // Stream logs and write to file
      process.stdout.transform(utf8.decoder).listen((data) {
        final lines = data.split('\n').where((l) => l.isNotEmpty);
        for (final line in lines) {
          print('🐳 [${node.title}] STDOUT: $line');
          node.logs.add('[STDOUT] $line');
          outputSink.writeln(line); // Write to file
        }
        update([node.id]); // Update UI for logs
      });

      process.stderr.transform(utf8.decoder).listen((data) {
        final lines = data.split('\n').where((l) => l.isNotEmpty);
        for (final line in lines) {
          print('⚠️ [${node.title}] STDERR: $line');
          node.logs.add('[STDERR] $line');
          outputSink.writeln('[ERROR] $line'); // Write errors to file too
        }
        update([node.id]); // Update UI for logs
      });

      final exitCode = await process.exitCode;

      // Close the output file
      await outputSink.flush();
      await outputSink.close();

      print('🏁 Node ${node.title} finished with exit code $exitCode');
      print('📁 Output saved to: $outputFilePath');

      // Store output file path in node
      node.logs.add('[SYSTEM] Output saved to: $outputFilePath');

      // Add output file path as a parameter for reference
      final outputParam =
          node.parameters.firstWhereOrNull((p) => p.key == '_output_file');
      if (outputParam != null) {
        outputParam.value = outputFilePath;
      } else {
        node.parameters.add(BlockParameter(
          key: '_output_file',
          label: 'Output File',
          type: ParameterType.text,
          value: outputFilePath,
        ));
      }

      if (exitCode == 0) {
        node.status = BlockStatus.success;
      } else {
        // If manually stopped, it might have a specific exit code (e.g. 137)
        // For now just mark as failed if not 0
        node.status = BlockStatus.failed;
      }
      update([node.id]);
    } catch (e) {
      print('❌ Error executing node: $e');
      node.status = BlockStatus.error;
      update([node.id]);
    }
  }

  /// Stop a running node
  Future<void> stopNode(String nodeId) async {
    final node = nodes.firstWhereOrNull((n) => n.id == nodeId);
    if (node == null) return;

    try {
      print('🛑 Stopping node ${node.title}...');
      await _dockerService.stopContainer(node.id);
      node.logs.add('[SYSTEM] Execution stopped by user');
      node.status = BlockStatus.failed; // Or a new 'stopped' status
      update([node.id]);
    } catch (e) {
      print('❌ Error stopping node: $e');
      node.logs.add('[SYSTEM] Error stopping: $e');
      update([node.id]);
    }
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

  /// Opens the output directory in the file explorer
  Future<void> openOutputDirectory() async {
    try {
      final workspacePath = await _workspaceService.getWorkspacePath();
      final currentRunPath = await _workspaceService.getCurrentRunPath();

      final pathToOpen = currentRunPath ?? workspacePath;

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

  void addConnection(String fromId, String toId,
      {String? fromPort, String? toPort}) {
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
    // Don't initialize default blocks - give users a truly blank canvas
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
