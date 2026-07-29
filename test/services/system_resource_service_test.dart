import 'package:flutter_test/flutter_test.dart';

import 'package:Ricochet/models/app_settings.dart';
import 'package:Ricochet/services/system_resource_service.dart';

void main() {
  group('SystemResourceService', () {
    test('recommendedParallelCap reserves one core', () {
      final service = SystemResourceService(logicalProcessorOverride: 8);
      expect(service.recommendedParallelCap(), 7);
    });

    test('single-core machine caps at 1', () {
      final service = SystemResourceService(logicalProcessorOverride: 1);
      expect(service.recommendedParallelCap(), 1);
      expect(service.resolveEffectiveParallelism(4), 1);
    });

    test('resolveEffectiveParallelism uses min of user setting and system cap', () {
      final service = SystemResourceService(logicalProcessorOverride: 4);
      expect(service.resolveEffectiveParallelism(2), 2);
      expect(service.resolveEffectiveParallelism(8), 3);
    });

    test('resolveEffectiveParallelism clamps user setting to allowed range', () {
      final service = SystemResourceService(logicalProcessorOverride: 32);
      expect(
        service.resolveEffectiveParallelism(0),
        AppSettings.minMaxParallelJobs,
      );
      expect(
        service.resolveEffectiveParallelism(99),
        AppSettings.maxMaxParallelJobs,
      );
    });
  });
}
