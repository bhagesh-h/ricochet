import '../models/ai_pipeline_draft.dart';

/// Validates AI pipeline drafts before ghosts are rendered.
class AiPipelineValidator {
  static const builtInNodeTypes = {
    'Input',
    'Output',
    'FastQC',
    'Trimmomatic',
    'BWA',
    'STAR',
    'Samtools',
  };

  AiPipelineValidationResult validate(AiPipelineDraft draft) {
    if (draft.nodes.isEmpty) {
      return const AiPipelineValidationResult.invalid(
        'Pipeline must include at least one node.',
      );
    }

    final hasInput =
        draft.nodes.any((n) => n.nodeType == 'Input');
    final hasOutput =
        draft.nodes.any((n) => n.nodeType == 'Output');
    if (!hasInput || !hasOutput) {
      return const AiPipelineValidationResult.invalid(
        'Pipeline must include both an Input and an Output node.',
      );
    }

    for (final conn in draft.connections) {
      if (conn.fromIndex < 0 ||
          conn.toIndex < 0 ||
          conn.fromIndex >= draft.nodes.length ||
          conn.toIndex >= draft.nodes.length) {
        return const AiPipelineValidationResult.invalid(
          'A connection references a node that does not exist.',
        );
      }
      if (conn.fromIndex == conn.toIndex) {
        return const AiPipelineValidationResult.invalid(
          'A node cannot connect to itself.',
        );
      }
    }

    if (_hasCycle(draft)) {
      return const AiPipelineValidationResult.invalid(
        'Pipeline contains a cycle. Connections must flow forward without loops.',
      );
    }

    final unknown = <int>[];
    for (var i = 0; i < draft.nodes.length; i++) {
      final type = draft.nodes[i].nodeType;
      if (builtInNodeTypes.contains(type)) continue;
      if (type.startsWith('docker:')) continue;
      unknown.add(i);
    }

    return AiPipelineValidationResult.valid(unknownNodeIndices: unknown);
  }

  bool _hasCycle(AiPipelineDraft draft) {
    final adjacency = <int, List<int>>{
      for (var i = 0; i < draft.nodes.length; i++) i: [],
    };
    for (final conn in draft.connections) {
      adjacency[conn.fromIndex]!.add(conn.toIndex);
    }

    final visited = <int>{};
    final stack = <int>{};

    bool dfs(int node) {
      visited.add(node);
      stack.add(node);
      for (final next in adjacency[node]!) {
        if (!visited.contains(next)) {
          if (dfs(next)) return true;
        } else if (stack.contains(next)) {
          return true;
        }
      }
      stack.remove(node);
      return false;
    }

    for (var i = 0; i < draft.nodes.length; i++) {
      if (!visited.contains(i) && dfs(i)) return true;
    }
    return false;
  }
}
