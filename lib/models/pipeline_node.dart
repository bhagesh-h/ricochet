import 'dart:ui';

import 'package:flutter/material.dart';

enum BlockCategory { input, output, processing, analysis, visualization }
enum BlockStatus { pending, running, success, failed }

class BlockParameter {
  final String id;
  String key;
  String label;
  final ParameterType type;
  dynamic value;
  final List<String>? options;
  final String? placeholder;
  final bool required;

  BlockParameter({
    String? id,
    required this.key,
    required this.label,
    required this.type,
    this.value,
    this.options,
    this.placeholder,
    this.required = false,
  }) : id = id ?? DateTime.now().millisecondsSinceEpoch.toString();
}

enum ParameterType { text, dropdown, toggle, file, numeric }

class PipelineNode {
  final String id;
  final String title;
  final String description;
  Offset position;
  final BlockCategory category;
  final List<BlockParameter> parameters;
  BlockStatus status;
  final List<String> inputPorts;
  final List<String> outputPorts;
  bool isSelected;
  final String iconCodePoint;

  PipelineNode({
    required this.id,
    required this.title,
    required this.description,
    required this.position,
    required this.category,
    required this.parameters,
    this.status = BlockStatus.pending,
    this.inputPorts = const ['input'],
    this.outputPorts = const ['output'],
    this.isSelected = false,
    required this.iconCodePoint,
  });

  Color get primaryColor {
    switch (category) {
      case BlockCategory.input:
        return const Color(0xFF3B82F6);
      case BlockCategory.output:
        return const Color(0xFFEF4444);
      case BlockCategory.processing:
        return const Color(0xFF8B5CF6);
      case BlockCategory.analysis:
        return const Color(0xFF10B981);
      case BlockCategory.visualization:
        return const Color(0xFFF59E0B);
    }
  }

  Color get backgroundColor {
    switch (category) {
      case BlockCategory.input:
        return const Color(0xFFF0F9FF);
      case BlockCategory.output:
        return const Color(0xFFFEF2F2);
      case BlockCategory.processing:
        return const Color(0xFFFAF5FF);
      case BlockCategory.analysis:
        return const Color(0xFFF0FDF4);
      case BlockCategory.visualization:
        return const Color(0xFFFFFBEB);
    }
  }

  IconData get icon {
    switch (category) {
      case BlockCategory.input:
        return Icons.download_rounded;
      case BlockCategory.output:
        return Icons.upload_rounded;
      case BlockCategory.processing:
        return Icons.transform_rounded;
      case BlockCategory.analysis:
        return Icons.analytics_rounded;
      case BlockCategory.visualization:
        return Icons.bar_chart_rounded;
    }
  }
}

class Connection {
  final String id;
  final String fromNodeId;
  final String toNodeId;
  final String fromPort;
  final String toPort;
  final Offset? fromPoint;
  final Offset? toPoint;

  Connection({
    required this.id,
    required this.fromNodeId,
    required this.toNodeId,
    this.fromPort = 'output',
    this.toPort = 'input',
    this.fromPoint,
    this.toPoint,
  });
}

// Extension for legacy compatibility
extension PipelineNodeConfig on PipelineNode {
  Map<String, dynamic> get config {
    Map<String, dynamic> configMap = {};
    for (var param in parameters) {
      if (param.value != null) {
        configMap[param.key] = param.value;
      }
    }
    return configMap;
  }
}
