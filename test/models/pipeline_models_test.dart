import 'dart:ui';
import 'package:flutter_test/flutter_test.dart';
import 'package:Ricochet/models/pipeline_node.dart';
import 'package:Ricochet/models/pipeline_file.dart';

void main() {
  // ---------------------------------------------------------------------------
  // OffsetConverter
  // ---------------------------------------------------------------------------
  group('OffsetConverter', () {
    const converter = OffsetConverter();

    test('toJson encodes dx and dy', () {
      final result = converter.toJson(const Offset(3.5, 7.0));
      expect(result, {'dx': 3.5, 'dy': 7.0});
    });

    test('fromJson decodes dx and dy', () {
      final offset = converter.fromJson({'dx': 12.0, 'dy': -4.5});
      expect(offset, const Offset(12.0, -4.5));
    });

    test('round-trip preserves integer-like doubles', () {
      const orig = Offset(100.0, 200.0);
      final back = converter.fromJson(converter.toJson(orig));
      expect(back, orig);
    });
  });

  // ---------------------------------------------------------------------------
  // NullableOffsetConverter
  // ---------------------------------------------------------------------------
  group('NullableOffsetConverter', () {
    const converter = NullableOffsetConverter();

    test('toJson null → null', () {
      expect(converter.toJson(null), isNull);
    });

    test('fromJson null → null', () {
      expect(converter.fromJson(null), isNull);
    });

    test('round-trip non-null value', () {
      const orig = Offset(50.0, 75.5);
      final back = converter.fromJson(converter.toJson(orig));
      expect(back, orig);
    });
  });

  // ---------------------------------------------------------------------------
  // BlockParameter
  // ---------------------------------------------------------------------------
  group('BlockParameter', () {
    test('fromJson / toJson round-trip', () {
      final param = BlockParameter(
        id: 'param-1',
        key: 'threads',
        label: 'Threads',
        type: ParameterType.numeric,
        value: 8,
      );
      final json = param.toJson();
      final back = BlockParameter.fromJson(json);

      expect(back.key, 'threads');
      expect(back.label, 'Threads');
      expect(back.type, ParameterType.numeric);
      expect(back.value, 8);
    });

    test('dropdown options survive round-trip', () {
      final param = BlockParameter(
        key: 'algo',
        label: 'Algorithm',
        type: ParameterType.dropdown,
        options: ['mem', 'aln', 'bwasw'],
        value: 'mem',
      );
      final back = BlockParameter.fromJson(param.toJson());
      expect(back.options, ['mem', 'aln', 'bwasw']);
      expect(back.value, 'mem');
    });

    test('required field defaults to false', () {
      final param = BlockParameter(
        key: 'x',
        label: 'X',
        type: ParameterType.text,
      );
      expect(param.required, isFalse);
    });
  });

  // ---------------------------------------------------------------------------
  // PipelineNode
  // ---------------------------------------------------------------------------
  group('PipelineNode JSON serialization', () {
    PipelineNode _makeNode() => PipelineNode(
          id: 'node-abc',
          title: 'Test Node',
          description: 'Does testing',
          position: const Offset(100.0, 200.0),
          category: BlockCategory.processing,
          iconCodePoint: '0xe8d5',
          parameters: [
            BlockParameter(
              id: 'p1',
              key: 'threads',
              label: 'Threads',
              type: ParameterType.numeric,
              value: 4,
            ),
          ],
          inputPorts: ['input'],
          outputPorts: ['output'],
          dockerImage: 'alpine',
        );

    test('toJson produces expected keys', () {
      final json = _makeNode().toJson();
      expect(json['id'], 'node-abc');
      expect(json['title'], 'Test Node');
      expect(json['category'], 'processing');
      expect(json.containsKey('position'), isTrue);
    });

    test('fromJson / toJson round-trip preserves all persistent fields', () {
      final orig = _makeNode();
      final back = PipelineNode.fromJson(orig.toJson());

      expect(back.id, orig.id);
      expect(back.title, orig.title);
      expect(back.description, orig.description);
      expect(back.position.dx, orig.position.dx);
      expect(back.position.dy, orig.position.dy);
      expect(back.category, orig.category);
      expect(back.dockerImage, orig.dockerImage);
      expect(back.parameters.length, orig.parameters.length);
      expect(back.parameters.first.key, 'threads');
    });

    test('transient fields reset to defaults after round-trip', () {
      final node = _makeNode()
        ..status = BlockStatus.running
        ..isSelected = true
        ..downloadProgress = 0.75;

      final back = PipelineNode.fromJson(node.toJson());
      // @JsonKey(includeFromJson: false) fields are not persisted
      expect(back.status, BlockStatus.idle);
      expect(back.isSelected, isFalse);
      expect(back.downloadProgress, 0.0);
    });

    test('outputFileName and isAggregator persist', () {
      final node = _makeNode()
        ..outputFileName = 'results.csv'
        ..isAggregator = true;

      final back = PipelineNode.fromJson(node.toJson());
      expect(back.outputFileName, 'results.csv');
      expect(back.isAggregator, isTrue);
    });
  });

  // ---------------------------------------------------------------------------
  // PipelineNode derived properties
  // ---------------------------------------------------------------------------
  group('PipelineNode derived properties', () {
    test('primaryColor varies per category', () {
      final colors = BlockCategory.values
          .map((c) => PipelineNode(
                id: 'n',
                title: 't',
                description: 'd',
                position: Offset.zero,
                category: c,
                iconCodePoint: '0xe8d5',
                parameters: [],
              ).primaryColor)
          .toList();
      // All colours should be distinct
      expect(colors.toSet().length, BlockCategory.values.length);
    });

    test('config extension only includes non-null parameter values', () {
      final node = PipelineNode(
        id: 'n',
        title: 't',
        description: 'd',
        position: Offset.zero,
        category: BlockCategory.processing,
        iconCodePoint: '0xe8d5',
        parameters: [
          BlockParameter(key: 'a', label: 'A', type: ParameterType.text, value: 'hello'),
          BlockParameter(key: 'b', label: 'B', type: ParameterType.text), // null value
        ],
      );
      expect(node.config, {'a': 'hello'});
    });
  });

  // ---------------------------------------------------------------------------
  // Connection
  // ---------------------------------------------------------------------------
  group('Connection JSON serialization', () {
    test('round-trip with null points', () {
      final conn = Connection(
        id: 'conn-1',
        fromNodeId: 'a',
        toNodeId: 'b',
      );
      final back = Connection.fromJson(conn.toJson());
      expect(back.id, 'conn-1');
      expect(back.fromNodeId, 'a');
      expect(back.toNodeId, 'b');
      expect(back.fromPoint, isNull);
      expect(back.toPoint, isNull);
    });

    test('round-trip with explicit points', () {
      final conn = Connection(
        id: 'conn-2',
        fromNodeId: 'x',
        toNodeId: 'y',
        fromPoint: const Offset(10.0, 20.0),
        toPoint: const Offset(30.0, 40.0),
      );
      final back = Connection.fromJson(conn.toJson());
      expect(back.fromPoint!.dx, 10.0);
      expect(back.fromPoint!.dy, 20.0);
      expect(back.toPoint!.dx, 30.0);
      expect(back.toPoint!.dy, 40.0);
    });

    test('default ports are preserved', () {
      final conn = Connection(id: 'c', fromNodeId: 'a', toNodeId: 'b');
      final back = Connection.fromJson(conn.toJson());
      expect(back.fromPort, 'output');
      expect(back.toPort, 'input');
    });
  });

  // ---------------------------------------------------------------------------
  // PipelineFile
  // ---------------------------------------------------------------------------
  group('PipelineFile JSON serialization', () {
    test('empty nodes/connections round-trip', () {
      final file = PipelineFile(
        id: 'file-1',
        name: 'My Pipeline',
        folderPath: '/tmp/my-pipeline',
      );
      final back = PipelineFile.fromJson(file.toJson());
      expect(back.id, 'file-1');
      expect(back.name, 'My Pipeline');
      expect(back.folderPath, '/tmp/my-pipeline');
      expect(back.nodes, isEmpty);
      expect(back.connections, isEmpty);
    });

    test('hasUnsavedChanges is NOT persisted', () {
      final file = PipelineFile(
        id: 'f',
        name: 'n',
        folderPath: '/tmp',
        hasUnsavedChanges: true,
      );
      final back = PipelineFile.fromJson(file.toJson());
      expect(back.hasUnsavedChanges, isFalse);
    });

    test('nested nodes and connections survive round-trip', () {
      final node = PipelineNode(
        id: 'n1',
        title: 'Input',
        description: 'in',
        position: const Offset(50.0, 50.0),
        category: BlockCategory.input,
        iconCodePoint: '0xe2c7',
        parameters: [],
      );
      final conn = Connection(id: 'c1', fromNodeId: 'n1', toNodeId: 'n2');

      final file = PipelineFile(
        id: 'f2',
        name: 'With Data',
        folderPath: '/tmp',
        nodes: [node],
        connections: [conn],
      );
      final back = PipelineFile.fromJson(file.toJson());
      expect(back.nodes.length, 1);
      expect(back.nodes.first.id, 'n1');
      expect(back.connections.length, 1);
      expect(back.connections.first.id, 'c1');
    });
  });
}
