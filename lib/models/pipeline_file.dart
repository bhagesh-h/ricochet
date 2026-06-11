import 'package:json_annotation/json_annotation.dart';
import 'pipeline_node.dart';

part 'pipeline_file.g.dart';

@JsonSerializable(explicitToJson: true)
class PipelineFile {
  final String id;
  String name;
  String folderPath; // mutable to support rename
  List<PipelineNode> nodes;
  List<Connection> connections;
  
  @JsonKey(includeFromJson: false, includeToJson: false)
  bool hasUnsavedChanges;

  PipelineFile({
    required this.id,
    required this.name,
    required this.folderPath,
    this.nodes = const [],
    this.connections = const [],
    this.hasUnsavedChanges = false,
  });

  factory PipelineFile.fromJson(Map<String, dynamic> json) => _$PipelineFileFromJson(json);
  Map<String, dynamic> toJson() => _$PipelineFileToJson(this);
}
