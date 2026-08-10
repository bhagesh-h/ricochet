/// Heuristic swap/search suggestions for unrecognized draft node types.
class AiUnknownNodeSuggestions {
  AiUnknownNodeSuggestions._();

  static const List<String> defaultSwapOptions = [
    'FastQC',
    'BWA',
    'Samtools',
    'STAR',
    'docker:biocontainers/samtools:latest',
  ];

  static List<String> suggestionsFor(String nodeType) {
    final normalized = nodeType.trim();
    if (normalized.isEmpty) return defaultSwapOptions;

    final lower = normalized.toLowerCase();
    if (lower.startsWith('docker:')) {
      final image = normalized.substring(7);
      final repo = image.contains(':') ? image.split(':').first : image;
      return [
        'docker:$repo:latest',
        'docker:biocontainers/$repo:latest',
        'docker:staphb/$repo:latest',
      ];
    }

    if (lower.contains('qc') || lower.contains('fastq')) {
      return ['FastQC', 'docker:biocontainers/fastqc:latest', 'Trimmomatic'];
    }
    if (lower.contains('align') || lower.contains('bwa') || lower.contains('map')) {
      return ['BWA', 'STAR', 'docker:biocontainers/bwa:latest'];
    }
    if (lower.contains('bam') || lower.contains('sam')) {
      return ['Samtools', 'docker:biocontainers/samtools:latest'];
    }
    if (lower.contains('rna') || lower.contains('star')) {
      return ['STAR', 'docker:biocontainers/star:latest'];
    }

    return defaultSwapOptions;
  }

  static String hubSearchQuery(String nodeType) {
    final normalized = nodeType.trim();
    if (normalized.startsWith('docker:')) {
      final image = normalized.substring(7);
      return image.contains(':') ? image.split(':').first : image;
    }
    return normalized.replaceAll(RegExp(r'[_-]+'), ' ');
  }
}
