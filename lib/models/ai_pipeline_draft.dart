import 'package:flutter/material.dart';

import 'pipeline_template.dart';

/// Parsed pipeline JSON from the AI model (no coordinates).
class AiPipelineDraft {
  final List<AiDraftNodeDef> nodes;
  final List<AiDraftConnectionDef> connections;

  const AiPipelineDraft({
    required this.nodes,
    required this.connections,
  });

  int get nodeCount => nodes.length;
}

/// Single node definition returned by the model.
class AiDraftNodeDef {
  final String nodeType;
  final Map<String, dynamic> parameterOverrides;

  const AiDraftNodeDef({
    required this.nodeType,
    this.parameterOverrides = const {},
  });

  TemplateNodeDef toTemplateDef(Offset position) => TemplateNodeDef(
        nodeType: nodeType,
        position: position,
        parameterOverrides: parameterOverrides,
      );
}

/// Connection between draft nodes by list index.
class AiDraftConnectionDef {
  final int fromIndex;
  final int toIndex;

  const AiDraftConnectionDef({
    required this.fromIndex,
    required this.toIndex,
  });
}

/// Result of validating a draft before ghosts are shown.
class AiPipelineValidationResult {
  final bool isValid;
  final String? errorMessage;
  final List<int> unknownNodeIndices;

  const AiPipelineValidationResult.valid({
    this.unknownNodeIndices = const [],
  })  : isValid = true,
        errorMessage = null;

  const AiPipelineValidationResult.invalid(
    String message, {
    this.unknownNodeIndices = const [],
  })  : isValid = false,
        errorMessage = message;
}

/// Layout output for ghost positioning on the canvas.
class AiPipelineLayoutResult {
  final Map<int, Offset> positionsByIndex;
  final int overflowCount;
  final int overflowScrollToIndex;
  final Offset? summaryGhostPosition;

  const AiPipelineLayoutResult({
    required this.positionsByIndex,
    this.overflowCount = 0,
    this.overflowScrollToIndex = 0,
    this.summaryGhostPosition,
  });

  bool get hasSummaryGhost => overflowCount > 0;
}

String extractJsonPayload(String raw) {
  var text = raw.trim();
  if (text.startsWith('```')) {
    final lines = text.split('\n');
    if (lines.length >= 2) {
      var end = lines.length;
      if (lines.last.trim() == '```') end = lines.length - 1;
      text = lines.sublist(1, end).join('\n').trim();
    }
  }

  final start = text.indexOf('{');
  final end = text.lastIndexOf('}');
  if (start >= 0 && end > start) {
    return text.substring(start, end + 1);
  }
  return text;
}
