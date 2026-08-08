import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:get/get.dart';

import 'package:Ricochet/controllers/execution_controller.dart';
import 'package:Ricochet/controllers/pipeline_controller.dart';
import 'package:Ricochet/models/pipeline_node.dart';
import 'package:Ricochet/models/pipeline_preflight_issue.dart';
import 'package:Ricochet/services/ai_pipeline_preflight_service.dart';

PipelineNode _inputNode(String id, {List<String> files = const []}) =>
    PipelineNode(
      id: id,
      title: 'Input Data',
      description: '',
      position: Offset.zero,
      category: BlockCategory.input,
      iconCodePoint: '0xe2c7',
      outputPorts: const ['data'],
      parameters: [
        BlockParameter(
          key: 'files',
          label: 'Input Files',
          type: ParameterType.multiFile,
          value: files,
        ),
      ],
    );

PipelineNode _outputNode(String id) => PipelineNode(
      id: id,
      title: 'Output Results',
      description: '',
      position: Offset.zero,
      category: BlockCategory.output,
      iconCodePoint: '0xe2c6',
      parameters: const [],
    );

PipelineNode _dockerNode(
  String id, {
  String title = 'Samtools',
  String? command,
  BlockStatus status = BlockStatus.idle,
  bool isImageLocal = false,
  String? downloadStatus,
  BlockCategory category = BlockCategory.processing,
}) =>
    PipelineNode(
      id: id,
      title: title,
      description: '',
      position: Offset.zero,
      category: category,
      iconCodePoint: '0xe8d5',
      dockerImage: 'biocontainers/samtools:latest',
      status: status,
      isImageLocal: isImageLocal,
      downloadStatus: downloadStatus,
      parameters: [
        BlockParameter(
          key: 'image',
          label: 'Docker Image',
          type: ParameterType.text,
          value: 'biocontainers/samtools:latest',
        ),
        BlockParameter(
          key: 'command',
          label: 'Command',
          type: ParameterType.text,
          value: command,
        ),
      ],
    );

