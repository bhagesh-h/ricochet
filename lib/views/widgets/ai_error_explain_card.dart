import 'package:flutter/material.dart';
import 'package:get/get.dart';

import '../../controllers/ai_controller.dart';
import '../../models/pipeline_node.dart';

class AiErrorExplainCard extends StatelessWidget {
  final PipelineNode node;

  const AiErrorExplainCard({super.key, required this.node});

  @override
  Widget build(BuildContext context) {
    if (!Get.isRegistered<AiController>()) return const SizedBox.shrink();
    final ai = Get.find<AiController>();

    return Obx(() {
      if (ai.explainNodeId.value != node.id) return const SizedBox.shrink();

      final phase = ai.explainPhase.value;
      if (phase == AiExplainPhase.idle) return const SizedBox.shrink();

      return Container(
        margin: const EdgeInsets.fromLTRB(12, 0, 12, 8),
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: const Color(0xFF1E293B),
          borderRadius: BorderRadius.circular(8),
          border: Border.all(color: const Color(0xFF334155)),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                const Icon(Icons.auto_awesome, size: 14, color: Color(0xFF818CF8)),
                const SizedBox(width: 6),
                const Expanded(
                  child: Text(
                    'AI explanation',
                    style: TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.w700,
                      color: Color(0xFFE2E8F0),
                    ),
                  ),
                ),
                if (ai.explainTruncated.value)
                  const Padding(
                    padding: EdgeInsets.only(right: 8),
                    child: Text(
                      'Limited log context',
                      style: TextStyle(fontSize: 10, color: Color(0xFF94A3B8)),
                    ),
                  ),
                if (phase == AiExplainPhase.streaming)
                  TextButton(
                    onPressed: ai.dismissErrorExplain,
                    child: const Text('Cancel'),
                  )
                else
                  IconButton(
                    onPressed: ai.dismissErrorExplain,
                    icon: const Icon(Icons.close, size: 16, color: Color(0xFF94A3B8)),
                    padding: EdgeInsets.zero,
                    constraints: const BoxConstraints(),
                  ),
              ],
            ),
            const SizedBox(height: 8),
            if (phase == AiExplainPhase.streaming) ...[
              Row(
                children: [
                  const SizedBox(
                    width: 14,
                    height: 14,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  ),
                  const SizedBox(width: 8),
                  Text(
                    ai.explainWaitingLabel,
                    style: const TextStyle(fontSize: 12, color: Color(0xFF94A3B8)),
                  ),
                ],
              ),
              if (ai.explainStreamText.value.isNotEmpty) ...[
                const SizedBox(height: 8),
                Text(
                  ai.explainStreamText.value,
                  style: const TextStyle(
                    fontSize: 12,
                    color: Color(0xFFCBD5E1),
                    height: 1.45,
                  ),
                ),
              ],
            ] else if (phase == AiExplainPhase.error)
              Text(
                ai.explainErrorMessage.value,
                style: const TextStyle(fontSize: 12, color: Color(0xFFF87171)),
              )
            else
              Text(
                ai.explainResult.value,
                style: const TextStyle(
                  fontSize: 12,
                  color: Color(0xFFE2E8F0),
                  height: 1.5,
                ),
              ),
          ],
        ),
      );
    });
  }
}

Widget buildExplainErrorButton({
  required PipelineNode node,
  required bool enabled,
}) {
  return Tooltip(
    message: enabled
        ? 'Explain this error with AI Assistant'
        : 'Enable AI Assistant in Settings first',
    child: TextButton.icon(
      onPressed: enabled
          ? () => Get.find<AiController>().explainError(node: node)
          : null,
      icon: const Icon(Icons.auto_awesome, size: 14, color: Color(0xFF818CF8)),
      label: const Text(
        'Explain',
        style: TextStyle(fontSize: 11, color: Color(0xFF818CF8)),
      ),
      style: TextButton.styleFrom(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      ),
    ),
  );
}

bool nodeHasExplainableError(PipelineNode node) {
  if (node.status == BlockStatus.failed || node.status == BlockStatus.error) {
    return true;
  }
  return node.logs.any(
    (line) => line.contains('[STDERR]') || line.toLowerCase().contains('error'),
  );
}
