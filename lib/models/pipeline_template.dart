import 'package:flutter/material.dart';

// ─── Node / Connection stubs ─────────────────────────────────────────────────

/// Defines a single node to be created when a template is applied.
class TemplateNodeDef {
  final String nodeType;
  // "Input" | "Output" | "FastQC" | … | "docker:image/name:tag"
  final Offset position;
  final Map<String, dynamic> parameterOverrides;

  const TemplateNodeDef({
    required this.nodeType,
    required this.position,
    this.parameterOverrides = const {},
  });
}

/// A directed connection between two nodes referenced by their list index.
class TemplateConnectionDef {
  final int fromIndex;
  final int toIndex;
  const TemplateConnectionDef(this.fromIndex, this.toIndex);
}

// ─── Template model ──────────────────────────────────────────────────────────

class PipelineTemplate {
  final String id;
  final String name;
  final String description;
  final String category; // "Quick Start" | "Genomics" | "Transcriptomics" …
  final List<Color> gradientColors;
  final IconData icon;
  final String estimatedTime; // display string, e.g. "~5 min"
  final String difficulty; // "Beginner" | "Intermediate" | "Advanced"
  final List<String> tags;
  final List<String> requiredImages; // Docker images needed (no tag)
  final List<TemplateNodeDef> nodes;
  final List<TemplateConnectionDef> connections;

  const PipelineTemplate({
    required this.id,
    required this.name,
    required this.description,
    required this.category,
    required this.gradientColors,
    required this.icon,
    required this.estimatedTime,
    required this.difficulty,
    required this.tags,
    required this.requiredImages,
    required this.nodes,
    required this.connections,
  });
}

// ─── Built-in template catalog ───────────────────────────────────────────────

/// Node positions for templates are centered near (25000, 25000) — the
/// midpoint of the 50000×50000 virtual canvas — so _centerView() shows
/// them immediately and the auto-fit animation has minimal travel distance.

class AppTemplates {
  AppTemplates._();

