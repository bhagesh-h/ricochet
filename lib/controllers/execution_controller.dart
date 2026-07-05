import 'dart:async';
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:get/get.dart';
import '../models/pipeline_node.dart';
import '../models/node_execution_identity.dart';
import '../models/pipeline_execution_context.dart';
import '../services/pipeline_tab_runtime_store.dart';
import 'pipeline_controller.dart';
import 'pipeline_tabs_controller.dart';
import 'settings_controller.dart';

class ExecutionController extends GetxController {
  final log = <String>[].obs;
  final isRunning = false.obs;
  final showPanel = false.obs;
  final panelHeight = 250.0.obs;

  final Map<String, List<String>> _logsByTab = {};
  final Map<String, bool> _isRunningByTab = {};
  final Map<String, int> _runTokenByTab = {};
  String? _currentTabId;

  int _invalidateRun(String tabId) {
    final next = (_runTokenByTab[tabId] ?? 0) + 1;
    _runTokenByTab[tabId] = next;
    return next;
  }

  int _beginRun(String tabId) {
    final token = _invalidateRun(tabId);
    _setRunning(tabId, true);
    return token;
  }

  bool _isRunActive(String tabId, int runToken) {
    return _runTokenByTab[tabId] == runToken;
  }

  bool isRunningForTab(String? tabId) {
    if (tabId == null) return false;
    return _isRunningByTab[tabId] == true;
  }

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
        final image = imageParam?.value?.toString().trim() ?? node.dockerImage ?? '';
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
              onPressed: () { Get.back(); _startPipelineRun(tabId); },
              child: const Text('Run Anyway', style: TextStyle(color: Colors.white)),
            ),
          ],
        ),
      );
      return;
    }

    _startPipelineRun(tabId);
  }

  void _startPipelineRun(String tabId) {
    if (_isRunningByTab[tabId] == true) return;
    final runToken = _beginRun(tabId);
    _doRunPipeline(tabId, runToken);
  }

  void _doRunPipeline(String tabId, int runToken) async {
    if (!_isRunActive(tabId, runToken)) {
      _setRunning(tabId, false);
      return;
    }

    final pipelineCtrl = Get.find<PipelineController>();
    final tabsCtrl = Get.find<PipelineTabsController>();
    final runtimeStore = Get.find<PipelineTabRuntimeStore>();
    final tab = tabsCtrl.tabs.firstWhereOrNull((t) => t.id == tabId);
    if (tab == null) {
      _setRunning(tabId, false);
      return;
    }

    runtimeStore.ensureTab(tab);
    if (tabsCtrl.activeTabId.value == tabId) {
      runtimeStore.captureActiveCanvas(tabId, pipelineCtrl);
    }

    final runPipelineName = _resolvePipelineName(tabId);
    final session = runtimeStore.beginSession(
      tabId: tabId,
      runToken: runToken,
      pipelineName: runPipelineName,
      controller: pipelineCtrl,
      activeTabId: tabsCtrl.activeTabId.value,
    );

    if (_currentTabId == tabId) log.clear();
    _logsByTab[tabId] = [];

    showPanel.value = true;
    final settingsCtrl = Get.isRegistered<SettingsController>()
        ? Get.find<SettingsController>()
        : null;
    final useParallel = settingsCtrl?.parallelExecutionEnabled.value ?? false;

    _addLog(tabId, '🚀 Pipeline execution started');
    _addLog(tabId, '📊 Found ${session.nodes.length} blocks');
    _addLog(tabId, '🔗 Found ${session.connections.length} connections');
    if (useParallel) {
      _addLog(tabId, '⚡ Parallel execution enabled');
    }
    _addLog(tabId, '');

    List<List<PipelineNode>> executionLevels;
    try {
      executionLevels = PipelineController.executionLevelsFor(
        session.nodes,
        session.connections,
      );
      final flatOrder =
          executionLevels.expand((level) => level).map((n) => n.title).join(' -> ');
      _addLog(tabId, '📋 Execution order determined: $flatOrder');
      for (var i = 0; i < executionLevels.length; i++) {
        final level = executionLevels[i];
        if (level.length > 1) {
          _addLog(
            tabId,
            '   Wave ${i + 1}: ${level.map((n) => n.title).join(', ')} '
            '(can run ${useParallel ? 'in parallel' : 'sequentially'})',
          );
        }
      }
    } catch (e) {
      _addLog(tabId, '❌ Pipeline execution failed');
      _addLog(tabId, '🚨 Error: ${e.toString().replaceAll('Exception: ', '')}');

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

    final nodeOutputs = <String, String>{};
    final nodeInputs = <String, List<String>>{};

    try {
      for (final level in executionLevels) {
        if (!_isRunActive(tabId, runToken)) break;

        if (useParallel && level.length > 1) {
          settingsCtrl?.setParallelRunActive(true);
          _addLog(
            tabId,
            '🔄 Running ${level.length} nodes in parallel: '
            '${level.map((n) => n.title).join(', ')}',
          );
          try {
            final results = await Future.wait(
              level.map(
                (node) => _executeNodeInPipeline(
                  tabId: tabId,
                  runToken: runToken,
                  session: session,
                  pipelineCtrl: pipelineCtrl,
                  node: node,
                  nodeOutputs: nodeOutputs,
                  nodeInputs: nodeInputs,
                  announcePipelineStop: false,
                ),
              ),
            );
            if (!_isRunActive(tabId, runToken)) break;
            if (results.any((success) => !success)) {
              await _stopRunningNodesInLevel(session, level);
              _addLog(
                tabId,
                '⚠️ Pipeline execution stopped due to errors in parallel wave',
              );
              return;
            }
          } finally {
            settingsCtrl?.setParallelRunActive(false);
          }
        } else {
          for (final node in level) {
            if (!_isRunActive(tabId, runToken)) break;
            final success = await _executeNodeInPipeline(
              tabId: tabId,
              runToken: runToken,
              session: session,
              pipelineCtrl: pipelineCtrl,
              node: node,
              nodeOutputs: nodeOutputs,
              nodeInputs: nodeInputs,
            );
            if (!success || !_isRunActive(tabId, runToken)) {
              return;
            }
          }
        }
      }

      if (!_isRunActive(tabId, runToken)) {
        _addLog(tabId, '⚠️ Pipeline was stopped by user.');
        return;
      }

      final allSuccess =
          session.nodes.every((n) => n.status == BlockStatus.success);
      if (allSuccess) {
        _addLog(tabId, '🎉 Pipeline completed successfully!');
        _addLog(tabId, '📈 All blocks executed without errors');
      } else {
        _addLog(tabId, '⚠️ Pipeline execution stopped due to errors');
      }
    } finally {
      if (runtimeStore.hasActiveSession(tabId)) {
        runtimeStore.finalizeSession(
          tabId: tabId,
          session: session,
          controller: pipelineCtrl,
          activeTabId: tabsCtrl.activeTabId.value,
          file: tab,
        );
      }
      settingsCtrl?.setParallelRunActive(false);
      _setRunning(tabId, false);
    }
  }

  Future<void> _stopRunningNodesInLevel(
    PipelineRunSession session,
    List<PipelineNode> level,
  ) async {
    final pipelineCtrl = Get.find<PipelineController>();
    final stops = <Future<void>>[];
    for (final node in level) {
      if (node.status == BlockStatus.running) {
        stops.add(
          pipelineCtrl.stopNode(
            node.id,
            executionContext: session.context,
            executionIdentity: NodeExecutionIdentity(
              tabId: session.tabId,
              nodeId: node.id,
              nodeTitle: node.title,
            ),
          ),
        );
      }
    }
    if (stops.isNotEmpty) {
      await Future.wait(stops);
    }
  }

  String _nodeIdFragment(String nodeId) {
    if (nodeId.length <= 6) return nodeId;
    return nodeId.substring(0, 6);
  }

  Future<bool> _executeNodeInPipeline({
    required String tabId,
    required int runToken,
    required PipelineRunSession session,
    required PipelineController pipelineCtrl,
    required Map<String, String> nodeOutputs,
    required Map<String, List<String>> nodeInputs,
    required PipelineNode node,
    bool announcePipelineStop = true,
  }) async {
    if (!_isRunActive(tabId, runToken)) return false;

    final ctx = session.context;
    final identity = NodeExecutionIdentity(
      tabId: session.tabId,
      nodeId: node.id,
      nodeTitle: node.title,
    );

    ctx.setNodeStatus(node.id, BlockStatus.running);

    _addLog(tabId, '⚡ Executing: ${node.title}');
    _addLog(tabId, '   📂 Category: ${node.category.name}');

    for (var param in node.parameters) {
      if (param.key.startsWith('_')) continue;
      if (param.value != null && param.value.toString().isNotEmpty) {
        _addLog(tabId, '   ⚙️ ${param.label}: ${param.value}');
      }
    }

    final nodeStart = DateTime.now();
    Timer? heartbeat;
    try {
      heartbeat = Timer.periodic(const Duration(seconds: 10), (_) {
        final elapsed = DateTime.now().difference(nodeStart);
        final mm = elapsed.inMinutes.toString().padLeft(2, '0');
        final ss = (elapsed.inSeconds % 60).toString().padLeft(2, '0');
        _addLog(tabId, '   ⏱️  ${node.title} still running... $mm:$ss elapsed');
      });

      final inputFiles = <String, String>{};
      final upstreamOutputs = <String, String>{};
      final upstreamInputs = <String, List<String>>{};
      final upstreamConnections = ctx.upstreamConnections(node.id);

      for (int connIdx = 0; connIdx < upstreamConnections.length; connIdx++) {
        final connection = upstreamConnections[connIdx];
        final upstreamNodeId = connection.fromNodeId;
        final upstreamTitle =
            session.nodes.firstWhere((n) => n.id == upstreamNodeId).title;

        if (nodeOutputs.containsKey(upstreamNodeId)) {
          final key =
              'file_${connIdx + 1}_${_nodeIdFragment(upstreamNodeId)}';
          final filePath = nodeOutputs[upstreamNodeId]!;
          inputFiles[key] = filePath;
          upstreamOutputs[upstreamTitle] = filePath;

          _addLog(tabId, '   📥 Input ${connIdx + 1} from "$upstreamTitle"');
          _addLog(tabId, '      Host path : $filePath');
          final fileName = filePath.split(Platform.pathSeparator).last;
          _addLog(
            tabId,
            '      In-container: /inputs/$fileName  (\$INPUT_FILE_${connIdx + 1})',
          );
        }

        if (nodeInputs.containsKey(upstreamNodeId)) {
          upstreamInputs[upstreamTitle] = nodeInputs[upstreamNodeId]!;
        }
      }

      nodeInputs[node.id] = inputFiles.values.toList();

      await pipelineCtrl.executeNode(
        node.id,
        inputFiles: inputFiles,
        upstreamOutputs: upstreamOutputs,
        upstreamInputs: upstreamInputs,
        pipelineName: session.pipelineName,
        executionContext: ctx,
        executionIdentity: identity,
      );
    } finally {
      heartbeat?.cancel();
    }

    if (!_isRunActive(tabId, runToken)) return false;

    final totalElapsed = DateTime.now().difference(nodeStart);
    final mm = totalElapsed.inMinutes.toString().padLeft(2, '0');
    final ss = (totalElapsed.inSeconds % 60).toString().padLeft(2, '0');
    _addLog(tabId, '   ⏱️  ${node.title} finished in $mm:$ss');

    if (node.status == BlockStatus.success) {
      _addLog(tabId, '   ✅ ${node.title} completed successfully');

      final outputParam = node.parameters.firstWhereOrNull(
        (p) => p.key == '_output_file',
      );

      if (outputParam?.value != null) {
        final path = outputParam!.value.toString();
        final isInputNode = node.category == BlockCategory.input;
        final isOutputNode = node.category == BlockCategory.output;

        if (isInputNode || isOutputNode) {
          _addLog(tabId, '   📄 File: $path');
          nodeOutputs[node.id] = path;
        } else {
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
                _addLog(
                  tabId,
                  '      ${f.uri.pathSegments.last}  ($kb KB)',
                );
              }
            } else {
              _addLog(
                tabId,
                '   ℹ️  No files found in output folder. '
                'Make sure your command writes to /outputs/.',
              );
            }
          } catch (_) {}

          nodeOutputs[node.id] = outDir.path;
        }
      }

      _addLog(tabId, '');
      return true;
    }

    _addLog(tabId, '   ❌ ${node.title} execution failed');
    final stderrLines = node.logs
        .where((l) => l.startsWith('[STDERR]') || l.startsWith('[ERROR]'))
        .toList();
    final stdoutLines = node.logs
        .where((l) => l.startsWith('[STDOUT]') || l.startsWith('[SYSTEM]'))
        .take(3)
        .toList();
    final logsToShow = stderrLines.isNotEmpty ? stderrLines : stdoutLines;
    for (final line in logsToShow.take(20)) {
      _addLog(tabId, '   $line');
    }
    if (logsToShow.length > 20) {
      _addLog(
        tabId,
        '   ... (+${logsToShow.length - 20} more lines — check node logs for full output)',
      );
    }
    if (logsToShow.isEmpty) {
      _addLog(
        tabId,
        '   (No output captured. The container may have exited immediately or the command was empty.)',
      );
    }

    _addLog(tabId, '');
    if (announcePipelineStop) {
      _addLog(
        tabId,
        '⚠️ Pipeline execution stopped due to failure in ${node.title}',
      );
    }
    return false;
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
  Future<void> stopPipeline() async {
    final tabId = _currentTabId;
    if (tabId == null) return;
    if (_isRunningByTab[tabId] != true) return;

    _invalidateRun(tabId);
    _addLog(tabId, '🛑 Stop requested by user...');

    final pipelineCtrl = Get.find<PipelineController>();
    final runtimeStore = Get.find<PipelineTabRuntimeStore>();
    final tabsCtrl = Get.find<PipelineTabsController>();
    final session = runtimeStore.sessionFor(tabId);
    final stopFutures = <Future<void>>[];

    final nodesToStop = session?.nodes ?? pipelineCtrl.nodes;
    for (final node in nodesToStop) {
      if (node.status == BlockStatus.running) {
        stopFutures.add(
          pipelineCtrl.stopNode(
            node.id,
            executionContext: session?.context,
            executionIdentity: NodeExecutionIdentity(
              tabId: tabId,
              nodeId: node.id,
              nodeTitle: node.title,
            ),
          ),
        );
      }
    }
    if (stopFutures.isNotEmpty) {
      await Future.wait(stopFutures);
    }

    final tab = tabsCtrl.tabs.firstWhereOrNull((t) => t.id == tabId);
    if (session != null && tab != null) {
      runtimeStore.finalizeSession(
        tabId: tabId,
        session: session,
        controller: pipelineCtrl,
        activeTabId: tabsCtrl.activeTabId.value,
        file: tab,
      );
    } else {
      runtimeStore.cancelSession(tabId);
    }

    _addLog(tabId, '⚠️ Pipeline was stopped by user.');
    if (Get.isRegistered<SettingsController>()) {
      Get.find<SettingsController>().setParallelRunActive(false);
    }
    _setRunning(tabId, false);
  }
}
