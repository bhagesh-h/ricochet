/// True when Docker reports the image reference cannot be resolved.
bool isDockerImageNotFoundError(String message) {
  final lower = message.toLowerCase();
  return lower.contains('not found') ||
      lower.contains('manifest unknown') ||
      lower.contains('failed to resolve reference') ||
      lower.contains('no such image') ||
      lower.contains('name unknown');
}
