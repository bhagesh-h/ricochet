// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'pipeline_file.dart';

// **************************************************************************
// JsonSerializableGenerator
// **************************************************************************

PipelineFile _$PipelineFileFromJson(Map<String, dynamic> json) => PipelineFile(
      id: json['id'] as String,
      name: json['name'] as String,
      folderPath: json['folderPath'] as String,
      nodes: (json['nodes'] as List<dynamic>?)
              ?.map((e) => PipelineNode.fromJson(e as Map<String, dynamic>))
              .toList() ??
          const [],
      connections: (json['connections'] as List<dynamic>?)
              ?.map((e) => Connection.fromJson(e as Map<String, dynamic>))
              .toList() ??
          const [],
    );

Map<String, dynamic> _$PipelineFileToJson(PipelineFile instance) =>
    <String, dynamic>{
      'id': instance.id,
      'name': instance.name,
      'folderPath': instance.folderPath,
      'nodes': instance.nodes.map((e) => e.toJson()).toList(),
      'connections': instance.connections.map((e) => e.toJson()).toList(),
    };
