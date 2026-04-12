import 'package:flutter_test/flutter_test.dart';
import 'package:get/get.dart';
import 'package:Ricochet/controllers/execution_controller.dart';
import 'package:Ricochet/controllers/pipeline_controller.dart';
import 'package:Ricochet/models/pipeline_file.dart';
import 'package:Ricochet/models/pipeline_node.dart';

// ---------------------------------------------------------------------------
// Helpers
// ---------------------------------------------------------------------------
PipelineNode _dockerNode(String id, {String command = 'echo hi', String image = 'alpine'}) {
  return PipelineNode(
    id: id,
    title: 'Tool $id',
    description: '',
    position: Offset.zero,
    category: BlockCategory.processing,
    iconCodePoint: '0xe8d5',
    dockerImage: image,
    parameters: [
      BlockParameter(key: 'command', label: 'Command', type: ParameterType.text, value: command),
      BlockParameter(key: 'image', label: 'Image', type: ParameterType.text, value: image),
    ],
  );
}

PipelineNode _plainNode(String id, {String title = 'Input'}) => PipelineNode(
      id: id,
      title: title,
      description: '',
      position: Offset.zero,
      category: BlockCategory.input,
      iconCodePoint: '0xe2c7',
      parameters: [],
    );

void main() {
  late ExecutionController execCtrl;
  late PipelineController pipelineCtrl;

  setUp(() {
    Get.testMode = true;
    pipelineCtrl = Get.put(PipelineController());
    execCtrl = Get.put(ExecutionController());
  });

  tearDown(() => Get.deleteAll(force: true));

  // ---------------------------------------------------------------------------
  // setPanelHeight
  // ---------------------------------------------------------------------------
  group('setPanelHeight', () {
    test('sets height within range', () {
      execCtrl.setPanelHeight(350.0);
      expect(execCtrl.panelHeight.value, 350.0);
    });

    test('clamps below minimum to 100', () {
      execCtrl.setPanelHeight(50.0);
      expect(execCtrl.panelHeight.value, 100.0);
    });

    test('clamps above maximum to 600', () {
      execCtrl.setPanelHeight(900.0);
      expect(execCtrl.panelHeight.value, 600.0);
    });

    test('exact minimum is accepted', () {
      execCtrl.setPanelHeight(100.0);
      expect(execCtrl.panelHeight.value, 100.0);
    });

    test('exact maximum is accepted', () {
      execCtrl.setPanelHeight(600.0);
      expect(execCtrl.panelHeight.value, 600.0);
    });
  });

  // ---------------------------------------------------------------------------
  // clearLogsAndSwitchToActiveTab
  // ---------------------------------------------------------------------------
  group('clearLogsAndSwitchToActiveTab', () {
    test('null tabId is a no-op', () {
      execCtrl.clearLogsAndSwitchToActiveTab(null);
      expect(execCtrl.log.isEmpty, isTrue);
    });

    test('switching tabs persists previous tab logs', () {
      execCtrl.clearLogsAndSwitchToActiveTab('tab-1');
      execCtrl.log.add('log from tab 1');

      execCtrl.clearLogsAndSwitchToActiveTab('tab-2');
      expect(execCtrl.log.isEmpty, isTrue); // tab-2 starts empty

      execCtrl.clearLogsAndSwitchToActiveTab('tab-1');
      expect(execCtrl.log, contains('log from tab 1'));
    });

    test('switching to new tab yields empty log', () {
      execCtrl.clearLogsAndSwitchToActiveTab('brand-new-tab');
      expect(execCtrl.log.isEmpty, isTrue);
    });
  });

  // ---------------------------------------------------------------------------
  // validatePipeline
  // ---------------------------------------------------------------------------
  group('validatePipeline', () {
    void loadNodes(List<PipelineNode> nodes, [List<Connection>? conns]) {
      final file = PipelineFile(
        id: 'tab',
        name: 'T',
        folderPath: '/tmp',
        nodes: nodes,
        connections: conns ?? [],
      );
      pipelineCtrl.loadPipelineData(file);
      execCtrl.clearLogsAndSwitchToActiveTab('tab');
    }

    test('empty canvas returns single error', () {
      loadNodes([]);
      final errors = execCtrl.validatePipeline();
      expect(errors.length, 1);
      expect(errors.first, contains('empty'));
    });

    test('single docker node with command is valid', () {
      loadNodes([_dockerNode('n1')]);
      expect(execCtrl.validatePipeline(), isEmpty);
    });

    test('docker node without command triggers error', () {
      loadNodes([_dockerNode('n1', command: '')]);
      final errors = execCtrl.validatePipeline();
      expect(errors.any((e) => e.contains('Command field is empty')), isTrue);
    });

    test('docker node without image triggers error', () {
      final node = PipelineNode(
        id: 'n1',
        title: 'Tool',
        description: '',
        position: Offset.zero,
        category: BlockCategory.processing,
        iconCodePoint: '0xe8d5',
        dockerImage: 'alpine',
        parameters: [
          BlockParameter(key: 'command', label: 'Command', type: ParameterType.text, value: 'echo'),
          BlockParameter(key: 'image', label: 'Image', type: ParameterType.text, value: ''),
        ],
      );
      loadNodes([node]);
      final errors = execCtrl.validatePipeline();
      expect(errors.any((e) => e.contains('Docker Image field is empty')), isTrue);
    });

    test('two docker nodes not connected triggers disconnected-node error', () {
      loadNodes([_dockerNode('n1'), _dockerNode('n2')]);
      final errors = execCtrl.validatePipeline();
      expect(errors.any((e) => e.contains('not connected')), isTrue);
    });

    test('two connected docker nodes with commands are valid', () {
      final n1 = _dockerNode('n1');
      final n2 = _dockerNode('n2');
      loadNodes([n1, n2], [
        Connection(id: 'c1', fromNodeId: 'n1', toNodeId: 'n2'),
      ]);
      expect(execCtrl.validatePipeline(), isEmpty);
    });

    test('non-docker node is not checked for command', () {
      loadNodes([_plainNode('x')]);
      expect(execCtrl.validatePipeline(), isEmpty);
    });
  });
}
