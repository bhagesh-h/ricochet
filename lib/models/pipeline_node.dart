import 'dart:ui';

class PipelineNode {
  final String id;
  final String title;
  Offset position;
  Map<String, dynamic> config;

  PipelineNode({
    required this.id,
    required this.title,
    required this.position,
    Map<String, dynamic>? config,
  }) : config = config ?? {};
}
