import 'package:flutter_test/flutter_test.dart';
import 'package:get/get.dart';
import 'package:Ricochet/controllers/docker_search_controller.dart';
import 'package:Ricochet/models/docker_image.dart';

DockerTag _tag(String name, {DateTime? lastUpdated}) => DockerTag(
      name: name,
      lastUpdated: lastUpdated ?? DateTime(2024, 1, 1),
    );

void main() {
  late DockerSearchController ctrl;

  setUp(() {
    Get.testMode = true;
    ctrl = Get.put(DockerSearchController());
  });

  tearDown(() => Get.deleteAll(force: true));

  // ---------------------------------------------------------------------------
  // compareTags — deterministic genomic sorter
  // ---------------------------------------------------------------------------
  group('compareTags', () {
    test('"latest" sorts before anything else', () {
      final sorted = [
        _tag('3.18'),
        _tag('latest'),
        _tag('3.17'),
      ]..sort(ctrl.compareTags);
      expect(sorted.first.name, 'latest');
    });

    test('version-like tags sort before non-version tags', () {
      final tags = [_tag('edge'), _tag('1.2.3'), _tag('dev')]
        ..sort(ctrl.compareTags);
      expect(tags.first.name, '1.2.3');
    });

    test('two version tags are sorted descending (newer first)', () {
      final tags = [_tag('1.0.0'), _tag('2.0.0'), _tag('1.5.0')]
        ..sort(ctrl.compareTags);
      // Descending string compare: '2.0.0' > '1.5.0' > '1.0.0'
      expect(tags.first.name, '2.0.0');
      expect(tags.last.name, '1.0.0');
    });

    test('non-version tags fall back to lastUpdated recency', () {
      final older = _tag('edge', lastUpdated: DateTime(2022));
      final newer = _tag('dev', lastUpdated: DateTime(2024));
      final sorted = [older, newer]..sort(ctrl.compareTags);
      expect(sorted.first.name, 'dev');
    });

    test('stable sort: identical tags remain in original order', () {
      final a = _tag('edge', lastUpdated: DateTime(2024, 6, 1));
      final b = _tag('edge', lastUpdated: DateTime(2024, 6, 1));
      final result = ctrl.compareTags(a, b);
      expect(result, 0);
    });

    test('v-prefixed version tags sort correctly', () {
      final tags = [_tag('v1.0.0'), _tag('v2.0.0')]..sort(ctrl.compareTags);
      expect(tags.first.name, 'v2.0.0');
    });

    test('"latest" beats version tags', () {
      final tags = [_tag('1000.0.0'), _tag('latest')]..sort(ctrl.compareTags);
      expect(tags.first.name, 'latest');
    });
  });

  // ---------------------------------------------------------------------------
  // clearSearch
  // ---------------------------------------------------------------------------
  group('clearSearch', () {
    test('resets query, results and error message', () {
      ctrl.searchQuery.value = 'alpine';
      ctrl.searchResults.add(DockerImage(
        repoName: 'alpine',
        shortDescription: '',
        starCount: 0,
        pullCount: 0,
        repoOwner: '',
        isAutomated: false,
        isOfficial: true,
      ));
      ctrl.errorMessage.value = 'some error';

      ctrl.clearSearch();

      expect(ctrl.searchQuery.value, '');
      expect(ctrl.searchResults, isEmpty);
      expect(ctrl.errorMessage.value, '');
    });
  });

  // ---------------------------------------------------------------------------
  // getDockerRunCommand
  // ---------------------------------------------------------------------------
  group('getDockerRunCommand', () {
    test('produces correct docker run command string', () {
      final cmd = ctrl.getDockerRunCommand('alpine', '3.18');
      expect(cmd, 'docker run --rm -it alpine:3.18');
    });
  });
}
