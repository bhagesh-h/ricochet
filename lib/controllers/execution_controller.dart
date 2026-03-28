import 'dart:async';
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:get/get.dart';
import '../models/pipeline_node.dart';
import '../services/workspace_service.dart';
import 'pipeline_controller.dart';
import 'pipeline_tabs_controller.dart';

class ExecutionController extends GetxController {
  final log = <String>[].obs;
  final isRunning = false.obs;
  final showPanel = false.obs;
  final panelHeight = 250.0.obs;

  final Map<String, List<String>> _logsByTab = {};
  final Map<String, bool> _isRunningByTab = {};
  String? _currentTabId;

  String _resolvePipelineName(String tabId) {
    if (!Get.isRegistered<PipelineTabsController>()) return 'Pipeline';
    final tabsCtrl = Get.find<PipelineTabsController>();
    final tab = tabsCtrl.tabs.firstWhereOrNull((t) => t.id == tabId);
    final name = tab?.name.trim();
    if (name == null || name.isEmpty) return 'Pipeline';
    return name;
  }

  void clearLogsAndSwitchToActiveTab(String? tabId) {
    if (tabId == null) return;
    
    if (_currentTabId != null) {
      _logsByTab[_currentTabId!] = List.from(log);
      _isRunningByTab[_currentTabId!] = isRunning.value;
    }
    
    _currentTabId = tabId;
    log.clear();
    
    if (_logsByTab.containsKey(tabId)) {
      log.addAll(_logsByTab[tabId]!);
    }
    isRunning.value = _isRunningByTab[tabId] ?? false;
  }

  void _addLog(String tabId, String message) {
    if (!_logsByTab.containsKey(tabId)) {
      _logsByTab[tabId] = [];
    }
    _logsByTab[tabId]!.add(message);
    
    if (_currentTabId == tabId) {
      log.add(message);
    }
  }

  void _setRunning(String tabId, bool running) {
    _isRunningByTab[tabId] = running;
    if (_currentTabId == tabId) {
      isRunning.value = running;
    }
  }

  void setPanelHeight(double height) {
    // Clamp height between min and max values
    panelHeight.value = height.clamp(100.0, 600.0);
  }

  /// Validates the pipeline before execution.
  /// Returns a list of human-readable issues. Empty list = valid.
  List<String> validatePipeline() {
    final pipelineCtrl = Get.find<PipelineController>();
    final errors = <String>[];

    // 1. Empty canvas
    if (pipelineCtrl.nodes.isEmpty) {
      errors.add('🚫 Canvas is empty. Add at least one node before executing.');
      return errors; // No point checking further
    }

    // 2. Docker nodes with no command set
    for (final node in pipelineCtrl.nodes) {
      if (node.dockerImage != null) {
        final commandParam = node.parameters
            .firstWhereOrNull((p) => p.key == 'command');
        final command = commandParam?.value?.toString().trim() ?? '';
        if (command.isEmpty) {
          final example = _getExampleCommand(node.dockerImage ?? node.title);
          errors.add(
            '⚠️ Node "${node.title}": Command field is empty.\n'
            '   Your input file is available as \$INPUT_FILE inside the container.\n'
            '   Output directory is /outputs/ (mapped to your workspace folder).\n'
            '   Example command:  $example',
          );
        }
        // Check image still set
        final imageParam = node.parameters
            .firstWhereOrNull((p) => p.key == 'image');
        final image = imageParam?.value?.toString().trim() ?? '';
        if (image.isEmpty) {
          errors.add('⚠️ Node "${node.title}": Docker Image field is empty.');
        }
      }
    }

    // 3. Disconnected nodes (only flag in multi-node pipeline)
    if (pipelineCtrl.nodes.length > 1) {
      for (final node in pipelineCtrl.nodes) {
        final hasAnyConnection = pipelineCtrl.connections.any(
          (c) => c.fromNodeId == node.id || c.toNodeId == node.id,
        );
        if (!hasAnyConnection) {
          errors.add('🔗 Node "${node.title}" is not connected to any other node.');
        }
      }
    }

    return errors;
  }

