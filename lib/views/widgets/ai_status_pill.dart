import 'package:flutter/material.dart';
import 'package:get/get.dart';

import '../../controllers/ai_controller.dart';
import 'ai_status_popover.dart';

/// Positions the status popover below [anchor], keeping it fully on screen.
Offset computeAiStatusPopoverOffset({
  required Offset anchorTopLeft,
  required Size anchorSize,
  required Size screenSize,
  double popoverWidth = AiStatusPopover.width,
  double edgePadding = 12,
  double gap = 8,
}) {
  var left = anchorTopLeft.dx;
  if (left + popoverWidth > screenSize.width - edgePadding) {
    left = anchorTopLeft.dx + anchorSize.width - popoverWidth;
  }
  left = left.clamp(
    edgePadding,
    (screenSize.width - popoverWidth - edgePadding).clamp(edgePadding, double.infinity),
  );

  final top = anchorTopLeft.dy + anchorSize.height + gap;
  return Offset(left, top);
}

class AiStatusPill extends StatelessWidget {
  final bool compact;

  const AiStatusPill({super.key, this.compact = false});

  @override
  Widget build(BuildContext context) {
    if (!Get.isRegistered<AiController>()) {
      return const SizedBox.shrink();
    }

    final ai = Get.find<AiController>();

    return Obx(() {
      if (ai.pillState.value == AiPillState.hidden) {
        return const SizedBox.shrink();
      }

      final state = ai.pillState.value;
      final (bg, fg) = _colorsFor(state);

      return Tooltip(
        message: 'AI Assistant status — tap for details',
        child: Material(
          color: Colors.transparent,
          child: InkWell(
            onTap: () => _showPopover(context, ai),
            borderRadius: BorderRadius.circular(20),
            child: AnimatedContainer(
              duration: const Duration(milliseconds: 180),
              padding: EdgeInsets.symmetric(
                horizontal: compact ? 8 : 10,
                vertical: compact ? 4 : 5,
              ),
              decoration: BoxDecoration(
                color: bg,
                borderRadius: BorderRadius.circular(20),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  _Dot(state: state),
                  const SizedBox(width: 6),
                  Text(
                    ai.pillLabel,
                    style: TextStyle(
                      color: fg,
                      fontSize: compact ? 10.5 : 11,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      );
    });
  }

  (Color, Color) _colorsFor(AiPillState state) {
    switch (state) {
      case AiPillState.connecting:
        return (const Color(0xFFFEF3C7), const Color(0xFFB45309));
      case AiPillState.ready:
        return (const Color(0xFFEEF2FF), const Color(0xFF4338CA));
      case AiPillState.readyLocal:
        return (const Color(0xFFD1FAE5), const Color(0xFF047857));
      case AiPillState.error:
        return (const Color(0xFFFEE2E2), const Color(0xFFB91C1C));
      case AiPillState.disconnected:
        return (const Color(0xFFF1F5F9), const Color(0xFF475569));
      case AiPillState.hidden:
        return (Colors.transparent, Colors.transparent);
    }
  }

  void _showPopover(BuildContext context, AiController ai) {
    final box = context.findRenderObject() as RenderBox?;
    final anchorTopLeft = box?.localToGlobal(Offset.zero) ?? Offset.zero;
    final anchorSize = box?.size ?? Size.zero;
    final screenSize = MediaQuery.sizeOf(context);
    final popoverOffset = computeAiStatusPopoverOffset(
      anchorTopLeft: anchorTopLeft,
      anchorSize: anchorSize,
      screenSize: screenSize,
    );

    showDialog(
      context: context,
      barrierColor: Colors.transparent,
      builder: (dialogContext) => GestureDetector(
        onTap: () => Navigator.of(dialogContext).pop(),
        behavior: HitTestBehavior.translucent,
        child: Stack(
          children: [
            Positioned(
              left: popoverOffset.dx,
              top: popoverOffset.dy,
              child: GestureDetector(
                onTap: () {},
                child: AiStatusPopover(ai: ai),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _Dot extends StatelessWidget {
  final AiPillState state;
  const _Dot({required this.state});

  @override
  Widget build(BuildContext context) {
    final color = switch (state) {
      AiPillState.connecting => const Color(0xFFF59E0B),
      AiPillState.ready => const Color(0xFF6366F1),
      AiPillState.readyLocal => const Color(0xFF059669),
      AiPillState.error => const Color(0xFFEF4444),
      AiPillState.disconnected => const Color(0xFF94A3B8),
      AiPillState.hidden => Colors.transparent,
    };
    return Container(
      width: 7,
      height: 7,
      decoration: BoxDecoration(color: color, shape: BoxShape.circle),
    );
  }
}
