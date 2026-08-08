import 'package:get/get.dart';

import '../models/ai_prompt_bundle.dart';
import '../models/pipeline_node.dart';
import '../models/pipeline_preflight_issue.dart';

/// Builds capped prompts for command-suggest requests.
class AiPromptBuilder {
  static const int maxUpstreamNodes = 3;
  static const int maxOtherNodeTitles = 10;
  static const int maxPartialCommandChars = 500;

  static const String _rulesSnippet = '''
Ricochet runs Docker containers with these rules:
- Upstream files are available as shell variables: \$INPUT_FILE, \$INPUT_FILE_1, \$INPUT_FILE_2, etc.
- Write all outputs under /outputs/ (mapped to the workspace).
- Raw inputs may appear under /inputs/.
- Return ONLY the shell command to run inside the container — no explanation, no markdown unless wrapping a single command block.
''';

  static AiPromptBundle forCommand({
    required PipelineNode targetNode,
    required List<PipelineNode> allNodes,
    required List<Connection> connections,
    required String partialCommand,
    String paramKey = 'command',
  }) {
    final upstream = _upstreamNodes(
      targetId: targetNode.id,
      allNodes: allNodes,
      connections: connections,
    );

    var upstreamTruncated = false;
    var titlesTruncated = false;
    var partialTruncated = false;

    var upstreamSlice = upstream;
    if (upstream.length > maxUpstreamNodes) {
      upstreamTruncated = true;
      upstreamSlice = upstream.take(maxUpstreamNodes).toList();
    }

    final otherTitles = allNodes
        .where((n) => n.id != targetNode.id)
        .map((n) => n.title)
        .toList();
    var titleSlice = otherTitles;
    if (otherTitles.length > maxOtherNodeTitles) {
      titlesTruncated = true;
      titleSlice = otherTitles.take(maxOtherNodeTitles).toList();
    }

    var partial = partialCommand;
    if (partial.length > maxPartialCommandChars) {
      partialTruncated = true;
      partial = partial.substring(0, maxPartialCommandChars);
    }

    final contextTruncated =
        upstreamTruncated || titlesTruncated || partialTruncated;

    final buffer = StringBuffer()
      ..writeln('Target node: ${targetNode.title}')
      ..writeln('Docker image: ${targetNode.dockerImage ?? 'none'}')
      ..writeln(_rulesSnippet);

    if (upstreamSlice.isNotEmpty) {
      buffer.writeln('\nDirect upstream nodes:');
      for (final node in upstreamSlice) {
        buffer.writeln('- ${node.title} (${node.category.name})');
        final ext = _fileExtensionsSummary(node);
        if (ext.isNotEmpty) buffer.writeln('  files: $ext');
      }
    } else {
      buffer.writeln('\nNo upstream nodes connected yet.');
    }

    if (titleSlice.isNotEmpty) {
      buffer.writeln('\nOther pipeline nodes (titles only): ${titleSlice.join(', ')}');
      if (titlesTruncated) {
        buffer.writeln('(${otherTitles.length - maxOtherNodeTitles} more not shown)');
      }
    }

    if (partial.isNotEmpty) {
      buffer.writeln('\nUser draft command:\n$partial');
    }

    if (contextTruncated) {
      buffer.writeln(
        '\n[Context truncated: showing ${upstreamSlice.length} nearest upstream nodes '
        'and ${titleSlice.length} of ${otherTitles.length} pipeline nodes. '
        'Prioritize the selected node and listed upstream dependencies.]',
      );
    }

    buffer.writeln(
      '\nSuggest a complete runnable shell command for this node.',
    );

    final messages = [
      {
        'role': 'system',
        'content':
            'You are a bioinformatics command-line expert helping Ricochet users write Docker container commands.',
      },
      {'role': 'user', 'content': buffer.toString()},
    ];

    return AiPromptBundle(
      baseMessages: messages,
      contextTruncated: contextTruncated,
      nodeId: targetNode.id,
      paramKey: paramKey,
    );
  }

  static List<PipelineNode> _upstreamNodes({
    required String targetId,
    required List<PipelineNode> allNodes,
    required List<Connection> connections,
  }) {
    final ids = connections
        .where((c) => c.toNodeId == targetId)
        .map((c) => c.fromNodeId);
    return ids
        .map((id) => allNodes.firstWhereOrNull((n) => n.id == id))
        .whereType<PipelineNode>()
        .toList();
  }

  static String _fileExtensionsSummary(PipelineNode node) {
    final extensions = <String>{};
    for (final param in node.parameters) {
      if (param.type == ParameterType.multiFile && param.value is List) {
        for (final path in param.value as List) {
          final ext = _extension(path.toString());
          if (ext.isNotEmpty) extensions.add(ext);
        }
      } else if (param.type == ParameterType.file && param.value != null) {
        final ext = _extension(param.value.toString());
        if (ext.isNotEmpty) extensions.add(ext);
      }
    }
    return extensions.join(', ');
  }

