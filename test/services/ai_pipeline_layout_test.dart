import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:Ricochet/models/ai_pipeline_draft.dart';
import 'package:Ricochet/services/ai_pipeline_layout.dart';

void main() {
  final layout = AiPipelineLayout();

  test('positions nodes by topological level from origin', () {
    final draft = AiPipelineDraft(
      nodes: const [
        AiDraftNodeDef(nodeType: 'Input'),
        AiDraftNodeDef(nodeType: 'FastQC'),
        AiDraftNodeDef(nodeType: 'Output'),
      ],
      connections: const [
        AiDraftConnectionDef(fromIndex: 0, toIndex: 1),
        AiDraftConnectionDef(fromIndex: 1, toIndex: 2),
      ],
    );

    final result = layout.layout(draft);
    expect(result.positionsByIndex[0], const Offset(25000, 25000));
    expect(result.positionsByIndex[1]!.dx, 25295);
    expect(result.positionsByIndex[2]!.dx, 25590);
    expect(result.hasSummaryGhost, isFalse);
  });

  test('creates overflow metadata when level exceeds cap', () {
    final nodes = <AiDraftNodeDef>[
      const AiDraftNodeDef(nodeType: 'Input'),
      ...List.generate(35, (_) => const AiDraftNodeDef(nodeType: 'FastQC')),
      const AiDraftNodeDef(nodeType: 'Output'),
    ];

    final connections = <AiDraftConnectionDef>[
      for (var i = 1; i <= 35; i++) AiDraftConnectionDef(fromIndex: 0, toIndex: i),
      for (var i = 1; i <= 35; i++) AiDraftConnectionDef(fromIndex: i, toIndex: 36),
    ];

    final result = layout.layout(
      AiPipelineDraft(nodes: nodes, connections: connections),
    );

    expect(result.positionsByIndex.length, 34);
    expect(result.overflowCount, 3);
    expect(result.overflowScrollToIndex, 33);
    expect(result.hasSummaryGhost, isTrue);
  });
}