void main() {
  late PipelineController pipeline;
  late AiPipelinePreflightService preflight;

  setUp(() {
    Get.testMode = true;
    pipeline = Get.put(PipelineController());
    Get.put(ExecutionController());
    preflight = AiPipelinePreflightService();
  });

  tearDown(() => Get.deleteAll(force: true));

  test('empty canvas reports a blocker', () {
    final issues = preflight.collectIssues();
    expect(issues, isNotEmpty);
    expect(issues.first.severity, PreflightSeverity.blocker);
    expect(issues.first.message, contains('Canvas is empty'));
  });

  test('input node with no files attached is a blocker', () {
    pipeline.nodes.value = [_inputNode('in1')];

    final issues = preflight.collectIssues();
    expect(
      issues.any((i) =>
          i.severity == PreflightSeverity.blocker &&
          i.message.contains('no files attached')),
      isTrue,
    );
  });

  test('input node with files attached does not block on missing files', () {
    pipeline.nodes.value = [_inputNode('in1', files: ['sample.fastq'])];

    final issues = preflight.collectIssues();
    expect(issues.any((i) => i.message.contains('no files attached')), isFalse);
  });

  test('pipeline with processing node but no input node is a blocker', () {
    pipeline.nodes.value = [_dockerNode('p1', command: 'samtools sort \$INPUT_FILE')];

    final issues = preflight.collectIssues();
    expect(
      issues.any((i) =>
          i.severity == PreflightSeverity.blocker &&
          i.message.contains('No Input node found')),
      isTrue,
    );
  });

  test('pipeline with no output node is a warning, not a blocker', () {
    pipeline.nodes.value = [
      _inputNode('in1', files: ['a.fastq']),
      _dockerNode('p1', command: 'samtools sort \$INPUT_FILE'),
    ];
    pipeline.connections.value = [
      Connection(id: 'c1', fromNodeId: 'in1', toNodeId: 'p1'),
    ];

    final issues = preflight.collectIssues();
    final outputIssue = issues.firstWhere(
      (i) => i.message.contains('No Output node found'),
    );
    expect(outputIssue.severity, PreflightSeverity.warning);
  });

  test('node with no incoming connection in multi-node pipeline is a blocker', () {
    pipeline.nodes.value = [
      _inputNode('in1', files: ['a.fastq']),
      _dockerNode('p1', command: 'samtools sort \$INPUT_FILE'),
      _outputNode('out1'),
    ];
    // p1 is never wired to in1 or out1.
    pipeline.connections.value = [];

    final issues = preflight.collectIssues();
    expect(
      issues.any((i) =>
          i.severity == PreflightSeverity.blocker &&
          i.message.contains('Node "Samtools" has no incoming connection')),
      isTrue,
    );
  });

  test('output node with nothing feeding it is a blocker', () {
    pipeline.nodes.value = [
      _inputNode('in1', files: ['a.fastq']),
      _dockerNode('p1', command: 'samtools sort \$INPUT_FILE'),
      _outputNode('out1'),
    ];
    pipeline.connections.value = [
      Connection(id: 'c1', fromNodeId: 'in1', toNodeId: 'p1'),
    ];

    final issues = preflight.collectIssues();
    expect(
      issues.any((i) =>
          i.severity == PreflightSeverity.blocker &&
          i.message.contains('Output node "Output Results" has nothing connected')),
      isTrue,
    );
  });

  test('fully wired pipeline with local docker image has no blockers', () {
    pipeline.nodes.value = [
      _inputNode('in1', files: ['a.fastq']),
      _dockerNode('p1', command: 'samtools sort \$INPUT_FILE', isImageLocal: true),
      _outputNode('out1'),
    ];
    pipeline.connections.value = [
      Connection(id: 'c1', fromNodeId: 'in1', toNodeId: 'p1'),
      Connection(id: 'c2', fromNodeId: 'p1', toNodeId: 'out1'),
    ];

    final issues = preflight.collectIssues();
    expect(issues.where((i) => i.severity == PreflightSeverity.blocker), isEmpty);
    expect(preflight.isReady, isTrue);
  });

  test('docker image not pulled yet is a warning', () {
    pipeline.nodes.value = [
      _inputNode('in1', files: ['a.fastq']),
      _dockerNode('p1', command: 'samtools sort \$INPUT_FILE', isImageLocal: false),
      _outputNode('out1'),
    ];
    pipeline.connections.value = [
      Connection(id: 'c1', fromNodeId: 'in1', toNodeId: 'p1'),
      Connection(id: 'c2', fromNodeId: 'p1', toNodeId: 'out1'),
    ];

    final issues = preflight.collectIssues();
    final warning = issues.firstWhere((i) => i.message.contains("hasn't been pulled yet"));
    expect(warning.severity, PreflightSeverity.warning);
  });

  test('docker node previously failed is a blocker with the failure detail', () {
    pipeline.nodes.value = [
      _inputNode('in1', files: ['a.fastq']),
      _dockerNode(
        'p1',
        command: 'samtools sort \$INPUT_FILE',
        status: BlockStatus.error,
        downloadStatus: 'manifest unknown',
      ),
      _outputNode('out1'),
    ];
    pipeline.connections.value = [
      Connection(id: 'c1', fromNodeId: 'in1', toNodeId: 'p1'),
      Connection(id: 'c2', fromNodeId: 'p1', toNodeId: 'out1'),
    ];

    final issues = preflight.collectIssues();
    final failure = issues.firstWhere((i) => i.message.contains('manifest unknown'));
    expect(failure.severity, PreflightSeverity.blocker);
  });

  test('command missing \$INPUT_FILE despite upstream data is a warning', () {
    pipeline.nodes.value = [
      _inputNode('in1', files: ['a.fastq']),
      _dockerNode('p1', command: 'samtools sort out.bam', isImageLocal: true),
      _outputNode('out1'),
    ];
    pipeline.connections.value = [
      Connection(id: 'c1', fromNodeId: 'in1', toNodeId: 'p1'),
      Connection(id: 'c2', fromNodeId: 'p1', toNodeId: 'out1'),
    ];

    final issues = preflight.collectIssues();
    final warning = issues.firstWhere(
      (i) => i.message.contains("doesn't reference \$INPUT_FILE"),
    );
    expect(warning.severity, PreflightSeverity.warning);
  });

  group('pipelineSignature', () {
    test('is stable when nothing changes', () {
      pipeline.nodes.value = [_inputNode('in1', files: ['a.fastq'])];
      final a = preflight.pipelineSignature();
      final b = preflight.pipelineSignature();
      expect(a, equals(b));
    });

    test('changes when a parameter value changes', () {
      pipeline.nodes.value = [_inputNode('in1', files: ['a.fastq'])];
      final before = preflight.pipelineSignature();

      pipeline.nodes.value = [_inputNode('in1', files: ['a.fastq', 'b.fastq'])];
      final after = preflight.pipelineSignature();

      expect(before, isNot(equals(after)));
    });

    test('changes when connections change', () {
      pipeline.nodes.value = [
        _inputNode('in1', files: ['a.fastq']),
        _outputNode('out1'),
      ];
      final before = preflight.pipelineSignature();

      pipeline.connections.value = [
        Connection(id: 'c1', fromNodeId: 'in1', toNodeId: 'out1'),
      ];
      final after = preflight.pipelineSignature();

      expect(before, isNot(equals(after)));
    });
  });
}
