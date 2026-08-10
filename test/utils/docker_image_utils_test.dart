import 'package:flutter_test/flutter_test.dart';

import 'package:Ricochet/utils/docker_image_utils.dart';

void main() {
  group('isDockerImageNotFoundError', () {
    test('detects biocontainers samtools latest not found', () {
      expect(
        isDockerImageNotFoundError(
          'Error response from daemon: failed to resolve reference '
          '"docker.io/biocontainers/samtools:latest": '
          'docker.io/biocontainers/samtools:latest: not found',
        ),
        isTrue,
      );
    });

    test('detects manifest unknown', () {
      expect(
        isDockerImageNotFoundError('manifest unknown: docker.io/foo:bar'),
        isTrue,
      );
    });

    test('does not match unrelated errors', () {
      expect(
        isDockerImageNotFoundError('unexpected EOF while pulling layer'),
        isFalse,
      );
    });
  });
}
