import 'package:flutter/material.dart';

/// High-level generate / review session state.
enum AiDraftPhase {
  idle,
  streaming,
  validating,
  draftActive,
  error,
}

enum AiGhostStatus {
  pending,
  accepted,
  summary,
}

/// A read-only preview node on the canvas before acceptance.
class AiGhostNode {
  final String id;
  final int index;
  final String nodeType;
  final Offset position;
  final Map<String, dynamic> parameterOverrides;
  final AiGhostStatus status;
  final bool isUnknownImage;
  final int? summaryHiddenCount;
  final int? summaryScrollToIndex;

  const AiGhostNode({
    required this.id,
    required this.index,
    required this.nodeType,
    required this.position,
    this.parameterOverrides = const {},
    this.status = AiGhostStatus.pending,
    this.isUnknownImage = false,
    this.summaryHiddenCount,
    this.summaryScrollToIndex,
  });

  bool get isSummary => status == AiGhostStatus.summary;

  String get displayTitle {
    if (isSummary) {
      return '+ $summaryHiddenCount more nodes';
    }
    if (nodeType.startsWith('docker:')) {
      return nodeType.substring(7);
    }
    return nodeType;
  }

  AiGhostNode copyWith({
    AiGhostStatus? status,
    Offset? position,
  }) {
    return AiGhostNode(
      id: id,
      index: index,
      nodeType: nodeType,
      position: position ?? this.position,
      parameterOverrides: parameterOverrides,
      status: status ?? this.status,
      isUnknownImage: isUnknownImage,
      summaryHiddenCount: summaryHiddenCount,
      summaryScrollToIndex: summaryScrollToIndex,
    );
  }
}

/// Cosmetic progress labels during generation.
enum AiGenerateProgressStep {
  reading('Reading your description…'),
  matching('Matching bioinformatics tools…'),
  building('Building pipeline graph…'),
  receiving('Receiving draft…');

  const AiGenerateProgressStep(this.label);
  final String label;
}
