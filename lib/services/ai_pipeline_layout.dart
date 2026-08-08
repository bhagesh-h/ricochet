import 'package:flutter/material.dart';

import '../models/ai_pipeline_draft.dart';

/// Auto-layout for AI draft ghosts — grid from (25000, 25000).
class AiPipelineLayout {
  static const Offset origin = Offset(25000, 25000);
  static const int maxNodesPerColumn = 8;
  static const int maxSubColumns = 4;
  static const double levelSpacingX = 295;
  static const double subColumnSpacingX = 140;
  static const double rowSpacingY = 120;
  static const int maxPositionedPerLevel = maxNodesPerColumn * maxSubColumns;

  AiPipelineLayoutResult layout(AiPipelineDraft draft) {
    final levels = _computeLevels(draft);
    final positions = <int, Offset>{};
    var overflowCount = 0;
    var overflowScrollToIndex = 0;
    Offset? summaryGhostPosition;

    for (var levelIndex = 0; levelIndex < levels.length; levelIndex++) {
      final levelNodes = levels[levelIndex];
      final positioned = levelNodes.length > maxPositionedPerLevel
          ? levelNodes.take(maxPositionedPerLevel).toList()
          : levelNodes;

      if (levelNodes.length > maxPositionedPerLevel) {
        overflowCount = levelNodes.length - maxPositionedPerLevel;
        overflowScrollToIndex = levelNodes[maxPositionedPerLevel];
        final subColumn = (maxPositionedPerLevel - 1) ~/ maxNodesPerColumn;
        final row = (maxPositionedPerLevel - 1) % maxNodesPerColumn;
        summaryGhostPosition = Offset(
          origin.dx +
              levelIndex * levelSpacingX +
              subColumn * subColumnSpacingX +
              subColumnSpacingX,
          origin.dy + row * rowSpacingY,
        );
      }

      for (var i = 0; i < positioned.length; i++) {
        final nodeIndex = positioned[i];
        final subColumn = i ~/ maxNodesPerColumn;
        final row = i % maxNodesPerColumn;
        positions[nodeIndex] = Offset(
          origin.dx + levelIndex * levelSpacingX + subColumn * subColumnSpacingX,
          origin.dy + row * rowSpacingY,
        );
      }
    }

    return AiPipelineLayoutResult(
      positionsByIndex: positions,
      overflowCount: overflowCount,
      overflowScrollToIndex: overflowScrollToIndex,
      summaryGhostPosition: summaryGhostPosition,
    );
  }

  List<List<int>> _computeLevels(AiPipelineDraft draft) {
    final inDegree = List<int>.filled(draft.nodes.length, 0);
    final adjacency = <int, List<int>>{
      for (var i = 0; i < draft.nodes.length; i++) i: [],
    };

    for (final conn in draft.connections) {
      adjacency[conn.fromIndex]!.add(conn.toIndex);
      inDegree[conn.toIndex]++;
    }

    final levels = <List<int>>[];
    var queue = <int>[];
    for (var i = 0; i < inDegree.length; i++) {
      if (inDegree[i] == 0) queue.add(i);
    }
    queue.sort();

    var processed = 0;
    while (queue.isNotEmpty) {
      final level = List<int>.from(queue)..sort();
      levels.add(level);
      processed += level.length;
      final next = <int>[];
      for (final node in level) {
        for (final child in adjacency[node]!) {
          inDegree[child]--;
          if (inDegree[child] == 0) next.add(child);
        }
      }
      queue = next..sort();
    }

    if (processed != draft.nodes.length) {
      // Validator should catch cycles; fall back to a single column.
      return [List<int>.generate(draft.nodes.length, (i) => i)];
    }
    return levels;
  }
}
