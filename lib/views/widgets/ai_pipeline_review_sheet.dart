import 'package:flutter/material.dart';
import 'package:get/get.dart';

import '../../controllers/ai_review_controller.dart';
import '../../models/pipeline_preflight_issue.dart';

class AiPipelineReviewSheet extends StatelessWidget {
  const AiPipelineReviewSheet({super.key});

  @override
  Widget build(BuildContext context) {
    if (!Get.isRegistered<AiReviewController>()) return const SizedBox.shrink();
    final review = Get.find<AiReviewController>();

    return Obx(() {
      if (!review.showSheet.value) return const SizedBox.shrink();

      final isStreaming = review.phase.value == AiReviewPhase.streaming;

      return Align(
        alignment: Alignment.bottomCenter,
        child: Material(
          elevation: 16,
          borderRadius: const BorderRadius.vertical(top: Radius.circular(16)),
          color: Colors.white,
          child: SafeArea(
            top: false,
            child: ConstrainedBox(
              constraints: BoxConstraints(
                maxHeight: MediaQuery.of(context).size.height * 0.6,
                minWidth: MediaQuery.of(context).size.width,
              ),
              child: Padding(
                padding: const EdgeInsets.fromLTRB(20, 16, 12, 20),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        const Expanded(
                          child: Text(
                            'Pipeline review',
                            style: TextStyle(
                              fontSize: 16,
                              fontWeight: FontWeight.w800,
                              color: Color(0xFF0F172A),
                            ),
                          ),
                        ),
                        if (review.reviewedAt.value != null) ...[
                          Text(
                            review.reviewedAgoLabel +
                                (review.isFromCache.value ? ' · cached' : ''),
                            style: const TextStyle(
                              fontSize: 11,
                              color: Color(0xFF94A3B8),
                              fontWeight: FontWeight.w500,
                            ),
                          ),
                          const SizedBox(width: 6),
                          Tooltip(
                            message: 'Run the review again',
                            child: IconButton(
                              onPressed:
                                  isStreaming ? null : review.refreshReview,
                              icon: const Icon(Icons.refresh_rounded, size: 18),
                              visualDensity: VisualDensity.compact,
                            ),
                          ),
                        ],
                        IconButton(
                          onPressed: review.closeReview,
                          icon: const Icon(Icons.close),
                        ),
                      ],
                    ),
                    Expanded(
                      child: SingleChildScrollView(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            _PreflightSection(issues: review.issues),
                            if (isStreaming) ...[
                              const SizedBox(height: 12),
                              Row(
                                children: [
                                  const SizedBox(
                                    width: 14,
                                    height: 14,
                                    child: CircularProgressIndicator(strokeWidth: 2),
                                  ),
                                  const SizedBox(width: 8),
                                  Text(
                                    review.waitingLabel,
                                    style: const TextStyle(
                                      fontSize: 12,
                                      color: Color(0xFF64748B),
                                    ),
                                  ),
                                ],
                              ),
                              if (review.streamText.value.isNotEmpty) ...[
                                const SizedBox(height: 8),
                                Text(
                                  review.streamText.value,
                                  style: const TextStyle(
                                    fontSize: 12.5,
                                    height: 1.45,
                                  ),
                                ),
                              ],
                            ] else if (review.summary.value.isNotEmpty) ...[
                              const SizedBox(height: 12),
                              Row(
                                children: [
                                  const Text(
                                    'AI review',
                                    style: TextStyle(
                                      fontSize: 12,
                                      fontWeight: FontWeight.w700,
                                      color: Color(0xFF475569),
                                    ),
                                  ),
                                  if (review.isFromCache.value) ...[
                                    const SizedBox(width: 6),
                                    Container(
                                      padding: const EdgeInsets.symmetric(
                                          horizontal: 6, vertical: 1),
                                      decoration: BoxDecoration(
                                        color: const Color(0xFFEFF6FF),
                                        borderRadius: BorderRadius.circular(4),
                                      ),
                                      child: const Text(
                                        'cached',
                                        style: TextStyle(
                                          fontSize: 10,
                                          fontWeight: FontWeight.w700,
                                          color: Color(0xFF2563EB),
                                        ),
                                      ),
                                    ),
                                  ],
                                ],
                              ),
                              const SizedBox(height: 6),
                              Text(
                                review.summary.value,
                                style: const TextStyle(
                                  fontSize: 12.5,
                                  height: 1.5,
                                ),
                              ),
                            ] else if (review.phase.value == AiReviewPhase.error)
                              Padding(
                                padding: const EdgeInsets.only(top: 12),
                                child: Text(
                                  review.errorMessage.value,
                                  style: const TextStyle(
                                    color: Color(0xFFB91C1C),
                                    fontSize: 12,
                                  ),
                                ),
                              ),
                          ],
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      );
    });
  }
}

class _PreflightSection extends StatelessWidget {
  const _PreflightSection({required this.issues});

  final List<PipelinePreflightIssue> issues;

  @override
  Widget build(BuildContext context) {
    if (issues.isEmpty) {
      return const Text(
        '✅ Pre-flight: no structural blockers found.',
        style: TextStyle(
          fontSize: 13,
          color: Color(0xFF059669),
          fontWeight: FontWeight.w600,
        ),
      );
    }

    final blockers =
        issues.where((i) => i.severity == PreflightSeverity.blocker).toList();
    final warnings =
        issues.where((i) => i.severity == PreflightSeverity.warning).toList();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        if (blockers.isNotEmpty)
          _IssueGroup(
            title: '${blockers.length} blocker${blockers.length == 1 ? '' : 's'} — fix before running',
            color: const Color(0xFFB91C1C),
            background: const Color(0xFFFEF2F2),
            issues: blockers,
          ),
        if (warnings.isNotEmpty) ...[
          if (blockers.isNotEmpty) const SizedBox(height: 10),
          _IssueGroup(
            title: '${warnings.length} warning${warnings.length == 1 ? '' : 's'} — worth reviewing',
            color: const Color(0xFF92400E),
            background: const Color(0xFFFFFBEB),
            issues: warnings,
          ),
        ],
      ],
    );
  }
}

class _IssueGroup extends StatelessWidget {
  const _IssueGroup({
    required this.title,
    required this.color,
    required this.background,
    required this.issues,
  });

  final String title;
  final Color color;
  final Color background;
  final List<PipelinePreflightIssue> issues;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(10),
      decoration: BoxDecoration(
        color: background,
        borderRadius: BorderRadius.circular(8),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            title,
            style: TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.w700,
              color: color,
            ),
          ),
          const SizedBox(height: 6),
          ...issues.map(
            (issue) => Padding(
              padding: const EdgeInsets.only(bottom: 4),
              child: Text(
                issue.message,
                style: const TextStyle(
                  fontSize: 12.5,
                  height: 1.4,
                  color: Color(0xFF334155),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
