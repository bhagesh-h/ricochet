import 'package:flutter_test/flutter_test.dart';

import 'package:Ricochet/models/docker_info.dart';

void main() {
  group('PlatformInfo.detectWindowsArchitecture', () {
    test('detects native Windows on ARM64', () {
      expect(
        PlatformInfo.detectWindowsArchitecture({
          'PROCESSOR_ARCHITECTURE': 'ARM64',
        }),
        'arm64',
      );
    });

    test('detects native Windows x64', () {
      expect(
        PlatformInfo.detectWindowsArchitecture({
          'PROCESSOR_ARCHITECTURE': 'AMD64',
        }),
        'x86_64',
      );
    });

    test('detects x64 host when running under WOW64', () {
      expect(
        PlatformInfo.detectWindowsArchitecture({
          'PROCESSOR_ARCHITECTURE': 'x86',
          'PROCESSOR_ARCHITEW6432': 'AMD64',
        }),
        'x86_64',
      );
    });
  });

  group('PlatformInfo emulation flags', () {
    test('Windows on ARM requests amd64 container platform', () {
      final info = PlatformInfo(
        isMacOS: false,
        isWindows: true,
        isLinux: false,
        isAppleSilicon: false,
        architecture: 'arm64',
        osVersion: 'Windows 11',
      );

      expect(info.isWindowsArm, isTrue);
      expect(info.needsPlatformEmulation, isTrue);
      expect(info.dockerPlatformFlag, 'linux/amd64');
    });

    test('Windows on Intel does not request emulation', () {
      final info = PlatformInfo(
        isMacOS: false,
        isWindows: true,
        isLinux: false,
        isAppleSilicon: false,
        architecture: 'x86_64',
        osVersion: 'Windows 11',
      );

      expect(info.isWindowsArm, isFalse);
      expect(info.needsPlatformEmulation, isFalse);
      expect(info.dockerPlatformFlag, 'linux/amd64');
    });

    test('Apple Silicon requests amd64 container platform', () {
      final info = PlatformInfo(
        isMacOS: true,
        isWindows: false,
        isLinux: false,
        isAppleSilicon: true,
        architecture: 'arm64',
        osVersion: 'macOS 15',
      );

      expect(info.needsPlatformEmulation, isTrue);
      expect(info.dockerPlatformFlag, 'linux/amd64');
    });
  });
}
