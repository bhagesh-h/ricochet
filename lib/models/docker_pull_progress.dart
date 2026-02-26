/// Docker image pull progress information
class DockerPullProgress {
  final String imageName;
  final PullStatus status;
  final String layerId;
  final String statusText;
  final int? currentBytes;
  final int? totalBytes;
  final double percentage;
  final String message;
  final DateTime timestamp;

  DockerPullProgress({
    required this.imageName,
    required this.status,
    this.layerId = '',
    this.statusText = '',
    this.currentBytes,
    this.totalBytes,
    required this.percentage,
    required this.message,
    DateTime? timestamp,
  }) : timestamp = timestamp ?? DateTime.now();

  /// Create a starting progress
  factory DockerPullProgress.starting(String imageName) {
    return DockerPullProgress(
      imageName: imageName,
      status: PullStatus.starting,
      percentage: 0.0,
      message: 'Starting pull...',
    );
  }

  /// Create a downloading progress
  factory DockerPullProgress.downloading({
    required String imageName,
    required String layerId,
    int? currentBytes,
    int? totalBytes,
    required double percentage,
  }) {
    final current = _formatBytes(currentBytes);
    final total = _formatBytes(totalBytes);
    final message = totalBytes != null
        ? 'Downloading $layerId: $current / $total'
        : 'Downloading $layerId...';

    return DockerPullProgress(
      imageName: imageName,
      status: PullStatus.downloading,
      layerId: layerId,
      statusText: 'Downloading',
      currentBytes: currentBytes,
      totalBytes: totalBytes,
      percentage: percentage,
      message: message,
    );
  }

  /// Create an extracting progress
  factory DockerPullProgress.extracting({
    required String imageName,
    required String layerId,
    required double percentage,
  }) {
    return DockerPullProgress(
      imageName: imageName,
      status: PullStatus.extracting,
      layerId: layerId,
      statusText: 'Extracting',
      percentage: percentage,
      message: 'Extracting $layerId...',
    );
  }

  /// Create a complete progress
  factory DockerPullProgress.complete(String imageName) {
    return DockerPullProgress(
      imageName: imageName,
      status: PullStatus.complete,
      percentage: 1.0,
      message: 'Pull complete!',
    );
  }

  /// Create an error progress
  factory DockerPullProgress.error(String imageName, String error) {
    return DockerPullProgress(
      imageName: imageName,
      status: PullStatus.error,
      percentage: 0.0,
      message: 'Error: $error',
    );
  }

  /// Format bytes to human-readable string
  static String _formatBytes(int? bytes) {
    if (bytes == null) return '0 B';
    if (bytes < 1024) return '$bytes B';
    if (bytes < 1024 * 1024) return '${(bytes / 1024).toStringAsFixed(1)} KB';
    if (bytes < 1024 * 1024 * 1024) {
      return '${(bytes / (1024 * 1024)).toStringAsFixed(1)} MB';
    }
    return '${(bytes / (1024 * 1024 * 1024)).toStringAsFixed(1)} GB';
  }

  @override
  String toString() {
    return 'DockerPullProgress(image: $imageName, status: $status, '
        'progress: ${(percentage * 100).toStringAsFixed(1)}%, message: $message)';
  }
}

/// Status of Docker image pull operation
enum PullStatus {
  starting, // Pull initiated
  downloading, // Downloading layers
  extracting, // Extracting layers
  complete, // Pull complete
  error, // Pull failed
}

extension PullStatusExtension on PullStatus {
  String get displayName {
    switch (this) {
      case PullStatus.starting:
        return 'Starting';
      case PullStatus.downloading:
        return 'Downloading';
      case PullStatus.extracting:
        return 'Extracting';
      case PullStatus.complete:
        return 'Complete';
      case PullStatus.error:
        return 'Error';
    }
  }
}
