import 'dart:convert';

import '../models/ai_pipeline_draft.dart';

class AiPipelineParseException implements Exception {
  final String message;
  const AiPipelineParseException(this.message);

  @override
  String toString() => message;
}

/// Parses model output into [AiPipelineDraft].
class AiPipelineParser {
  AiPipelineDraft parse(String raw) {
    final jsonText = extractJsonPayload(raw);
    if (jsonText.trim().isEmpty) {
      throw const AiPipelineParseException('Model returned empty pipeline JSON.');
    }

    final dynamic decoded;
    try {
      decoded = jsonDecode(jsonText);
    } catch (_) {
      throw const AiPipelineParseException(
        'Could not parse pipeline JSON. Try regenerating.',
      );
    }

    if (decoded is! Map<String, dynamic>) {
      throw const AiPipelineParseException('Pipeline JSON must be an object.');
    }

    final nodesRaw = decoded['nodes'];
    if (nodesRaw is! List || nodesRaw.isEmpty) {
      throw const AiPipelineParseException(
        'Pipeline must include at least one node.',
      );
    }

    final nodes = <AiDraftNodeDef>[];
    for (final entry in nodesRaw) {
      if (entry is! Map) {
        throw const AiPipelineParseException('Each node must be an object.');
      }
      final nodeType = entry['nodeType']?.toString().trim() ?? '';
      if (nodeType.isEmpty) {
        throw const AiPipelineParseException('Each node needs a nodeType.');
      }
      final overrides = entry['parameterOverrides'];
      nodes.add(
        AiDraftNodeDef(
          nodeType: nodeType,
          parameterOverrides: overrides is Map
              ? Map<String, dynamic>.from(overrides)
              : const {},
        ),
      );
    }

    final connections = <AiDraftConnectionDef>[];
    final connectionsRaw = decoded['connections'];
    if (connectionsRaw is List) {
      for (final entry in connectionsRaw) {
        if (entry is! Map) continue;
        final from = _readIndex(entry['from'] ?? entry['fromIndex']);
        final to = _readIndex(entry['to'] ?? entry['toIndex']);
        if (from == null || to == null) continue;
        connections.add(AiDraftConnectionDef(fromIndex: from, toIndex: to));
      }
    }

    return AiPipelineDraft(nodes: nodes, connections: connections);
  }

  int? _readIndex(dynamic value) {
    if (value is int) return value;
    if (value is num) return value.toInt();
    return int.tryParse(value?.toString() ?? '');
  }
}