  static String _extension(String path) {
    final dot = path.lastIndexOf('.');
    if (dot <= 0 || dot == path.length - 1) return '';
    return path.substring(dot + 1).toLowerCase();
  }

  static const String _pipelineSchemaSnippet = '''
Return ONLY valid JSON (no markdown unless a single fenced block) matching this schema:
{
  "nodes": [
    {"nodeType": "Input"},
    {"nodeType": "FastQC"},
    {"nodeType": "docker:biocontainers/samtools:latest", "parameterOverrides": {"command": "..."}},
    {"nodeType": "Output"}
  ],
  "connections": [
    {"from": 0, "to": 1},
    {"from": 1, "to": 2}
  ]
}

Rules:
- nodeType must be one of: Input, Output, FastQC, Trimmomatic, BWA, STAR, Samtools, or docker:image:tag
- Do NOT include coordinates
- Pipeline must include Input and Output nodes
- Connections must form a directed acyclic graph flowing from Input toward Output
- Prefer well-known Biocontainers / staphb images when using docker: nodes
''';

  static List<Map<String, String>> forPipelineGenerate({
    required String description,
    bool regenerate = false,
  }) {
    final userContent = StringBuffer()
      ..writeln('Design a bioinformatics pipeline for Ricochet.')
      ..writeln(_pipelineSchemaSnippet)
      ..writeln('\nUser request:\n$description');

    if (regenerate) {
      userContent.writeln(
        '\nThe user wants a different pipeline approach than your previous draft. '
        'Provide an alternative design.',
      );
    }

    return [
      {
        'role': 'system',
        'content':
            'You are a bioinformatics workflow expert helping Ricochet users design Docker-based pipelines.',
      },
      {'role': 'user', 'content': userContent.toString()},
    ];
  }

  static List<Map<String, String>> forErrorExplain({
    required String nodeTitle,
    String? dockerImage,
    String? command,
    required String logExcerpt,
    bool truncated = false,
  }) {
    final buffer = StringBuffer()
      ..writeln('Explain this Ricochet pipeline node failure in plain language.')
      ..writeln('Node: $nodeTitle');
    if (dockerImage != null && dockerImage.isNotEmpty) {
      buffer.writeln('Docker image: $dockerImage');
    }
    if (command != null && command.trim().isNotEmpty) {
      buffer.writeln('Command: $command');
    }
    buffer.writeln('\nRelevant logs:\n$logExcerpt');
    if (truncated) {
      buffer.writeln(
        '\n[Log excerpt truncated — focus on the tail of stderr/system lines.]',
      );
    }
    buffer.writeln(
      '\nRespond with: likely cause, concrete fix steps, and what to check next. '
      'Keep it concise and actionable.',
    );

    return [
      {
        'role': 'system',
        'content':
            'You are a bioinformatics DevOps expert helping users debug Docker pipeline failures.',
      },
      {'role': 'user', 'content': buffer.toString()},
    ];
  }

  static List<Map<String, String>> forDockerSearchAssist({
    required String naturalLanguageQuery,
  }) {
    return [
      {
        'role': 'system',
        'content':
            'You convert natural-language bioinformatics requests into Docker Hub search keywords.',
      },
      {
        'role': 'user',
        'content':
            'Return ONLY a short Docker Hub search query (2-5 words, no punctuation, no explanation) '
            'for this request:\n$naturalLanguageQuery',
      },
    ];
  }

  static List<Map<String, String>> forPipelineReview({
    required List<PipelinePreflightIssue> preflightIssues,
    required String pipelineSummary,
  }) {
    final blockers = preflightIssues
        .where((i) => i.severity == PreflightSeverity.blocker)
        .toList();
    final warnings = preflightIssues
        .where((i) => i.severity == PreflightSeverity.warning)
        .toList();

    final buffer = StringBuffer()
      ..writeln('Review this Ricochet pipeline before execution.')
      ..writeln(pipelineSummary);

    if (preflightIssues.isEmpty) {
      buffer.writeln('\nStructural pre-flight: no blocking issues detected.');
    } else {
      if (blockers.isNotEmpty) {
        buffer.writeln('\nBlocking issues (pipeline will likely fail or run incorrectly):');
        for (final issue in blockers) {
          buffer.writeln('- ${issue.message}');
        }
      }
      if (warnings.isNotEmpty) {
        buffer.writeln('\nWarnings (worth reviewing, not necessarily fatal):');
        for (final issue in warnings) {
          buffer.writeln('- ${issue.message}');
        }
      }
    }

    buffer.writeln(
      '\nGive a concise review: readiness verdict (Ready / Needs fixes / Blocked), top risks, and '
      '2-3 prioritized fixes ordered by impact. Reference the specific node names from the issues above '
      'when relevant. Do not invent file paths or secrets, and do not repeat every issue verbatim — '
      'synthesize them.',
    );

    return [
      {
        'role': 'system',
        'content':
            'You are a bioinformatics pipeline reviewer helping Ricochet users run workflows safely.',
      },
      {'role': 'user', 'content': buffer.toString()},
    ];
  }
}
