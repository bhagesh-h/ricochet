import 'package:flutter/material.dart';
import 'package:get/get.dart';

import '../../controllers/ai_controller.dart';

class AiCommandSuggestPanel extends StatelessWidget {
  final String nodeId;
  final String paramKey;
  final String partialCommand;
  final VoidCallback onAccept;
  final VoidCallback onRegenerate;

  const AiCommandSuggestPanel({
    super.key,
    required this.nodeId,
    required this.paramKey,
    required this.partialCommand,
    required this.onAccept,
    required this.onRegenerate,
  });

  @override
  Widget build(BuildContext context) {
    if (!Get.isRegistered<AiController>()) return const SizedBox.shrink();
    final ai = Get.find<AiController>();

    return Obx(() {
      if (ai.commandNodeId.value != nodeId ||
          ai.commandParamKey.value != paramKey) {
        return const SizedBox.shrink();
      }

      final phase = ai.commandPhase.value;
      if (phase == AiCommandSuggestPhase.idle) {
        return const SizedBox.shrink();
      }

      if (phase == AiCommandSuggestPhase.streaming) {
        return _StreamingCard(ai: ai);
      }

      if (phase == AiCommandSuggestPhase.error) {
        return _ErrorCard(
          message: ai.commandError.value,
          onDismiss: ai.discardCommandSuggestion,
        );
      }

      return _DiffCard(
        ai: ai,
        onAccept: onAccept,
        onDiscard: ai.discardCommandSuggestion,
        onRegenerate: onRegenerate,
      );
    });
  }
}

class _SuggestChip extends StatelessWidget {
  final bool enabled;
  final bool truncated;
  final VoidCallback onTap;

  const _SuggestChip({
    required this.enabled,
    required this.truncated,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Tooltip(
      message: truncated
          ? 'Limited context — large pipeline'
          : 'Suggest a command with AI Assistant',
      child: ActionChip(
        avatar: const Icon(Icons.auto_awesome, size: 14, color: Color(0xFF6366F1)),
        label: const Text('Suggest'),
        onPressed: enabled ? onTap : null,
        backgroundColor: const Color(0xFFEEF2FF),
        side: const BorderSide(color: Color(0xFFC7D2FE)),
        labelStyle: const TextStyle(
          fontSize: 12,
          fontWeight: FontWeight.w700,
          color: Color(0xFF4338CA),
        ),
      ),
    );
  }
}

Widget buildAiSuggestChip({
  required bool enabled,
  required bool truncated,
  required VoidCallback onTap,
}) {
  return _SuggestChip(enabled: enabled, truncated: truncated, onTap: onTap);
}

class _StreamingCard extends StatelessWidget {
  final AiController ai;
  const _StreamingCard({required this.ai});

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: const Color(0xFFF8FAFC),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: const Color(0xFFE2E8F0)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const SizedBox(
                width: 14,
                height: 14,
                child: CircularProgressIndicator(strokeWidth: 2),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  ai.commandWaitingLabel,
                  style: const TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
                    color: Color(0xFF475569),
                  ),
                ),
              ),
              TextButton(
                onPressed: ai.cancelCommandSuggestion,
                child: const Text('Cancel'),
              ),
            ],
          ),
          if (ai.commandStreamText.value.isNotEmpty) ...[
            const SizedBox(height: 8),
            Text(
              ai.commandStreamText.value,
              style: const TextStyle(
                fontFamily: 'monospace',
                fontSize: 12,
                color: Color(0xFF0F172A),
              ),
            ),
          ],
        ],
      ),
    );
  }
}

class _DiffCard extends StatelessWidget {
  final AiController ai;
  final VoidCallback onAccept;
  final VoidCallback onDiscard;
  final VoidCallback onRegenerate;

  const _DiffCard({
    required this.ai,
    required this.onAccept,
    required this.onDiscard,
    required this.onRegenerate,
  });

  @override
  Widget build(BuildContext context) {
    final original = ai.commandOriginal.value;
    final proposed = ai.commandProposed.value;
    final alt = ai.commandRegenerateCount.value;

    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: const Color(0xFFF0FDF4),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: const Color(0xFF86EFAC)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Icon(Icons.auto_awesome, size: 14, color: Color(0xFF059669)),
              const SizedBox(width: 6),
              Text(
                alt > 0 ? 'Suggested command · Alternative $alt' : 'Suggested command',
                style: const TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w700,
                  color: Color(0xFF047857),
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          if (original.trim().isNotEmpty)
            Text(
              original,
              style: const TextStyle(
                fontFamily: 'monospace',
                fontSize: 12,
                color: Color(0xFF94A3B8),
                decoration: TextDecoration.lineThrough,
                decorationColor: Color(0xFF94A3B8),
              ),
            ),
          if (original.trim().isNotEmpty) const SizedBox(height: 6),
          Text(
            proposed,
            style: const TextStyle(
              fontFamily: 'monospace',
              fontSize: 12.5,
              color: Color(0xFF166534),
              fontWeight: FontWeight.w600,
            ),
          ),
          const SizedBox(height: 10),
          Wrap(
            spacing: 8,
            children: [
              FilledButton(
                onPressed: onAccept,
                style: FilledButton.styleFrom(
                  backgroundColor: const Color(0xFF059669),
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                ),
                child: const Text('Accept'),
              ),
              OutlinedButton(
                onPressed: onRegenerate,
                child: const Text('Regenerate'),
              ),
              TextButton(
                onPressed: onDiscard,
                child: const Text('Discard'),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _ErrorCard extends StatelessWidget {
  final String message;
  final VoidCallback onDismiss;

  const _ErrorCard({required this.message, required this.onDismiss});

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: const Color(0xFFFEF2F2),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: const Color(0xFFFECACA)),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Icon(Icons.error_outline, size: 16, color: Color(0xFFDC2626)),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              message,
              style: const TextStyle(fontSize: 12, color: Color(0xFFB91C1C)),
            ),
          ),
          TextButton(onPressed: onDismiss, child: const Text('Dismiss')),
        ],
      ),
    );
  }
}
