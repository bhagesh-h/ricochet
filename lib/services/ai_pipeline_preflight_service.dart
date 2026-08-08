import 'package:get/get.dart';

import '../controllers/execution_controller.dart';
import '../controllers/pipeline_controller.dart';
import '../models/pipeline_node.dart';
import '../models/pipeline_preflight_issue.dart';

/// Structural pipeline checks reused for execute validation and AI review.
///
/// [collectIssues] performs a much deeper structural pass than the plain
/// execute-time validation: it checks that input nodes actually have files
/// attached, that every node is wired correctly (not just "connected to
/// something"), that Docker images are actually ready, and other footguns
/// that would otherwise only surface after clicking "Execute".
class AiPipelinePreflightService {
  List<PipelinePreflightIssue> collectIssues() {
    final exec = Get.find<ExecutionController>();
    final pipeline = Get.find<PipelineController>();

    final issues = <PipelinePreflightIssue>[
      for (final raw in exec.validatePipeline()) _classifyLegacyIssue(raw),
    ];

    if (pipeline.nodes.isEmpty) {
      // validatePipeline() already reported the empty-canvas blocker and
      // returned early — nothing else to check.
      return issues;
    }

    if (pipeline.cycleConnectionIds.isNotEmpty) {
      issues.add(const PipelinePreflightIssue(
        message:
            'Pipeline contains cycles (loops). Ricochet only supports directed acyclic graphs.',
        severity: PreflightSeverity.blocker,
      ));
    }

    issues.addAll(_checkInputFiles(pipeline));
    issues.addAll(_checkIoNodesPresent(pipeline));
    issues.addAll(_checkNodeWiring(pipeline));
    issues.addAll(_checkDockerReadiness(pipeline));
    issues.addAll(_checkCommandUsesUpstreamData(pipeline));

    return issues;
  }

  /// True when there are no blocking issues (warnings/info are allowed).
  bool get isReady =>
      collectIssues().every((i) => i.severity != PreflightSeverity.blocker);

  int blockerCount(List<PipelinePreflightIssue> issues) =>
      issues.where((i) => i.severity == PreflightSeverity.blocker).length;

  int warningCount(List<PipelinePreflightIssue> issues) =>
      issues.where((i) => i.severity == PreflightSeverity.warning).length;

  String summaryContext() {
    final pipeline = Get.find<PipelineController>();
    final dockerNodes =
        pipeline.nodes.where((n) => n.dockerImage != null).length;
    return 'Nodes: ${pipeline.nodes.length}, '
        'Connections: ${pipeline.connections.length}, '
        'Docker nodes: $dockerNodes';
  }

  /// A cheap, deterministic fingerprint of the current pipeline's shape and
  /// configuration. Two calls return the same value iff nothing that would
  /// change the review's outcome has changed (nodes, params, wiring, docker
  /// readiness). Used to cache AI review results and only recompute when the
  /// pipeline actually changed.
  String pipelineSignature() {
    final pipeline = Get.find<PipelineController>();
    final buffer = StringBuffer();
    for (final node in pipeline.nodes) {
      buffer
        ..write(node.id)
        ..write(':')
        ..write(node.dockerImage ?? '')
        ..write(':')
        ..write(node.status.name)
        ..write(':')
        ..write(node.isImageLocal)
        ..write(':')
        ..write(node.downloadStatus ?? '');
      for (final p in node.parameters) {
        buffer
          ..write('|')
          ..write(p.key)
          ..write('=')
          ..write(_paramFingerprint(p.value));
      }
      buffer.write(';');
    }
    buffer.write('#');
    for (final c in pipeline.connections) {
      buffer
        ..write(c.fromNodeId)
        ..write('->')
        ..write(c.toNodeId)
        ..write(':')
        ..write(c.fromPort)
        ..write('>')
        ..write(c.toPort)
        ..write(';');
    }
    return buffer.toString();
  }

  String _paramFingerprint(dynamic value) {
    if (value is List) return value.join(',');
    return value?.toString() ?? '';
  }

  PipelinePreflightIssue _classifyLegacyIssue(String message) {
    final severity = message.startsWith('🔗')
        ? PreflightSeverity.warning
        : PreflightSeverity.blocker;
    return PipelinePreflightIssue(message: message, severity: severity);
  }

  /// Input nodes exist to feed files into the pipeline — if none of them
  /// have a file attached, nothing downstream can run.
  List<PipelinePreflightIssue> _checkInputFiles(PipelineController pipeline) {
    final issues = <PipelinePreflightIssue>[];
    final inputNodes =
        pipeline.nodes.where((n) => n.category == BlockCategory.input);

    for (final node in inputNodes) {
      final files = _filesAttached(node);
      if (files.isEmpty) {
        issues.add(PipelinePreflightIssue(
          message:
              '📁 Input node "${node.title}" has no files attached. Attach at least one file before running.',
          severity: PreflightSeverity.blocker,
          nodeId: node.id,
        ));
      }
    }
    return issues;
  }

  List<String> _filesAttached(PipelineNode node) {
    final multiParam =
        node.parameters.firstWhereOrNull((p) => p.type == ParameterType.multiFile);
    if (multiParam != null) {
      final value = multiParam.value;
      if (value is List) {
        return value
            .map((e) => e.toString().trim())
            .where((s) => s.isNotEmpty)
            .toList();
      }
      return const [];
    }
    final fileParam =
        node.parameters.firstWhereOrNull((p) => p.type == ParameterType.file);
    final single = fileParam?.value?.toString().trim() ?? '';
    if (single.isNotEmpty) return [single];

    // Legacy fallback used by older saved pipelines.
    final legacy =
        node.parameters.firstWhereOrNull((p) => p.key == 'file_path');
    final legacyValue = legacy?.value?.toString().trim() ?? '';
    return legacyValue.isNotEmpty ? [legacyValue] : const [];
  }

