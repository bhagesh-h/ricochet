import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:Ricochet/views/widgets/ai_status_pill.dart';
import 'package:Ricochet/views/widgets/ai_status_popover.dart';

void main() {
  group('computeAiStatusPopoverOffset', () {
    test('aligns below anchor when there is room on the right', () {
      final offset = computeAiStatusPopoverOffset(
        anchorTopLeft: const Offset(100, 40),
        anchorSize: const Size(90, 28),
        screenSize: const Size(1280, 800),
      );

      expect(offset.dx, 100);
      expect(offset.dy, 76);
    });

    test('shifts left when popover would overflow the right edge', () {
      final offset = computeAiStatusPopoverOffset(
        anchorTopLeft: const Offset(1100, 40),
        anchorSize: const Size(90, 28),
        screenSize: const Size(1280, 800),
      );

      expect(offset.dx + AiStatusPopover.width, lessThanOrEqualTo(1280 - 12));
      expect(offset.dx, greaterThanOrEqualTo(12));
    });

    test('right-aligns to anchor when pill is in the top-right corner', () {
      const anchorWidth = 88.0;
      const screenWidth = 900.0;
      final offset = computeAiStatusPopoverOffset(
        anchorTopLeft: Offset(screenWidth - anchorWidth - 16, 12),
        anchorSize: const Size(anchorWidth, 28),
        screenSize: const Size(screenWidth, 700),
      );

      expect(offset.dx + AiStatusPopover.width, lessThanOrEqualTo(screenWidth - 12));
      expect(offset.dx, greaterThanOrEqualTo(12));
    });
  });
}
