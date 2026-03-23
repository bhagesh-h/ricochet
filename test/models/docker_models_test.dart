import 'package:flutter_test/flutter_test.dart';
import 'package:Ricochet/models/docker_image.dart';
import 'package:Ricochet/models/docker_pull_progress.dart';
import 'package:Ricochet/models/docker_info.dart';

void main() {
  // ---------------------------------------------------------------------------
  // DockerImage
  // ---------------------------------------------------------------------------
  group('DockerImage', () {
    Map<String, dynamic> _imageJson({
      String repoName = 'alpine',
      String shortDescription = 'A minimal image',
      int starCount = 10000,
      int pullCount = 1000000000,
      String repoOwner = 'library',
      bool isAutomated = false,
      bool isOfficial = true,
    }) =>
        {
          'repo_name': repoName,
          'short_description': shortDescription,
          'star_count': starCount,
          'pull_count': pullCount,
          'repo_owner': repoOwner,
          'is_automated': isAutomated,
          'is_official': isOfficial,
        };

    test('fromJson parses all fields correctly', () {
      final img = DockerImage.fromJson(_imageJson());
      expect(img.repoName, 'alpine');
      expect(img.shortDescription, 'A minimal image');
      expect(img.starCount, 10000);
      expect(img.pullCount, 1000000000);
      expect(img.isOfficial, isTrue);
      expect(img.isAutomated, isFalse);
    });

    test('fromJson uses defaults for missing keys', () {
      final img = DockerImage.fromJson({});
      expect(img.repoName, '');
      expect(img.pullCount, 0);
      expect(img.isOfficial, isFalse);
    });

    group('formattedPullCount', () {
      test('billions abbrev', () {
        final img = DockerImage.fromJson(_imageJson(pullCount: 2000000000));
        expect(img.formattedPullCount, '2.0B');
      });

      test('millions abbrev', () {
        final img = DockerImage.fromJson(_imageJson(pullCount: 5500000));
        expect(img.formattedPullCount, '5.5M');
      });

      test('thousands abbrev', () {
        final img = DockerImage.fromJson(_imageJson(pullCount: 3200));
        expect(img.formattedPullCount, '3.2K');
      });

      test('small numbers shown as-is', () {
        final img = DockerImage.fromJson(_imageJson(pullCount: 999));
        expect(img.formattedPullCount, '999');
      });

      test('zero', () {
        final img = DockerImage.fromJson(_imageJson(pullCount: 0));
        expect(img.formattedPullCount, '0');
      });
    });

    group('displayName', () {
      test('includes owner when owner is non-empty', () {
        final img = DockerImage.fromJson(_imageJson(repoOwner: 'bitnami', repoName: 'redis'));
        expect(img.displayName, 'bitnami/redis');
      });

      test('just repo name when owner is empty', () {
        final img = DockerImage.fromJson(_imageJson(repoOwner: '', repoName: 'ubuntu'));
        expect(img.displayName, 'ubuntu');
      });
    });
  });

  // ---------------------------------------------------------------------------
  // DockerSearchResponse
  // ---------------------------------------------------------------------------
  group('DockerSearchResponse', () {
    test('fromJson parses count and results list', () {
      final json = {
        'count': 2,
        'next': null,
        'previous': null,
        'results': [
          {'repo_name': 'alpine', 'short_description': '', 'star_count': 1, 'pull_count': 1, 'repo_owner': '', 'is_automated': false, 'is_official': true},
          {'repo_name': 'ubuntu', 'short_description': '', 'star_count': 2, 'pull_count': 2, 'repo_owner': '', 'is_automated': false, 'is_official': true},
        ],
      };
      final response = DockerSearchResponse.fromJson(json);
      expect(response.count, 2);
      expect(response.results.length, 2);
      expect(response.results.first.repoName, 'alpine');
    });

    test('empty results list handled gracefully', () {
      final response = DockerSearchResponse.fromJson({'count': 0});
      expect(response.results, isEmpty);
    });
  });

  // ---------------------------------------------------------------------------
  // DockerTag & TagCacheEntry
  // ---------------------------------------------------------------------------
  group('DockerTag', () {
    test('fromJson parses expected fields', () {
      final json = {
        'name': '3.18',
        'full_size': 3145728,
        'architecture': 'amd64',
        'os': 'linux',
        'digest': 'sha256:abc',
        'last_updated': '2024-01-01T00:00:00Z',
      };
      final tag = DockerTag.fromJson(json);
      expect(tag.name, '3.18');
      expect(tag.size, 3145728);
      expect(tag.architecture, 'amd64');
    });
  });

  group('TagCacheEntry', () {
    test('not expired when fetched just now', () {
      final entry = TagCacheEntry(
        tags: [],
        fetchedAt: DateTime.now(),
        isFullFetch: false,
      );
      expect(entry.isExpired, isFalse);
    });

    test('expired when fetched more than TTL ago', () {
      final entry = TagCacheEntry(
        tags: [],
        fetchedAt: DateTime.now().subtract(const Duration(hours: 2)),
        isFullFetch: false,
      );
      expect(entry.isExpired, isTrue);
    });
  });

  // ---------------------------------------------------------------------------
  // DockerPullProgress factories
  // ---------------------------------------------------------------------------
  group('DockerPullProgress', () {
    test('starting factory sets correct status and percentage', () {
      final p = DockerPullProgress.starting('alpine');
      expect(p.imageName, 'alpine');
      expect(p.status, PullStatus.starting);
      expect(p.percentage, 0.0);
      expect(p.message, contains('Starting'));
    });

    test('complete factory sets percentage 1.0', () {
      final p = DockerPullProgress.complete('alpine');
      expect(p.status, PullStatus.complete);
      expect(p.percentage, 1.0);
      expect(p.message, contains('complete'));
    });

    test('error factory embeds error text', () {
      final p = DockerPullProgress.error('alpine', 'network timeout');
      expect(p.status, PullStatus.error);
      expect(p.message, contains('network timeout'));
    });

    test('extracting factory stores layerId and percentage', () {
      final p = DockerPullProgress.extracting(
        imageName: 'alpine',
        layerId: 'abc123',
        percentage: 0.5,
      );
      expect(p.status, PullStatus.extracting);
      expect(p.layerId, 'abc123');
      expect(p.percentage, 0.5);
      expect(p.message, contains('abc123'));
    });

    group('downloading factory byte formatting', () {
      test('formats MB correctly in message', () {
        final p = DockerPullProgress.downloading(
          imageName: 'alpine',
          layerId: 'layer1',
          currentBytes: 2097152,   // 2 MB
          totalBytes: 10485760,    // 10 MB
          percentage: 0.2,
        );
        expect(p.message, contains('2.0 MB'));
        expect(p.message, contains('10.0 MB'));
      });

      test('formats KB correctly in message', () {
        final p = DockerPullProgress.downloading(
          imageName: 'alpine',
          layerId: 'layer1',
          currentBytes: 512,
          totalBytes: 2048,
          percentage: 0.25,
        );
        expect(p.message, contains('512 B'));
        expect(p.message, contains('2.0 KB'));
      });

      test('null totalBytes produces partial message', () {
        final p = DockerPullProgress.downloading(
          imageName: 'alpine',
          layerId: 'x',
          currentBytes: null,
          totalBytes: null,
          percentage: 0.0,
        );
        expect(p.message, contains('Downloading x...'));
      });
    });
  });

  // ---------------------------------------------------------------------------
  // DockerInfo
  // ---------------------------------------------------------------------------
  group('DockerInfo.fromDockerInfoOutput', () {
    const typicalOutput = '''
Client:
 Version:           24.0.5

Server:
 Engine:
  Version:          24.0.5
 Server Version: 24.0.5
 Operating System: Docker Desktop
 Architecture: aarch64
 Containers: 3
 Images: 12
''';

    test('parses Server Version', () {
      final info = DockerInfo.fromDockerInfoOutput(typicalOutput);
      expect(info.serverVersion, '24.0.5');
    });

    test('parses Operating System', () {
      final info = DockerInfo.fromDockerInfoOutput(typicalOutput);
      expect(info.operatingSystem, 'Docker Desktop');
    });

    test('parses Architecture', () {
      final info = DockerInfo.fromDockerInfoOutput(typicalOutput);
      expect(info.architecture, 'aarch64');
    });

    test('parses container count', () {
      final info = DockerInfo.fromDockerInfoOutput(typicalOutput);
      expect(info.containers, 3);
    });

    test('parses image count', () {
      final info = DockerInfo.fromDockerInfoOutput(typicalOutput);
      expect(info.images, 12);
    });

    test('empty output yields defaults', () {
      final info = DockerInfo.fromDockerInfoOutput('');
      expect(info.serverVersion, 'Unknown');
      expect(info.containers, 0);
      expect(info.images, 0);
    });

    test('malformed count line defaults to 0', () {
      final info = DockerInfo.fromDockerInfoOutput('Containers: N/A\nImages: -');
      expect(info.containers, 0);
      expect(info.images, 0);
    });

    test('statusMessage includes version when running', () {
      final info = DockerInfo.fromDockerInfoOutput(typicalOutput);
      expect(info.statusMessage, contains('24.0.5'));
    });

    test('detailsMessage includes container and image counts', () {
      final info = DockerInfo.fromDockerInfoOutput(typicalOutput);
      expect(info.detailsMessage, contains('3'));
      expect(info.detailsMessage, contains('12'));
    });

    test('not-running statusMessage is informative', () {
      final info = DockerInfo(
        version: '?',
        serverVersion: '?',
        operatingSystem: 'Linux',
        architecture: 'x86',
        isRunning: false,
        containers: 0,
        images: 0,
        checkedAt: DateTime.now(),
      );
      expect(info.statusMessage, contains('not running'));
    });
  });
}
