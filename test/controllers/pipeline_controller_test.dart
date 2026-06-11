import 'package:flutter_test/flutter_test.dart';
import 'package:get/get.dart';
import 'package:Ricochet/controllers/pipeline_controller.dart';
import 'package:Ricochet/models/pipeline_node.dart';
import 'package:Ricochet/models/pipeline_file.dart';

// ---------------------------------------------------------------------------
// Helper: build a minimal PipelineFile with supplied nodes/connections so
// we can call loadPipelineData() without hitting the disk.
// ---------------------------------------------------------------------------
PipelineFile _makeFile({
  List<PipelineNode> nodes = const [],
  List<Connection> connections = const [],
}) =>
    PipelineFile(
      id: 'test-tab',
      name: 'Test',
      folderPath: '/tmp',
      nodes: nodes,
      connections: connections,
    );

PipelineNode _node(String id, {String title = 'Node'}) => PipelineNode(
      id: id,
      title: title,
      description: '',
      position: Offset.zero,
      category: BlockCategory.processing,
      iconCodePoint: '0xe8d5',
      parameters: [],
    );

void main() {
  late PipelineController ctrl;

  setUp(() {
    Get.testMode = true;
    ctrl = Get.put(PipelineController());
  });

  tearDown(() => Get.deleteAll(force: true));

  // ---------------------------------------------------------------------------
  // addNode / deleteNode
  // ---------------------------------------------------------------------------
  group('addNode / deleteNode', () {
    test('addNode increases node count', () {
      ctrl.loadPipelineData(_makeFile());
      ctrl.addNode('Input', const Offset(100, 100));
      expect(ctrl.nodes.length, 1);
    });

    test('addNode with docker: prefix (tag provided) adds a node without crash', () {
      ctrl.loadPipelineData(_makeFile());
      ctrl.addNode('docker:alpine:latest', const Offset(50, 50));
      expect(ctrl.nodes.length, 1);
      expect(ctrl.nodes.first.dockerImage, 'alpine');
    });

    test('deleteNode removes node and its attached connections', () {
      ctrl.loadPipelineData(_makeFile());
      ctrl.addNode('Input', Offset.zero);
      ctrl.addNode('Output', Offset.zero);
      final fromId = ctrl.nodes[0].id;
      final toId = ctrl.nodes[1].id;
      ctrl.addConnection(fromId, toId);

      expect(ctrl.connections.length, 1);
      ctrl.deleteNode(fromId);
      expect(ctrl.nodes.any((n) => n.id == fromId), isFalse);
      expect(ctrl.connections.any((c) => c.fromNodeId == fromId), isFalse);
    });

    test('deleteNode on input-default or output-default is a no-op', () {
      ctrl.loadPipelineData(_makeFile(nodes: [
        _node('input-default'),
        _node('output-default'),
      ]));
      ctrl.deleteNode('input-default');
      ctrl.deleteNode('output-default');
      expect(ctrl.nodes.length, 2);
    });
  });

  // ---------------------------------------------------------------------------
  // addConnection / deleteConnection
  // ---------------------------------------------------------------------------
  group('addConnection / deleteConnection', () {
    test('addConnection creates a connection', () {
      ctrl.loadPipelineData(_makeFile(nodes: [_node('a'), _node('b')]));
      ctrl.addConnection('a', 'b');
      expect(ctrl.connections.length, 1);
      expect(ctrl.connections.first.fromNodeId, 'a');
      expect(ctrl.connections.first.toNodeId, 'b');
    });

    test('duplicate connection is rejected', () {
      ctrl.loadPipelineData(_makeFile(nodes: [_node('a'), _node('b')]));
      ctrl.addConnection('a', 'b');
      ctrl.addConnection('a', 'b');
      expect(ctrl.connections.length, 1);
    });

    test('self-loop connection is rejected', () {
      ctrl.loadPipelineData(_makeFile(nodes: [_node('x')]));
      ctrl.addConnection('x', 'x');
      expect(ctrl.connections.isEmpty, isTrue);
    });

    test('deleteConnection removes the connection', () {
      ctrl.loadPipelineData(_makeFile(nodes: [_node('a'), _node('b')]));
      ctrl.addConnection('a', 'b');
      final connId = ctrl.connections.first.id;
      ctrl.deleteConnection(connId);
      expect(ctrl.connections.isEmpty, isTrue);
    });
  });

  // ---------------------------------------------------------------------------
  // selectNode / deselectAll
  // ---------------------------------------------------------------------------
  group('selectNode / deselectAll', () {
    test('selectNode marks only that node as selected', () {
      ctrl.loadPipelineData(_makeFile(nodes: [_node('a'), _node('b')]));
      ctrl.selectNode('a');
      expect(ctrl.nodes.firstWhere((n) => n.id == 'a').isSelected, isTrue);
      expect(ctrl.nodes.firstWhere((n) => n.id == 'b').isSelected, isFalse);
    });

    test('deselectAll clears node and connection selection', () {
      ctrl.loadPipelineData(_makeFile(nodes: [_node('a'), _node('b')]));
      ctrl.addConnection('a', 'b');
      ctrl.selectNode('a');
      ctrl.selectConnection(ctrl.connections.first.id);
      ctrl.deselectAll();
      expect(ctrl.selectedNode.value, isNull);
      expect(ctrl.selectedConnectionId.value, isNull);
    });
  });

  // ---------------------------------------------------------------------------
  // undo / redo
  // ---------------------------------------------------------------------------
  group('undo / redo', () {
    test('undo reverts last node addition', () {
      ctrl.loadPipelineData(_makeFile());
      ctrl.addNode('Input', Offset.zero);
      expect(ctrl.nodes.length, 1);
      ctrl.undo();
      expect(ctrl.nodes.isEmpty, isTrue);
    });

    test('redo re-applies undone change', () {
      ctrl.loadPipelineData(_makeFile());
      ctrl.addNode('Output', Offset.zero);
      ctrl.undo();
      expect(ctrl.nodes.isEmpty, isTrue);
      ctrl.redo();
      expect(ctrl.nodes.length, 1);
    });

    test('undo on empty history does nothing', () {
      ctrl.loadPipelineData(_makeFile());
      // No operations: undo should not throw
      expect(() => ctrl.undo(), returnsNormally);
    });

    test('redo on empty redo stack does nothing', () {
      ctrl.loadPipelineData(_makeFile());
      ctrl.addNode('Input', Offset.zero);
      expect(() => ctrl.redo(), returnsNormally);
    });
  });

  // ---------------------------------------------------------------------------
  // getCycleConnections
  // ---------------------------------------------------------------------------
  group('getCycleConnections', () {
    test('linear graph has no cycles', () {
      // A → B → C
      ctrl.loadPipelineData(_makeFile(
        nodes: [_node('A'), _node('B'), _node('C')],
        connections: [
          Connection(id: 'c1', fromNodeId: 'A', toNodeId: 'B'),
          Connection(id: 'c2', fromNodeId: 'B', toNodeId: 'C'),
        ],
      ));
      expect(ctrl.getCycleConnections(), isEmpty);
    });

    test('single back-edge cycle is detected', () {
      // A → B → A  (back-edge B→A forms cycle)
      ctrl.loadPipelineData(_makeFile(
        nodes: [_node('A'), _node('B')],
        connections: [
          Connection(id: 'c1', fromNodeId: 'A', toNodeId: 'B'),
          Connection(id: 'c2', fromNodeId: 'B', toNodeId: 'A'),
        ],
      ));
      expect(ctrl.getCycleConnections(), isNotEmpty);
    });

    test('three-node cycle: all back-edge connections flagged', () {
      // A → B → C → A
      ctrl.loadPipelineData(_makeFile(
        nodes: [_node('A'), _node('B'), _node('C')],
        connections: [
          Connection(id: 'c1', fromNodeId: 'A', toNodeId: 'B'),
          Connection(id: 'c2', fromNodeId: 'B', toNodeId: 'C'),
          Connection(id: 'c3', fromNodeId: 'C', toNodeId: 'A'),
        ],
      ));
      final cycles = ctrl.getCycleConnections();
      expect(cycles, isNotEmpty);
      // The back-edge itself must be included
      expect(cycles, contains('c3'));
    });

    test('empty graph has no cycles', () {
      ctrl.loadPipelineData(_makeFile());
      expect(ctrl.getCycleConnections(), isEmpty);
    });
  });

  // ---------------------------------------------------------------------------
  // getExecutionOrder (topological sort)
  // ---------------------------------------------------------------------------
  group('getExecutionOrder', () {
    test('linear graph returns nodes in execution order', () {
      ctrl.loadPipelineData(_makeFile(
        nodes: [_node('A'), _node('B'), _node('C')],
        connections: [
          Connection(id: 'c1', fromNodeId: 'A', toNodeId: 'B'),
          Connection(id: 'c2', fromNodeId: 'B', toNodeId: 'C'),
        ],
      ));
      final order = ctrl.getExecutionOrder();
      expect(order.map((n) => n.id).toList(), ['A', 'B', 'C']);
    });

    test('throws on cyclic graph', () {
      ctrl.loadPipelineData(_makeFile(
        nodes: [_node('A'), _node('B')],
        connections: [
          Connection(id: 'c1', fromNodeId: 'A', toNodeId: 'B'),
          Connection(id: 'c2', fromNodeId: 'B', toNodeId: 'A'),
        ],
      ));
      expect(() => ctrl.getExecutionOrder(), throwsException);
    });

    test('single node returns itself', () {
      ctrl.loadPipelineData(_makeFile(nodes: [_node('solo')]));
      final order = ctrl.getExecutionOrder();
      expect(order.length, 1);
      expect(order.first.id, 'solo');
    });
  });

  // ---------------------------------------------------------------------------
  // saveStateToPipelineFile
  // ---------------------------------------------------------------------------
  group('saveStateToPipelineFile', () {
    test('syncs canvas nodes back to PipelineFile', () {
      final file = _makeFile();
      ctrl.loadPipelineData(file);
      ctrl.addNode('Input', Offset.zero);
      ctrl.saveStateToPipelineFile(file);
      expect(file.nodes.length, 1);
    });

    test('syncs connections to PipelineFile', () {
      final file = _makeFile(nodes: [_node('a'), _node('b')]);
      ctrl.loadPipelineData(file);
      ctrl.addConnection('a', 'b');
      ctrl.saveStateToPipelineFile(file);
      expect(file.connections.length, 1);
    });
  });
}
