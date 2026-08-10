import 'package:flutter_test/flutter_test.dart';

import 'package:Ricochet/services/ai_unknown_node_suggestions.dart';

void main() {
  test('suggests QC tools for qc-like names', () {
    final suggestions = AiUnknownNodeSuggestions.suggestionsFor('ReadQC');
    expect(suggestions, contains('FastQC'));
  });

  test('hubSearchQuery strips docker prefix', () {
    expect(
      AiUnknownNodeSuggestions.hubSearchQuery('docker:biocontainers/samtools:latest'),
      'biocontainers/samtools',
    );
  });
}