  /// A pipeline with processing/analysis steps but no Input node (or any
  /// file-bearing parameter) has nothing to work on. A pipeline with no
  /// Output node will run but silently produce nothing users can retrieve.
  List<PipelinePreflightIssue> _checkIoNodesPresent(
      PipelineController pipeline) {
    final issues = <PipelinePreflightIssue>[];
    final hasInputNode =
        pipeline.nodes.any((n) => n.category == BlockCategory.input);
    final hasOutputNode =
        pipeline.nodes.any((n) => n.category == BlockCategory.output);
    final hasWorkNodes = pipeline.nodes.any((n) =>
        n.category != BlockCategory.input && n.category != BlockCategory.output);

    if (hasWorkNodes && !hasInputNode) {
      issues.add(const PipelinePreflightIssue(
        message:
            '📁 No Input node found. Add one and attach files, otherwise there is no data for the pipeline to process.',
        severity: PreflightSeverity.blocker,
      ));
    }

    if (hasWorkNodes && !hasOutputNode) {
      issues.add(const PipelinePreflightIssue(
        message:
            '📤 No Output node found. Results will run but won\'t be exported anywhere unless you add one.',
        severity: PreflightSeverity.warning,
      ));
    }

    return issues;
  }

  /// Beyond "is this node connected to *anything*", check the *direction* of
  /// wiring: nodes that consume data need an incoming connection, Output
  /// nodes with nothing feeding them export nothing, and dead-end nodes
  /// (output not consumed, and not an Output node) likely indicate a
  /// forgotten wire.
  List<PipelinePreflightIssue> _checkNodeWiring(PipelineController pipeline) {
    if (pipeline.nodes.length < 2) return const [];
    final issues = <PipelinePreflightIssue>[];

    for (final node in pipeline.nodes) {
      final hasIncoming =
          pipeline.connections.any((c) => c.toNodeId == node.id);
      final hasOutgoing =
          pipeline.connections.any((c) => c.fromNodeId == node.id);

      if (node.category == BlockCategory.output) {
        if (!hasIncoming) {
          issues.add(PipelinePreflightIssue(
            message:
                '🔗 Output node "${node.title}" has nothing connected to it, so there is nothing to export.',
            severity: PreflightSeverity.blocker,
            nodeId: node.id,
          ));
        }
        continue;
      }

      if (node.category != BlockCategory.input && !hasIncoming) {
        issues.add(PipelinePreflightIssue(
          message:
              '🔗 Node "${node.title}" has no incoming connection — it will run without any upstream data.',
          severity: PreflightSeverity.blocker,
          nodeId: node.id,
        ));
      }

      if (node.category != BlockCategory.output &&
          !hasOutgoing &&
          hasIncoming) {
        issues.add(PipelinePreflightIssue(
          message:
              '🔗 Node "${node.title}" output isn\'t connected to anything downstream. Add an Output node (or a next step) so its results aren\'t lost.',
          severity: PreflightSeverity.warning,
          nodeId: node.id,
        ));
      }
    }

    return issues;
  }

  /// Docker nodes need a resolvable image before they can run. Flag ones
  /// that are known to have failed previously or aren't confirmed local yet.
  List<PipelinePreflightIssue> _checkDockerReadiness(
      PipelineController pipeline) {
    final issues = <PipelinePreflightIssue>[];
    for (final node in pipeline.nodes) {
      if (node.dockerImage == null) continue;

      if (node.status == BlockStatus.error ||
          node.status == BlockStatus.failed) {
        final detail = (node.downloadStatus ?? '').trim();
        issues.add(PipelinePreflightIssue(
          message: detail.isNotEmpty
              ? '🐳 Node "${node.title}" previously failed: $detail'
              : '🐳 Node "${node.title}" is in an error state and needs attention before running.',
          severity: PreflightSeverity.blocker,
          nodeId: node.id,
        ));
      } else if (!node.isImageLocal) {
        issues.add(PipelinePreflightIssue(
          message:
              '🐳 Docker image for "${node.title}" hasn\'t been pulled yet. It will be downloaded on first run — make sure you have network access.',
          severity: PreflightSeverity.warning,
          nodeId: node.id,
        ));
      }
    }
    return issues;
  }

  /// If a node has upstream data but its command never references it, the
  /// author probably forgot to wire the variable in — a common mistake.
  List<PipelinePreflightIssue> _checkCommandUsesUpstreamData(
      PipelineController pipeline) {
    final issues = <PipelinePreflightIssue>[];
    for (final node in pipeline.nodes) {
      if (node.dockerImage == null) continue;
      final hasIncoming =
          pipeline.connections.any((c) => c.toNodeId == node.id);
      if (!hasIncoming) continue;

      final commandParam =
          node.parameters.firstWhereOrNull((p) => p.key == 'command');
      final command = commandParam?.value?.toString() ?? '';
      if (command.trim().isEmpty) continue; // already flagged elsewhere

      if (!command.contains(r'$INPUT_FILE') && !command.contains('/inputs/')) {
        issues.add(PipelinePreflightIssue(
          message:
              '⌨️ Node "${node.title}" has upstream input but its command doesn\'t reference \$INPUT_FILE — double-check it actually uses the incoming data.',
          severity: PreflightSeverity.warning,
          nodeId: node.id,
        ));
      }
    }
    return issues;
  }
}
