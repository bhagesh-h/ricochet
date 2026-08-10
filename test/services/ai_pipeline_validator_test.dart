import 'package:flutter_test/flutter_test.dart';

import 'package:Ricochet/models/ai_pipeline_draft.dart';
import 'package:Ricochet/services/ai_pipeline_validator.dart';

void main() {
  final validator = AiPipelineValidator();

  AiPipelineDraft draft({
    required List<String> types,
    List<AiDraftConnectionDef> connections = const [],
  }) =>
      AiPipelineDraft(
        nodes: [
          for (final type in types) AiDraftNodeDef(nodeType: type),
        ],
        connections: connections,
      );

  test('valid simple linear pipeline passes', () {
    final result = validator.validate(
      draft(
        types: ['Input', 'FastQC', 'Output'],
        connections: const [
          AiDraftConnectionDef(fromIndex: 0, toIndex: 1),
          AiDraftConnectionDef(fromIndex: 1, toIndex: 2),
        ],
      ),
    );
    expect(result.isValid, isTrue);
  });

  test('rejects missing Input or Output', () {
    expect(
      validator.validate(draft(types: ['FastQC'])).isValid,
      isFalse,
    );
    expect(
      validator.validate(draft(types: ['Input', 'FastQC'])).isValid,
      isFalse,
    );
  });

  test('rejects cycles', () {
    final result = validator.validate(
      draft(
        types: ['Input', 'FastQC', 'Output'],
        connections: const [
          AiDraftConnectionDef(fromIndex: 0, toIndex: 1),
          AiDraftConnectionDef(fromIndex: 1, toIndex: 2),
          AiDraftConnectionDef(fromIndex: 2, toIndex: 0),
        ],
      ),
    );
    expect(result.isValid, isFalse);
    expect(result.errorMessage, contains('cycle'));
  });

  test('flags unknown node types without failing validation', () {
    final result = validator.validate(
      draft(
        types: ['Input', 'MysteryTool', 'Output'],
        connections: const [
          AiDraftConnectionDef(fromIndex: 0, toIndex: 1),
          AiDraftConnectionDef(fromIndex: 1, toIndex: 2),
        ],
      ),
    );
    expect(result.isValid, isTrue);
    expect(result.unknownNodeIndices, [1]);
  });
}