  void runPipeline() async {
    final tabId = _currentTabId;
    if (tabId == null) return;

    if (_isRunningByTab[tabId] == true) return;

    // --- Validate before running ---
    final errors = validatePipeline();
    // Check for cycles (fix #2.3)
    final pipelineCtrl = Get.find<PipelineController>();
    if (pipelineCtrl.cycleConnectionIds.isNotEmpty) {
      errors.add(
          'Pipeline contains cycles (loops). Ricochet only supports Directed Acyclic Graphs (DAGs).');
    }

    if (errors.isNotEmpty) {
      Get.dialog(
        AlertDialog(
          title: Row(
            children: const [
              Icon(Icons.warning_amber_rounded, color: Color(0xFFF59E0B)),
              SizedBox(width: 8),
              Text('Pipeline Issues Found'),
            ],
          ),
          content: SingleChildScrollView(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                const Text(
                  'Please fix these issues before executing:',
                  style: TextStyle(fontWeight: FontWeight.w600),
                ),
                const SizedBox(height: 12),
                ...errors.map((e) => Padding(
                  padding: const EdgeInsets.only(bottom: 8),
                  child: Text(e, style: const TextStyle(fontSize: 13)),
                )),
              ],
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Get.back(),
              child: const Text('Fix Issues'),
            ),
            ElevatedButton(
              style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFFF59E0B)),
              onPressed: () { Get.back(); _doRunPipeline(tabId); },
              child: const Text('Run Anyway', style: TextStyle(color: Colors.white)),
            ),
          ],
        ),
      );
      return;
    }

    _doRunPipeline(tabId);
  }

  void _doRunPipeline(String tabId) async {
    if (_currentTabId == tabId) log.clear();
    _logsByTab[tabId] = [];
    
    _setRunning(tabId, true);
    showPanel.value = true; // Show panel when running
    final pipelineCtrl = Get.find<PipelineController>();

    // Create a fresh run directory for every execution.  This prevents outputs
    // from different runs sharing the same folder, which would leave stale
    // output.txt files from a prior aborted run appearing as the current result.
    final runPipelineName = _resolvePipelineName(tabId);
    final runDir = await WorkspaceService().startNewRun(
      pipelineName: runPipelineName,
    );
    _addLog(tabId, '📂 Run workspace: ${runDir.path}');

    _addLog(tabId, '🚀 Pipeline execution started');
    _addLog(tabId, '📊 Found ${pipelineCtrl.nodes.length} blocks');
    _addLog(tabId, '🔗 Found ${pipelineCtrl.connections.length} connections');
    _addLog(tabId, '');

    // 1. Determine execution order (Topological Sort)
    List<PipelineNode> executionOrder;
    try {
      executionOrder = pipelineCtrl.getExecutionOrder();
      _addLog(tabId,
          '📋 Execution order determined: ${executionOrder.map((n) => n.title).join(' -> ')}');
    } catch (e) {
      _addLog(tabId, '❌ Pipeline execution failed');
      _addLog(tabId, '🚨 Error: ${e.toString().replaceAll('Exception: ', '')}');

      // Show error dialog
      Get.dialog(
        AlertDialog(
          title: const Text('Pipeline Error'),
          content: Text(e.toString().replaceAll('Exception: ', '')),
          actions: [
            TextButton(
              onPressed: () => Get.back(),
              child: const Text('OK'),
            ),
          ],
        ),
      );

      _setRunning(tabId, false);
      return;
    }

    _addLog(tabId, '');

    // Map to store output file paths: nodeId -> filePath
    final nodeOutputs = <String, String>{};

    // 2. Execute nodes in order
    for (var node in executionOrder) {
      pipelineCtrl.setNodeStatus(node.id, BlockStatus.running);

      _addLog(tabId, '⚡ Executing: ${node.title}');
      _addLog(tabId, '   📂 Category: ${node.category.name}');

      for (var param in node.parameters) {
        // Skip internal runtime params from clutter
        if (param.key.startsWith('_')) continue;
        if (param.value != null && param.value.toString().isNotEmpty) {
          _addLog(tabId, '   ⚙️ ${param.label}: ${param.value}');
        }
      }

      // ── Heartbeat: log elapsed time every 10 s so the user knows
      // the container is still alive during long-running bioinformatics jobs.
      final _nodeStart = DateTime.now();
      Timer? _heartbeat;
      _heartbeat = Timer.periodic(const Duration(seconds: 10), (_) {
        final elapsed = DateTime.now().difference(_nodeStart);
        final mm = elapsed.inMinutes.toString().padLeft(2, '0');
        final ss = (elapsed.inSeconds % 60).toString().padLeft(2, '0');
        _addLog(tabId, '   ⏱️  Still running... $mm:$ss elapsed');
      });

      // Prepare input files from upstream nodes
      final inputFiles = <String, String>{};
      final upstreamConnections =
          pipelineCtrl.connections.where((c) => c.toNodeId == node.id).toList();

      for (int connIdx = 0; connIdx < upstreamConnections.length; connIdx++) {
        final connection = upstreamConnections[connIdx];
        final upstreamNodeId = connection.fromNodeId;
        if (nodeOutputs.containsKey(upstreamNodeId)) {
          // Always include the upstreamNodeId so two Input nodes that both
          // connect to the same port don't collide and overwrite each other.
          final key = 'file_${connIdx + 1}_${upstreamNodeId.substring(0, 6)}';
          final filePath = nodeOutputs[upstreamNodeId]!;
          inputFiles[key] = filePath;
          final upstreamTitle = pipelineCtrl.nodes
              .firstWhere((n) => n.id == upstreamNodeId)
              .title;
          _addLog(tabId, '   📥 Input ${connIdx + 1} from "$upstreamTitle"');
          _addLog(tabId, '      Host path : $filePath');
          final fileName = filePath.split(Platform.pathSeparator).last;
          _addLog(tabId, '      In-container: /inputs/$fileName  (\$INPUT_FILE_${connIdx + 1})');
        }
      }

      // Execute the node using the real pipeline controller logic
      await pipelineCtrl.executeNode(node.id, inputFiles: inputFiles);
      _heartbeat.cancel();
      _heartbeat = null;
      final totalElapsed = DateTime.now().difference(_nodeStart);
      final mm = totalElapsed.inMinutes.toString().padLeft(2, '0');
      final ss = (totalElapsed.inSeconds % 60).toString().padLeft(2, '0');
      _addLog(tabId, '   ⏱️  Finished in $mm:$ss');

      // Check status after execution
      if (node.status == BlockStatus.success) {
        _addLog(tabId, '   ✅ Completed successfully');

        // Get real output file path
        final outputParam = node.parameters.firstWhereOrNull(
          (p) => p.key == '_output_file',
        );

        if (outputParam?.value != null) {
          final path = outputParam!.value.toString();

          // Input nodes store the raw file path; Docker tool nodes store
          // output.txt inside the output dir — downstream gets the directory.
          final isInputNode = node.category == BlockCategory.input;
          final isOutputNode = node.category == BlockCategory.output;

          if (isInputNode || isOutputNode) {
            // Pass the exact file path so the next container mounts
            // /Users/.../sample.fastq.gz  →  /inputs/sample.fastq.gz  ✅
            _addLog(tabId, '   📄 File: $path');
            nodeOutputs[node.id] = path;
          } else {
            // Docker tool nodes: pass their output directory so downstream
            // tools can access all generated files (HTML, ZIP, BAM…).
            final outDir = File(path).parent;
            _addLog(tabId, '   📁 Output folder: ${outDir.path}');

            try {
              final produced = await outDir
                  .list()
                  .where((e) => e is File)
                  .cast<File>()
                  .toList();
              if (produced.isNotEmpty) {
                _addLog(tabId, '   📄 Files produced:');
                for (final f in produced) {
                  final kb = (await f.length() / 1024).toStringAsFixed(1);
                  _addLog(tabId,
                      '      ${f.uri.pathSegments.last}  ($kb KB)');
                }
              } else {
                _addLog(tabId,
                    '   ℹ️  No files found in output folder. '
                    'Make sure your command writes to /outputs/.');
              }
            } catch (_) {}

            nodeOutputs[node.id] = outDir.path;
          }
        }
      } else {
        _addLog(tabId, '   ❌ Execution failed');
        // Surface ALL captured stderr/error lines to the execution console
        final stderrLines = node.logs
            .where((l) => l.startsWith('[STDERR]') || l.startsWith('[ERROR]'))
            .toList();
        final stdoutLines = node.logs
            .where((l) => l.startsWith('[STDOUT]') || l.startsWith('[SYSTEM]'))
            .take(3)
            .toList();
        // Prefer stderr; fall back to last few stdout lines if no stderr captured
        final logsToShow =
            stderrLines.isNotEmpty ? stderrLines : stdoutLines;
        for (final line in logsToShow.take(20)) {
          _addLog(tabId, '   $line');
        }
        if (logsToShow.length > 20) {
          _addLog(tabId,
              '   ... (+${logsToShow.length - 20} more lines — check node logs for full output)');
        }
        if (logsToShow.isEmpty) {
          _addLog(tabId,
              '   (No output captured. The container may have exited immediately or the command was empty.)');
        }

        // Stop pipeline on failure
        _addLog(tabId, '');
        _addLog(tabId,
            '⚠️ Pipeline execution stopped due to failure in ${node.title}');
        _setRunning(tabId, false);
        return;
      }

      _addLog(tabId, '');
    }

    final allSuccess =
        pipelineCtrl.nodes.every((n) => n.status == BlockStatus.success);
    if (allSuccess) {
      _addLog(tabId, '🎉 Pipeline completed successfully!');
      _addLog(tabId, '📈 All blocks executed without errors');
    } else {
      _addLog(tabId, '⚠️ Pipeline execution stopped due to errors');
    }

    _setRunning(tabId, false);
  }

  /// Returns a suggested example command for a known bioinformatics image.
  /// Used in validation error messages so the user knows what to type.
  String _getExampleCommand(String imageName) {
    final lower = imageName.toLowerCase();
    if (lower.contains('fastqc')) {
      return 'fastqc \$INPUT_FILE --outdir /outputs/';
    }
    if (lower.contains('trimmomatic')) {
      return 'trimmomatic SE \$INPUT_FILE /outputs/trimmed.fastq.gz '
          'LEADING:3 TRAILING:3 SLIDINGWINDOW:4:15 MINLEN:36';
    }
    if (lower.contains('bwa')) {
      return 'bwa mem /ref/genome.fa \$INPUT_FILE -o /outputs/aligned.sam';
    }
    if (lower.contains('samtools')) {
      return 'samtools view -bS \$INPUT_FILE -o /outputs/output.bam';
    }
    if (lower.contains('star')) {
      return 'STAR --runMode alignReads --genomeDir /ref '
          '--readFilesIn \$INPUT_FILE --outFileNamePrefix /outputs/';
    }
    if (lower.contains('gatk')) {
      return 'gatk HaplotypeCaller -I \$INPUT_FILE -O /outputs/variants.vcf';
    }
    if (lower.contains('multiqc')) {
      return 'multiqc /inputs/ -o /outputs/';
    }
    if (lower.contains('hisat')) {
      return 'hisat2 -x /ref/index -U \$INPUT_FILE -S /outputs/aligned.sam';
    }
    if (lower.contains('bowtie')) {
      return 'bowtie2 -x /ref/index -U \$INPUT_FILE -S /outputs/aligned.sam';
    }
    if (lower.contains('kallisto')) {
      return 'kallisto quant -i /ref/index.idx -o /outputs/ \$INPUT_FILE';
    }
    if (lower.contains('salmon')) {
      return 'salmon quant -i /ref/index -l A -r \$INPUT_FILE -p 4 -o /outputs/';
    }
    if (lower.contains('cutadapt') || lower.contains('fastp')) {
      return 'fastp -i \$INPUT_FILE -o /outputs/trimmed.fastq.gz';
    }
    if (lower.contains('python')) {
      return 'python /scripts/analysis.py --input \$INPUT_FILE --output /outputs/result.txt';
    }
    if (lower.contains('r-base') || lower.contains('bioconductor')) {
      return 'Rscript /scripts/analysis.R --input \$INPUT_FILE --outdir /outputs/';
    }
    return 'your-tool \$INPUT_FILE -o /outputs/output.txt';
  }

  void clearLog() {
    if (_currentTabId != null) {
      _logsByTab[_currentTabId!] = [];
    }
    log.clear();
  }

  void togglePanel() {
    showPanel.value = !showPanel.value;
  }

  /// Stop all running containers for the current tab (fix #6)
  void stopPipeline() {
    final tabId = _currentTabId;
    if (tabId == null) return;
    if (_isRunningByTab[tabId] != true) return;

    _addLog(tabId, '🛑 Stop requested by user...');

    final pipelineCtrl = Get.find<PipelineController>();
    for (final node in pipelineCtrl.nodes) {
      if (node.status == BlockStatus.running) {
        pipelineCtrl.stopNode(node.id);
      }
    }

    _addLog(tabId, '⚠️ Pipeline was stopped by user.');
    _setRunning(tabId, false);
  }
}
