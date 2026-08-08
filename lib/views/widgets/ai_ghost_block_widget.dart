import 'package:flutter/material.dart';

import '../../models/ai_draft_session.dart';

class AiGhostBlockWidget extends StatelessWidget {
  final AiGhostNode ghost;
  final bool focused;
  final VoidCallback? onTap;
  final VoidCallback? onHover;

  const AiGhostBlockWidget({
    super.key,
    required this.ghost,
    this.focused = false,
    this.onTap,
    this.onHover,
  });

  @override
  Widget build(BuildContext context) {
    final borderColor = ghost.isSummary
        ? const Color(0xFF94A3B8)
        : ghost.isUnknownImage
            ? const Color(0xFFF59E0B)
            : const Color(0xFF6366F1);

    return MouseRegion(
      onEnter: (_) => onHover?.call(),
      child: GestureDetector(
        onTap: onTap,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 180),
          width: 180,
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
          decoration: BoxDecoration(
            color: Colors.white.withOpacity(0.72),
            borderRadius: BorderRadius.circular(12),
            border: Border.all(
              color: focused ? borderColor : borderColor.withOpacity(0.55),
              width: focused ? 2.5 : 1.5,
              strokeAlign: BorderSide.strokeAlignOutside,
            ),
            boxShadow: [
              BoxShadow(
                color: borderColor.withOpacity(focused ? 0.25 : 0.12),
                blurRadius: focused ? 14 : 8,
                offset: const Offset(0, 3),
              ),
            ],
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              Row(
                children: [
                  Icon(
                    ghost.isSummary
                        ? Icons.more_horiz_rounded
                        : Icons.auto_awesome,
                    size: 14,
                    color: borderColor,
                  ),
                  const SizedBox(width: 6),
                  Expanded(
                    child: Text(
                      ghost.displayTitle,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.w700,
                        color: borderColor.withOpacity(0.95),
                      ),
                    ),
                  ),
                ],
              ),
              if (!ghost.isSummary) ...[
                const SizedBox(height: 4),
                Text(
                  ghost.isUnknownImage ? 'Unknown image' : 'Suggested',
                  style: TextStyle(
                    fontSize: 10.5,
                    color: borderColor.withOpacity(0.8),
                  ),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}
