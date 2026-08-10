import 'package:flutter/material.dart';

import '../../controllers/ai_draft_controller.dart';
import '../../models/ai_draft_session.dart';
import '../../services/ai_unknown_node_suggestions.dart';

class AiGhostUnknownChips extends StatelessWidget {
  final AiGhostNode ghost;
  final AiDraftController draft;

  const AiGhostUnknownChips({
    super.key,
    required this.ghost,
    required this.draft,
  });

  @override
  Widget build(BuildContext context) {
    if (!ghost.isUnknownImage || ghost.isSummary) {
      return const SizedBox.shrink();
    }

    final suggestions = AiUnknownNodeSuggestions.suggestionsFor(ghost.nodeType);

    return Padding(
      padding: const EdgeInsets.only(top: 8),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Not a built-in Ricochet block. Try:',
            style: TextStyle(fontSize: 11, color: Color(0xFF92400E)),
          ),
          const SizedBox(height: 6),
          Wrap(
            spacing: 6,
            runSpacing: 6,
            children: [
              for (final option in suggestions.take(3))
                ActionChip(
                  label: Text(
                    option.startsWith('docker:')
                        ? option.substring(7)
                        : option,
                    style: const TextStyle(fontSize: 11),
                  ),
                  onPressed: () => draft.swapGhostNodeType(ghost.index, option),
                  backgroundColor: const Color(0xFFFFFBEB),
                  side: const BorderSide(color: Color(0xFFFCD34D)),
                ),
              ActionChip(
                avatar: const Icon(Icons.search, size: 14, color: Color(0xFF6366F1)),
                label: const Text('Search Hub', style: TextStyle(fontSize: 11)),
                onPressed: () => draft.searchHubForGhost(ghost.index),
                backgroundColor: const Color(0xFFEEF2FF),
                side: const BorderSide(color: Color(0xFFC7D2FE)),
              ),
              ActionChip(
                avatar: const Icon(Icons.delete_outline, size: 14, color: Color(0xFFB91C1C)),
                label: const Text('Remove', style: TextStyle(fontSize: 11)),
                onPressed: () => draft.removeGhostAt(ghost.index),
                backgroundColor: const Color(0xFFFEF2F2),
                side: const BorderSide(color: Color(0xFFFECACA)),
              ),
            ],
          ),
        ],
      ),
    );
  }
}