  static const List<PipelineTemplate> all = [
    // ─── 1. Quality Check ────────────────────────────────────────────────────
    PipelineTemplate(
      id: 'qc_fastqc',
      name: 'Quality Check',
      description:
          'Run FastQC on raw sequencing reads to assess data quality and '
          'generate an interactive HTML report.',
      category: 'Quick Start',
      gradientColors: [Color(0xFF6366F1), Color(0xFF8B5CF6)],
      icon: Icons.verified_rounded,
      estimatedTime: '~3 min',
      difficulty: 'Beginner',
      tags: ['QC', 'FASTQ', 'FastQC'],
      requiredImages: ['staphb/fastqc'],
      nodes: [
        TemplateNodeDef(nodeType: 'Input', position: Offset(24500, 24900)),
        TemplateNodeDef(nodeType: 'FastQC', position: Offset(24795, 24900)),
        TemplateNodeDef(nodeType: 'Output', position: Offset(25090, 24900)),
      ],
      connections: [
        TemplateConnectionDef(0, 1),
        TemplateConnectionDef(1, 2),
      ],
    ),

    // ─── 2. Trim & QC ────────────────────────────────────────────────────────
    PipelineTemplate(
      id: 'trim_qc',
      name: 'Trim & QC',
      description:
          'Remove adapter sequences and low-quality bases with Trimmomatic, '
          'then verify quality with FastQC.',
      category: 'Preprocessing',
      gradientColors: [Color(0xFF3B82F6), Color(0xFF06B6D4)],
      icon: Icons.content_cut_rounded,
      estimatedTime: '~8 min',
      difficulty: 'Beginner',
      tags: ['QC', 'Trimming', 'Adapters'],
      requiredImages: ['staphb/trimmomatic', 'staphb/fastqc'],
      nodes: [
        TemplateNodeDef(nodeType: 'Input', position: Offset(24500, 24900)),
        TemplateNodeDef(
            nodeType: 'Trimmomatic', position: Offset(24795, 24900)),
        TemplateNodeDef(nodeType: 'FastQC', position: Offset(25090, 24900)),
        TemplateNodeDef(nodeType: 'Output', position: Offset(25385, 24900)),
      ],
      connections: [
        TemplateConnectionDef(0, 1),
        TemplateConnectionDef(1, 2),
        TemplateConnectionDef(2, 3),
      ],
    ),

    // ─── 3. DNA Alignment ────────────────────────────────────────────────────
    PipelineTemplate(
      id: 'dna_alignment',
      name: 'DNA Alignment',
      description:
          'Align DNA short reads against a reference genome with BWA-MEM, '
          'then sort and index BAM files with Samtools.',
      category: 'Genomics',
      gradientColors: [Color(0xFF10B981), Color(0xFF0EA5E9)],
      icon: Icons.compare_arrows_rounded,
      estimatedTime: '~20 min',
      difficulty: 'Intermediate',
      tags: ['DNA-seq', 'BWA', 'Samtools', 'Alignment'],
      requiredImages: ['staphb/bwa', 'staphb/samtools'],
      nodes: [
        TemplateNodeDef(nodeType: 'Input', position: Offset(24500, 24900)),
        TemplateNodeDef(nodeType: 'BWA', position: Offset(24795, 24900)),
        TemplateNodeDef(nodeType: 'Samtools', position: Offset(25090, 24900)),
        TemplateNodeDef(nodeType: 'Output', position: Offset(25385, 24900)),
      ],
      connections: [
        TemplateConnectionDef(0, 1),
        TemplateConnectionDef(1, 2),
        TemplateConnectionDef(2, 3),
      ],
    ),

    // ─── 4. RNA-seq Quantification ───────────────────────────────────────────
    PipelineTemplate(
      id: 'rnaseq_quant',
      name: 'RNA-seq Quantification',
      description:
          'Align RNA reads with STAR and quantify gene expression using '
          'featureCounts (Subread).',
      category: 'Transcriptomics',
      gradientColors: [Color(0xFFF59E0B), Color(0xFFEC4899)],
      icon: Icons.biotech_rounded,
      estimatedTime: '~25 min',
      difficulty: 'Intermediate',
      tags: ['RNA-seq', 'STAR', 'featureCounts'],
      requiredImages: ['staphb/star', 'staphb/subread'],
      nodes: [
        TemplateNodeDef(nodeType: 'Input', position: Offset(24500, 24900)),
        TemplateNodeDef(nodeType: 'STAR', position: Offset(24795, 24900)),
        TemplateNodeDef(
            nodeType: 'docker:staphb/subread:latest',
            position: Offset(25090, 24900)),
        TemplateNodeDef(nodeType: 'Output', position: Offset(25385, 24900)),
      ],
      connections: [
        TemplateConnectionDef(0, 1),
        TemplateConnectionDef(1, 2),
        TemplateConnectionDef(2, 3),
      ],
    ),

    // ─── 5. Variant Calling ──────────────────────────────────────────────────
    PipelineTemplate(
      id: 'variant_calling',
      name: 'Variant Calling',
      description:
          'End-to-end variant calling: BWA alignment → Samtools BAM '
          'processing → GATK HaplotypeCaller.',
      category: 'Genomics',
      gradientColors: [Color(0xFFEF4444), Color(0xFFF97316)],
      icon: Icons.hub_rounded,
      estimatedTime: '~45 min',
      difficulty: 'Advanced',
      tags: ['Variants', 'GATK', 'BWA', 'Samtools'],
      requiredImages: ['staphb/bwa', 'staphb/samtools', 'broadinstitute/gatk'],
      nodes: [
        TemplateNodeDef(nodeType: 'Input', position: Offset(24500, 24900)),
        TemplateNodeDef(nodeType: 'BWA', position: Offset(24795, 24900)),
        TemplateNodeDef(nodeType: 'Samtools', position: Offset(25090, 24900)),
        TemplateNodeDef(
            nodeType: 'docker:broadinstitute/gatk:latest',
            position: Offset(25385, 24900)),
        TemplateNodeDef(nodeType: 'Output', position: Offset(25680, 24900)),
      ],
      connections: [
        TemplateConnectionDef(0, 1),
        TemplateConnectionDef(1, 2),
        TemplateConnectionDef(2, 3),
        TemplateConnectionDef(3, 4),
      ],
    ),
  ];

  static List<String> get categories => [
        'All',
        ...{for (final t in all) t.category},
      ];
}
