/// Stable identity for filesystem paths, hash files, and Docker resources.
///
/// Combines tab + node ids so parallel runs and similarly named nodes never
/// collide, regardless of title or timestamp.
class NodeExecutionIdentity {
  final String tabId;
  final String nodeId;
  final String nodeTitle;

  const NodeExecutionIdentity({
    required this.tabId,
    required this.nodeId,
    required this.nodeTitle,
  });

  String get _sanitizedTitle =>
      nodeTitle.replaceAll(RegExp(r'[^a-zA-Z0-9_-]'), '_');

  String get _idFragment {
    final clean = nodeId.replaceAll(RegExp(r'[^a-zA-Z0-9_-]'), '');
    if (clean.isEmpty) return 'node';
    return clean.length <= 8 ? clean : clean.substring(0, 8);
  }

  /// Used for temp staging directories and final output folder suffixes.
  String get pathSuffix => '${_sanitizedTitle}_${_idFragment}_$tabId';

  /// Used for content-addressed hash sidecar files during deduplication.
  String get hashFileName => '.${_sanitizedTitle}_${_idFragment}_hash';

  /// Docker container name — must be unique per running container (max 64 chars).
  String get containerName {
    final tabFragment = tabId.replaceAll('-', '').substring(0, 12);
    final nodeFragment = nodeId.replaceAll('-', '').substring(0, 12);
    return 'r_${tabFragment}_$nodeFragment';
  }
}
