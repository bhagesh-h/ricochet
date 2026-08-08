import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:Ricochet/models/ai_prompt_bundle.dart';
import 'package:Ricochet/models/pipeline_node.dart';
import 'package:Ricochet/services/ai_prompt_builder.dart';

PipelineNode _node(
  String id, {
  String title = 'Node',
  BlockCategory category = BlockCategory.processing,
  String? dockerImage,
  List<BlockParameter> parameters = const [],
}) =>
    PipelineNode(
      id: id,
      title: title,
      description: '',
      position: Offset.zero,
      category: category,
      iconCodePoint: '0xe8d5',
      dockerImage: dockerImage,
      parameters: parameters,
    );

void main() {
  group('extractShellCommand', () {
    test('returns plain text unchanged', () {
      expect(extractShellCommand('samtools sort -o /outputs/out.bam'), 'samtools sort -o /outputs/out.bam');
    });

    test('strips markdown fence', () {
      const raw = '```bash\nfastqc \$INPUT_FILE -o /outputs/\n```';
      expect(extractShellCommand(raw), 'fastqc \$INPUT_FILE -o /outputs/');
    });
  });

  group('AiPromptBuilder.forCommand', () {
    test('includes upstream nodes and draft command', () {
      final upstream = _node(
        'u1',
        title: 'QC',
        category: BlockCategory.input,
        parameters: [
          BlockParameter(
            key: 'files',
            label: 'Files',
            type: ParameterType.multiFile,
            value: ['sample.fastq.gz'],
          ),
        ],
      );
      final target = _node('t1', title: 'Align', dockerImage: 'biocontainers/samtools');
      final bundle = AiPromptBuilder.forCommand(
        targetNode: target,
        allNodes: [upstream, target],
        connections: [
          Connection(id: 'c1', fromNodeId: 'u1', toNodeId: 't1'),
        ],
        partialCommand: 'samtools sort',
      );

      final user = bundle.baseMessages.last['content']!;
      expect(user, contains('Target node: Align'));
      expect(user, contains('Docker image: biocontainers/samtools'));
      expect(user, contains('Direct upstream nodes:'));
      expect(user, contains('- QC (input)'));
      expect(user, contains('files: gz'));
      expect(user, contains('User draft command:\nsamtools sort'));
      expect(bundle.contextTruncated, isFalse);
    });

    test('sets truncation footer when caps exceeded', () {
      final upstream = List.generate(
        5,
        (i) => _node('u$i', title: 'Up $i'),
      );
      final others = List.generate(
        12,
        (i) => _node('o$i', title: 'Other $i'),
      );
      final target = _node('t1', title: 'Target');
      final partial = 'x' * 600;

      final bundle = AiPromptBuilder.forCommand(
        targetNode: target,
        allNodes: [...upstream, ...others, target],
        connections: [
          for (var i = 0; i < upstream.length; i++)
            Connection(id: 'c$i', fromNodeId: upstream[i].id, toNodeId: 't1'),
        ],
        partialCommand: partial,
      );

      expect(bundle.contextTruncated, isTrue);
      final user = bundle.baseMessages.last['content']!;
      expect(user, contains('[Context truncated:'));
      expect(user, contains('3 nearest upstream'));
    });
  });

  group('extractSearchQuery', () {
    test('strips quotes and whitespace', () {
      expect(extractSearchQuery('"bwa mem"'), 'bwa mem');
    });
  });

  group('buildLogExcerpt', () {
    test('prioritizes stderr lines and caps length', () {
      final logs = [
        '[STDOUT] ok',
        '[STDERR] invalid option',
        '[SYSTEM] exit 1',
      ];
      final excerpt = buildLogExcerpt(logs);
      expect(excerpt, contains('[STDERR]'));
      expect(isLogExcerptTruncated(logs), isFalse);
    });

    test('detects truncation for long logs', () {
      final logs = List.generate(50, (i) => '[STDERR] line $i');
      expect(isLogExcerptTruncated(logs), isTrue);
    });
  });

  group('AiPromptBuilder.forErrorExplain', () {
    test('includes node context and truncation footer', () {
      final messages = AiPromptBuilder.forErrorExplain(
        nodeTitle: 'FastQC',
        dockerImage: 'staphb/fastqc',
        command: 'fastqc /inputs/read.fastq',
        logExcerpt: '[STDERR] command not found',
        truncated: true,
      );
      final user = messages.last['content']!;
      expect(user, contains('Node: FastQC'));
      expect(user, contains('[STDERR] command not found'));
      expect(user, contains('Log excerpt truncated'));
    });
  });

  group('AiPromptBuilder.forDockerSearchAssist', () {
    test('asks for short search query only', () {
      final messages = AiPromptBuilder.forDockerSearchAssist(
        naturalLanguageQuery: 'align RNA-seq reads to human genome',
      );
      expect(messages.last['content'], contains('RNA-seq'));
      expect(messages.last['content'], contains('ONLY'));
    });
  });

  group('AiPromptBundle.regenerateMessages', () {
    test('appends assistant turn and alternate user prompt', () {
      const bundle = AiPromptBundle(
        baseMessages: [
          {'role': 'system', 'content': 'sys'},
          {'role': 'user', 'content': 'ctx'},
        ],
        contextTruncated: false,
        nodeId: 'n1',
        paramKey: 'command',
      );

      final messages = bundle.regenerateMessages('echo old');
      expect(messages.length, 4);
      expect(messages[2], {'role': 'assistant', 'content': 'echo old'});
      expect(messages[3]['content'], contains('different command alternative'));
    });
  });
}
