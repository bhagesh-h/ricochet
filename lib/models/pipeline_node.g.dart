// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'pipeline_node.dart';

// **************************************************************************
// JsonSerializableGenerator
// **************************************************************************

BlockParameter _$BlockParameterFromJson(Map<String, dynamic> json) =>
    BlockParameter(
      id: json['id'] as String?,
      key: json['key'] as String,
      label: json['label'] as String,
      type: $enumDecode(_$ParameterTypeEnumMap, json['type']),
      value: json['value'],
      options:
          (json['options'] as List<dynamic>?)?.map((e) => e as String).toList(),
      placeholder: json['placeholder'] as String?,
      required: json['required'] as bool? ?? false,
    );

Map<String, dynamic> _$BlockParameterToJson(BlockParameter instance) =>
    <String, dynamic>{
      'id': instance.id,
      'key': instance.key,
      'label': instance.label,
      'type': _$ParameterTypeEnumMap[instance.type]!,
      'value': instance.value,
      'options': instance.options,
      'placeholder': instance.placeholder,
      'required': instance.required,
    };

const _$ParameterTypeEnumMap = {
  ParameterType.text: 'text',
  ParameterType.dropdown: 'dropdown',
  ParameterType.toggle: 'toggle',
  ParameterType.file: 'file',
  ParameterType.numeric: 'numeric',
  ParameterType.multiFile: 'multiFile',
};

PipelineNode _$PipelineNodeFromJson(Map<String, dynamic> json) => PipelineNode(
      id: json['id'] as String,
      title: json['title'] as String,
      description: json['description'] as String,
      position: const OffsetConverter()
          .fromJson(json['position'] as Map<String, dynamic>),
      category: $enumDecode(_$BlockCategoryEnumMap, json['category']),
      parameters: (json['parameters'] as List<dynamic>)
          .map((e) => BlockParameter.fromJson(e as Map<String, dynamic>))
          .toList(),
      inputPorts: (json['inputPorts'] as List<dynamic>?)
              ?.map((e) => e as String)
              .toList() ??
          const ['input'],
      outputPorts: (json['outputPorts'] as List<dynamic>?)
              ?.map((e) => e as String)
              .toList() ??
          const ['output'],
      iconCodePoint: json['iconCodePoint'] as String,
      dockerImage: json['dockerImage'] as String?,
      outputFileName: json['outputFileName'] as String?,
      isAggregator: json['isAggregator'] as bool? ?? false,
    );

Map<String, dynamic> _$PipelineNodeToJson(PipelineNode instance) =>
    <String, dynamic>{
      'id': instance.id,
      'title': instance.title,
      'description': instance.description,
      'position': const OffsetConverter().toJson(instance.position),
      'category': _$BlockCategoryEnumMap[instance.category]!,
      'parameters': instance.parameters.map((e) => e.toJson()).toList(),
      'inputPorts': instance.inputPorts,
      'outputPorts': instance.outputPorts,
      'iconCodePoint': instance.iconCodePoint,
      'dockerImage': instance.dockerImage,
      'outputFileName': instance.outputFileName,
      'isAggregator': instance.isAggregator,
    };

const _$BlockCategoryEnumMap = {
  BlockCategory.input: 'input',
  BlockCategory.output: 'output',
  BlockCategory.processing: 'processing',
  BlockCategory.analysis: 'analysis',
  BlockCategory.visualization: 'visualization',
};

Connection _$ConnectionFromJson(Map<String, dynamic> json) => Connection(
      id: json['id'] as String,
      fromNodeId: json['fromNodeId'] as String,
      toNodeId: json['toNodeId'] as String,
      fromPort: json['fromPort'] as String? ?? 'output',
      toPort: json['toPort'] as String? ?? 'input',
      fromPoint: const NullableOffsetConverter()
          .fromJson(json['fromPoint'] as Map<String, dynamic>?),
      toPoint: const NullableOffsetConverter()
          .fromJson(json['toPoint'] as Map<String, dynamic>?),
    );

Map<String, dynamic> _$ConnectionToJson(Connection instance) =>
    <String, dynamic>{
      'id': instance.id,
      'fromNodeId': instance.fromNodeId,
      'toNodeId': instance.toNodeId,
      'fromPort': instance.fromPort,
      'toPort': instance.toPort,
      'fromPoint': const NullableOffsetConverter().toJson(instance.fromPoint),
      'toPoint': const NullableOffsetConverter().toJson(instance.toPoint),
    };
