import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:json_annotation/json_annotation.dart';

part 'pipeline_node.g.dart';

class OffsetConverter implements JsonConverter<Offset, Map<String, dynamic>> {
  const OffsetConverter();

  @override
  Offset fromJson(Map<String, dynamic> json) {
    return Offset((json['dx'] as num).toDouble(), (json['dy'] as num).toDouble());
  }

  @override
  Map<String, dynamic> toJson(Offset object) {
    return {'dx': object.dx, 'dy': object.dy};
  }
}

class NullableOffsetConverter implements JsonConverter<Offset?, Map<String, dynamic>?> {
  const NullableOffsetConverter();

  @override
  Offset? fromJson(Map<String, dynamic>? json) {
    if (json == null) return null;
    return Offset((json['dx'] as num).toDouble(), (json['dy'] as num).toDouble());
  }

  @override
  Map<String, dynamic>? toJson(Offset? object) {
    if (object == null) return null;
    return {'dx': object.dx, 'dy': object.dy};
  }
}


enum BlockCategory { input, output, processing, analysis, visualization }

enum BlockStatus {
  idle, // Just placed on canvas
  checking, // Checking if image exists
  downloading, // Pulling Docker image
  ready, // Image available, ready to execute
  pending, // Waiting to execute
  running, // Container executing
  success, // Execution completed
  failed, // Execution failed
  error, // Configuration or download error
}

@JsonSerializable(explicitToJson: true)

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

  factory BlockParameter.fromJson(Map<String, dynamic> json) => _$BlockParameterFromJson(json);
  Map<String, dynamic> toJson() => _$BlockParameterToJson(this);
}

enum ParameterType { text, dropdown, toggle, file, numeric }

@JsonSerializable(explicitToJson: true)

class PipelineNode {
  final String id;
  final String title;
  final String description;
  @OffsetConverter()
  Offset position;
  final BlockCategory category;
  final List<BlockParameter> parameters;
  
  @JsonKey(includeFromJson: false, includeToJson: false)
  BlockStatus status;
  
  final List<String> inputPorts;
  final List<String> outputPorts;
  
  @JsonKey(includeFromJson: false, includeToJson: false)
  bool isSelected;
  
  final String iconCodePoint;

  // Docker image tracking
  String? dockerImage; 
  
  @JsonKey(includeFromJson: false, includeToJson: false)
  double downloadProgress;
  
  @JsonKey(includeFromJson: false, includeToJson: false)
  String? downloadStatus;
  
  @JsonKey(includeFromJson: false, includeToJson: false)
  bool isImageLocal;
  
  // Export Settings
  String? outputFileName;
  bool isAggregator;

  @JsonKey(includeFromJson: false, includeToJson: false)
  final List<String> logs;

  PipelineNode({
    required this.id,
    required this.title,
    required this.description,
    required this.position,
    required this.category,
    required this.parameters,
    this.status = BlockStatus.idle,
    this.inputPorts = const ['input'],
    this.outputPorts = const ['output'],
    this.isSelected = false,
    required this.iconCodePoint,
    this.dockerImage,
    this.downloadProgress = 0.0,
    this.downloadStatus,
    this.isImageLocal = false,
    this.outputFileName,
    this.isAggregator = false,
    List<String>? logs,
  }) : logs = logs ?? [];

  factory PipelineNode.fromJson(Map<String, dynamic> json) => _$PipelineNodeFromJson(json);
  Map<String, dynamic> toJson() => _$PipelineNodeToJson(this);

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

@JsonSerializable(explicitToJson: true)
class Connection {
  final String id;
  final String fromNodeId;
  final String toNodeId;
  final String fromPort;
  final String toPort;
  
  @NullableOffsetConverter()
  final Offset? fromPoint;
  
  @NullableOffsetConverter()
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

  factory Connection.fromJson(Map<String, dynamic> json) => _$ConnectionFromJson(json);
  Map<String, dynamic> toJson() => _$ConnectionToJson(this);
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
