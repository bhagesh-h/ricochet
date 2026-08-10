/// Severity of a pipeline pre-flight finding.
///
/// - [blocker]: the pipeline will very likely fail to run correctly and
///   should be fixed first.
/// - [warning]: not fatal, but worth reviewing before running.
/// - [info]: informational context, no action required.
enum PreflightSeverity { blocker, warning, info }

/// A single structural finding surfaced by [AiPipelinePreflightService]
/// and shown in the AI pipeline review sheet.
class PipelinePreflightIssue {
  const PipelinePreflightIssue({
    required this.message,
    required this.severity,
    this.nodeId,
  });

  final String message;
  final PreflightSeverity severity;

  /// Optional id of the node this issue relates to (for future "jump to
  /// node" affordances).
  final String? nodeId;

  @override
  String toString() => message;

  @override
  bool operator ==(Object other) =>
      other is PipelinePreflightIssue &&
      other.message == message &&
      other.severity == severity &&
      other.nodeId == nodeId;

  @override
  int get hashCode => Object.hash(message, severity, nodeId);
}
