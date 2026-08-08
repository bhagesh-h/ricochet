/// Cached OpenAI-style messages for command suggest + regenerate.
class AiPromptBundle {
  final List<Map<String, String>> baseMessages;
  final bool contextTruncated;
  final String nodeId;
  final String paramKey;

  const AiPromptBundle({
    required this.baseMessages,
    required this.contextTruncated,
    required this.nodeId,
    required this.paramKey,
  });

  List<Map<String, String>> initialMessages() =>
      List<Map<String, String>>.from(baseMessages);

  List<Map<String, String>> regenerateMessages(String previousSuggestion) {
    return [
      ...baseMessages,
      {'role': 'assistant', 'content': previousSuggestion},
      {
        'role': 'user',
        'content':
            'Provide a different command alternative. Do not repeat the previous suggestion.',
      },
    ];
  }
}

/// Strips markdown fences from model output when present.
String extractShellCommand(String raw) {
  var text = raw.trim();
  if (!text.startsWith('```')) return text;

  final lines = text.split('\n');
  if (lines.length < 2) return text;

  var end = lines.length;
  if (lines.last.trim() == '```') {
    end = lines.length - 1;
  }
  return lines.sublist(1, end).join('\n').trim();
}

/// Normalizes model output into a Docker Hub search query.
String extractSearchQuery(String raw) {
  var text = extractShellCommand(raw).trim();
  if (text.startsWith('"') && text.endsWith('"') && text.length > 1) {
    text = text.substring(1, text.length - 1);
  }
  if (text.startsWith("'") && text.endsWith("'") && text.length > 1) {
    text = text.substring(1, text.length - 1);
  }
  return text.replaceAll(RegExp(r'\s+'), ' ').trim();
}

/// Caps execution logs sent to the model for error explain.
String buildLogExcerpt(
  List<String> logs, {
  int maxLines = 40,
  int maxChars = 3000,
}) {
  if (logs.isEmpty) return '';

  final prioritized = logs.where((line) {
    final lower = line.toLowerCase();
    return line.contains('[STDERR]') ||
        line.contains('[SYSTEM]') ||
        lower.contains('error') ||
        lower.contains('failed');
  }).toList();

  var slice = (prioritized.isNotEmpty ? prioritized : logs);
  if (slice.length > maxLines) {
    slice = slice.sublist(slice.length - maxLines);
  }

  var text = slice.join('\n');
  if (text.length > maxChars) {
    text = text.substring(text.length - maxChars);
  }
  return text;
}

bool isLogExcerptTruncated(
  List<String> logs, {
  int maxLines = 40,
  int maxChars = 3000,
}) {
  if (logs.isEmpty) return false;
  final prioritized = logs.where((line) {
    final lower = line.toLowerCase();
    return line.contains('[STDERR]') ||
        line.contains('[SYSTEM]') ||
        lower.contains('error') ||
        lower.contains('failed');
  }).toList();
  final source = prioritized.isNotEmpty ? prioritized : logs;
  if (source.length > maxLines) return true;
  return source.join('\n').length > maxChars;
}
