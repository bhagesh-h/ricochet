import 'package:flutter_test/flutter_test.dart';

import 'package:Ricochet/models/ai_pipeline_draft.dart';
import 'package:Ricochet/services/ai_pipeline_parser.dart';

void main() {
  final parser = AiPipelineParser();

  test('parse extracts JSON from markdown fence', () {
    const raw = '''
Here is your pipeline:
```json
{
  "nodes": [
    {"nodeType": "Input"},
    {"nodeType": "FastQC"},
    {"nodeType": "Output"}
  ],
  "connections": [
    {"from": 0, "to": 1},
    {"from": 1, "to": 2}
  ]
}
```
''';

    final draft = parser.parse(raw);
    expect(draft.nodes.length, 3);
    expect(draft.nodes.first.nodeType, 'Input');
    expect(draft.connections.length, 2);
    expect(draft.connections.first.fromIndex, 0);
    expect(draft.connections.first.toIndex, 1);
  });

  test('parse throws on empty payload', () {
    expect(
      () => parser.parse(''),
      throwsA(isA<AiPipelineParseException>()),
    );
  });

  test('parse accepts parameterOverrides', () {
    final draft = parser.parse('''
{
  "nodes": [
    {
      "nodeType": "docker:biocontainers/samtools:latest",
      "parameterOverrides": {"command": "samtools sort"}
    }
  ],
  "connections": []
}
''');
    expect(draft.nodes.single.parameterOverrides['command'], 'samtools sort');
  });
}
