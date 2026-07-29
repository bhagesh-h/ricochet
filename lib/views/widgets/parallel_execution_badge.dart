import 'package:flutter/material.dart';
import 'package:get/get.dart';

import '../../controllers/settings_controller.dart';

/// Small pill shown in the editor chrome when parallel execution is enabled
/// or actively running a parallel pipeline.
class ParallelExecutionBadge extends StatelessWidget {
  final bool compact;

  const ParallelExecutionBadge({super.key, this.compact = false});

  @override
  Widget build(BuildContext context) {
    if (!Get.isRegistered<SettingsController>()) {
      return const SizedBox.shrink();
    }

    final settingsCtrl = Get.find<SettingsController>();

    return Obx(() {
      final enabled = settingsCtrl.parallelExecutionEnabled.value;
      final active = settingsCtrl.isParallelRunActive.value;
      if (!enabled && !active) return const SizedBox.shrink();

      final label = active ? 'Parallel · Running' : 'Parallel · On';
      final bg = active ? const Color(0xFF059669) : const Color(0xFF6366F1);

      return Tooltip(
        message: SettingsController.parallelExecutionTooltip,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 180),
          padding: EdgeInsets.symmetric(
            horizontal: compact ? 8 : 10,
            vertical: compact ? 4 : 5,
          ),
          decoration: BoxDecoration(
            color: bg.withOpacity(active ? 0.95 : 0.85),
            borderRadius: BorderRadius.circular(20),
            boxShadow: active
                ? [
                    BoxShadow(
                      color: bg.withOpacity(0.35),
                      blurRadius: 8,
                      offset: const Offset(0, 2),
                    ),
                  ]
                : null,
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(
                active ? Icons.bolt_rounded : Icons.account_tree_outlined,
                size: compact ? 12 : 13,
                color: Colors.white,
              ),
              const SizedBox(width: 5),
              Text(
                label,
                style: TextStyle(
                  color: Colors.white,
                  fontSize: compact ? 10.5 : 11,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ],
          ),
        ),
      );
    });
  }
}
