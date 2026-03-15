import 'package:flutter/material.dart';
import 'package:get/get.dart';

import '../controllers/docker_search_controller.dart';
import '../models/docker_image.dart';

class ToolSidebar extends StatefulWidget {
  const ToolSidebar({Key? key}) : super(key: key);

  @override
  State<ToolSidebar> createState() => _ToolSidebarState();
}

class _ToolSidebarState extends State<ToolSidebar> {
  final DockerSearchController _searchController =
      Get.find<DockerSearchController>();
  final TextEditingController _searchTextController = TextEditingController();
  final FocusNode _searchFocusNode = FocusNode();

  // Bioinformatics tool library — fix #11
  final List<Map<String, dynamic>> tools = const [
    // ── Quality Control ────────────────────────────────────────────────────
    {
      'name': 'FastQC',
      'category': 'Quality Control',
      'description': 'Quality control for raw sequencing reads',
      'icon': Icons.bar_chart_rounded,
      'color': Color(0xFF10B981),
      'bgColor': Color(0xFFF0FDF4),
      'dockerId': 'docker:biocontainers/fastqc',
    },
    {
      'name': 'MultiQC',
      'category': 'Quality Control',
      'description': 'Aggregate QC results across samples',
      'icon': Icons.assessment_rounded,
      'color': Color(0xFF10B981),
      'bgColor': Color(0xFFF0FDF4),
      'dockerId': 'docker:ewels/multiqc',
    },
    {
      'name': 'Fastp',
      'category': 'Quality Control',
      'description': 'Fast FASTQ preprocessing & QC',
      'icon': Icons.speed_rounded,
      'color': Color(0xFF10B981),
      'bgColor': Color(0xFFF0FDF4),
      'dockerId': 'docker:biocontainers/fastp',
    },
    {
      'name': 'Trimmomatic',
      'category': 'Quality Control',
      'description': 'Trim adapters from Illumina reads',
      'icon': Icons.content_cut_rounded,
      'color': Color(0xFF10B981),
      'bgColor': Color(0xFFF0FDF4),
      'dockerId': 'docker:staphb/trimmomatic',
    },
    // ── Alignment ─────────────────────────────────────────────────────────
    {
      'name': 'BWA',
      'category': 'Alignment',
      'description': 'Burrows-Wheeler DNA aligner',
      'icon': Icons.align_horizontal_left_rounded,
      'color': Color(0xFF6366F1),
      'bgColor': Color(0xFFF0F9FF),
      'dockerId': 'docker:biocontainers/bwa',
    },
    {
      'name': 'HISAT2',
      'category': 'Alignment',
      'description': 'Graph-based alignment of RNA-seq reads',
      'icon': Icons.account_tree_rounded,
      'color': Color(0xFF6366F1),
      'bgColor': Color(0xFFF0F9FF),
      'dockerId': 'docker:staphb/hisat2',
    },
    {
      'name': 'STAR',
      'category': 'Alignment',
      'description': 'RNA-seq alignment, splice-aware',
      'icon': Icons.star_rounded,
      'color': Color(0xFF6366F1),
      'bgColor': Color(0xFFF0F9FF),
      'dockerId': 'docker:mgibio/star',
    },
    {
      'name': 'Bowtie2',
      'category': 'Alignment',
      'description': 'Short read aligner for DNA/RNA',
      'icon': Icons.swap_horiz_rounded,
      'color': Color(0xFF6366F1),
      'bgColor': Color(0xFFF0F9FF),
      'dockerId': 'docker:biocontainers/bowtie2',
    },
    // ── SAM/BAM Tools ─────────────────────────────────────────────────────
    {
      'name': 'Samtools',
      'category': 'SAM/BAM',
      'description': 'Sort, index, filter BAM/SAM files',
      'icon': Icons.table_rows_rounded,
      'color': Color(0xFFF59E0B),
      'bgColor': Color(0xFFFFFBEB),
      'dockerId': 'docker:staphb/samtools',
    },
    {
      'name': 'Picard',
      'category': 'SAM/BAM',
      'description': 'Mark duplicates, collect metrics',
      'icon': Icons.filter_alt_rounded,
      'color': Color(0xFFF59E0B),
      'bgColor': Color(0xFFFFFBEB),
      'dockerId': 'docker:broadinstitute/picard',
    },
    // ── Variant Calling ───────────────────────────────────────────────────
    {
      'name': 'GATK',
      'category': 'Variant Calling',
      'description': 'HaplotypeCaller, BaseRecalibrator',
      'icon': Icons.biotech_rounded,
      'color': Color(0xFFEF4444),
      'bgColor': Color(0xFFFEF2F2),
      'dockerId': 'docker:broadinstitute/gatk',
    },
    {
      'name': 'FreeBayes',
      'category': 'Variant Calling',
      'description': 'Bayesian genetic variant detector',
      'icon': Icons.scatter_plot_rounded,
      'color': Color(0xFFEF4444),
      'bgColor': Color(0xFFFEF2F2),
      'dockerId': 'docker:biocontainers/freebayes',
    },
    {
      'name': 'bcftools',
      'category': 'Variant Calling',
      'description': 'VCF/BCF variant manipulation',
      'icon': Icons.data_array_rounded,
      'color': Color(0xFFEF4444),
      'bgColor': Color(0xFFFEF2F2),
      'dockerId': 'docker:biocontainers/bcftools',
    },
    // ── RNA-Seq ───────────────────────────────────────────────────────────
    {
      'name': 'featureCounts',
      'category': 'RNA-Seq',
      'description': 'Count reads over genomic features',
      'icon': Icons.calculate_rounded,
      'color': Color(0xFF8B5CF6),
      'bgColor': Color(0xFFF5F3FF),
      'dockerId': 'docker:biocontainers/subread',
    },
    {
      'name': 'DESeq2',
      'category': 'RNA-Seq',
      'description': 'Differential expression with R/Bioconductor',
      'icon': Icons.trending_up_rounded,
      'color': Color(0xFF8B5CF6),
      'bgColor': Color(0xFFF5F3FF),
      'dockerId': 'docker:bioconductor/bioconductor_docker',
    },
    {
      'name': 'Salmon',
      'category': 'RNA-Seq',
      'description': 'Fast transcript quantification',
      'icon': Icons.flash_on_rounded,
      'color': Color(0xFF8B5CF6),
      'bgColor': Color(0xFFF5F3FF),
      'dockerId': 'docker:combinelab/salmon',
    },
    // ── I/O Utilities ─────────────────────────────────────────────────────
    {
      'name': 'Input',
      'category': 'IO',
      'description': 'Input data source',
      'icon': Icons.input_rounded,
      'color': Color(0xFF3B82F6),
      'bgColor': Color(0xFFEFF6FF),
      'dockerId': null,
    },
    {
      'name': 'Output',
      'category': 'IO',
      'description': 'Output data destination',
      'icon': Icons.output_rounded,
      'color': Color(0xFF3B82F6),
      'bgColor': Color(0xFFEFF6FF),
      'dockerId': null,
    },
  ];

  @override
  void initState() {
    super.initState();
    _searchTextController.addListener(_onSearchChanged);
  }

  @override
  void dispose() {
    _searchTextController.dispose();
    _searchFocusNode.dispose();
    super.dispose();
  }

  void _onSearchChanged() {
    final query = _searchTextController.text.trim();
    if (query.isNotEmpty) {
      _searchController.searchDockerImages(query);
    } else {
      _searchController.clearSearch();
    }
  }

  void _clearSearch() {
    _searchTextController.clear();
    _searchFocusNode.unfocus();
    _searchController.clearSearch();
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 320,
      decoration: const BoxDecoration(
        color: Colors.white,
        border: Border(
          right: BorderSide(color: Color(0xFFE2E8F0)),
        ),
        boxShadow: [
          BoxShadow(
            color: Color(0x08000000),
            blurRadius: 12,
            offset: Offset(4, 0),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Header
          Container(
            padding: const EdgeInsets.all(24),
            decoration: const BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
                colors: [
                  Color(0xFFF8FAFC),
                  Color(0xFFE2E8F0),
                ],
              ),
              border: Border(
                bottom: BorderSide(color: Color(0xFFE2E8F0)),
              ),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.all(8),
                      decoration: BoxDecoration(
                        gradient: const LinearGradient(
                          colors: [Color(0xFF6366F1), Color(0xFF8B5CF6)],
                        ),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: const Icon(
                        Icons.biotech,
                        color: Colors.white,
                        size: 20,
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: const Text(
                        'Search Docker Images',
                        style: TextStyle(
                          fontSize: 17,
                          fontWeight: FontWeight.w700,
                          color: Color(0xFF0F172A),
                        ),
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 8),
                Text(
                  'Search Docker images or drag built-in tools to build your pipeline',
                  style: TextStyle(
                    fontSize: 14,
                    color: Colors.grey[600],
                    height: 1.4,
                  ),
                ),
              ],
            ),
          ),
          // Search bar
          Container(
            padding: const EdgeInsets.all(16),
            decoration: const BoxDecoration(
              border: Border(
                bottom: BorderSide(color: Color(0xFFE2E8F0)),
              ),
            ),
            child: Row(
              children: [
                Expanded(
                  child: Container(
                    decoration: BoxDecoration(
                      color: const Color(0xFFF8FAFC),
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(color: const Color(0xFFE2E8F0)),
                    ),
                    child: TextField(
                      controller: _searchTextController,
                      focusNode: _searchFocusNode,
                      decoration: InputDecoration(
                        hintText: 'Search Docker images...',
                        hintStyle: const TextStyle(color: Color(0xFF94A3B8)),
                        border: InputBorder.none,
                        contentPadding: const EdgeInsets.symmetric(
                          horizontal: 16,
                          vertical: 12,
                        ),
                        prefixIcon: const Icon(
                          Icons.search,
                          size: 20,
                          color: Color(0xFF94A3B8),
                        ),
                        suffixIcon: _searchTextController.text.isNotEmpty
                            ? IconButton(
                                icon: const Icon(
                                  Icons.clear,
                                  size: 16,
                                  color: Color(0xFF94A3B8),
                                ),
                                onPressed: _clearSearch,
                              )
                            : null,
                      ),
                      style: const TextStyle(
                        fontSize: 14,
                        color: Color(0xFF0F172A),
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
          // Content area
          Expanded(
            child: Obx(() {
              if (_searchController.isLoading.value) {
                return const Center(
                  child: CircularProgressIndicator(
                    strokeWidth: 2,
                    valueColor: AlwaysStoppedAnimation(Color(0xFF6366F1)),
                  ),
                );
              }

              if (_searchController.errorMessage.value.isNotEmpty) {
                return Center(
                  child: Padding(
                    padding: const EdgeInsets.all(16),
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        const Icon(
                          Icons.wifi_off,
                          size: 48,
                          color: Color(0xFFEF4444),
                        ),
                        const SizedBox(height: 16),
                        Text(
                          _searchController.errorMessage.value,
                          style: const TextStyle(
                            color: Color(0xFFEF4444),
                            fontSize: 14,
                          ),
                          textAlign: TextAlign.center,
                        ),
                        const SizedBox(height: 8),
                        if (_searchController.errorMessage.value
                            .contains('Network error'))
                          const Text(
                            'Please ensure the app has internet permissions\nand try restarting the app',
                            style: TextStyle(
                              color: Color(0xFF64748B),
                              fontSize: 12,
                            ),
                            textAlign: TextAlign.center,
                          ),
                      ],
                    ),
                  ),
                );
              }

              if (_searchController.searchQuery.value.isNotEmpty) {
                return _buildDockerSearchResults();
              }

              return _buildBuiltInTools();
            }),
          ),
        ],
      ),
    );
  }

  Widget _buildBuiltInTools() {
    // Group tools by category
    final Map<String, List<Map<String, dynamic>>> grouped = {};
    for (final tool in tools) {
      final cat = tool['category'] as String;
      grouped.putIfAbsent(cat, () => []).add(tool);
    }

    final items = <Widget>[];
    grouped.forEach((category, catTools) {
      // Category header
      items.add(Padding(
        padding: const EdgeInsets.fromLTRB(4, 16, 4, 8),
        child: Text(
          category.toUpperCase(),
          style: const TextStyle(
            fontSize: 10,
            fontWeight: FontWeight.w700,
            color: Color(0xFF94A3B8),
            letterSpacing: 1.2,
          ),
        ),
      ));
      for (final tool in catTools) {
        // Use dockerId as drag data for Docker-based tools, tool name for builtins
        final dragData = (tool['dockerId'] as String?) ?? (tool['name'] as String);
        items.add(Container(
          margin: const EdgeInsets.only(bottom: 8),
          child: Draggable<String>(
            data: dragData,
            feedback: Material(
              elevation: 12,
              borderRadius: BorderRadius.circular(16),
              child: _buildToolCard(tool, isDragging: true),
            ),
            childWhenDragging: _buildToolCard(tool, isGhost: true),
            child: _buildToolCard(tool),
          ),
        ));
      }
    });

    return ListView(
      padding: const EdgeInsets.fromLTRB(16, 8, 16, 16),
      children: items,
    );
  }

  Widget _buildDockerSearchResults() {
    final results = _searchController.searchResults;

    if (results.isEmpty) {
      return const Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              Icons.search_off,
              size: 48,
              color: Color(0xFFCBD5E1),
            ),
            SizedBox(height: 12),
            Text(
              'No Docker images found',
              style: TextStyle(
                color: Color(0xFF64748B),
                fontSize: 14,
                fontWeight: FontWeight.w500,
              ),
            ),
            Text(
              'Try a different search term',
              style: TextStyle(
                color: Color(0xFF94A3B8),
                fontSize: 12,
              ),
            ),
          ],
        ),
      );
    }

    return ListView.builder(
      padding: const EdgeInsets.all(16),
      itemCount: results.length,
      itemBuilder: (context, index) {
        final image = results[index];
        return Container(
          margin: const EdgeInsets.only(bottom: 12),
          child: Draggable<String>(
            data: 'docker:${image.displayName}',
            feedback: Material(
              elevation: 12,
              borderRadius: BorderRadius.circular(16),
              child: _buildDockerImageCard(image, isDragging: true),
            ),
            childWhenDragging: _buildDockerImageCard(image, isGhost: true),
            child: _buildDockerImageCard(image),
          ),
        );
      },
    );
  }

  Widget _buildToolCard(Map<String, dynamic> tool,
      {bool isDragging = false, bool isGhost = false}) {
    final primaryColor = tool['color'] as Color;
    final backgroundColor = tool['bgColor'] as Color;

    return Container(
      width: 180,
      height: 60,
      decoration: BoxDecoration(
        color: isGhost ? Colors.white.withOpacity(0.5) : Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color:
              isGhost ? const Color(0xFFE2E8F0) : primaryColor.withOpacity(0.2),
          width: 1,
        ),
        boxShadow: isDragging
            ? [
                BoxShadow(
                  color: Colors.black.withOpacity(0.15),
                  blurRadius: 20,
                  offset: const Offset(0, 8),
                ),
              ]
            : [
                BoxShadow(
                  color: Colors.black.withOpacity(0.04),
                  blurRadius: 8,
                  offset: const Offset(0, 2),
                ),
              ],
      ),
      child: Row(
        children: [
          Container(
            width: 36,
            height: 36,
            margin: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: isGhost ? const Color(0xFFE2E8F0) : backgroundColor,
              borderRadius: BorderRadius.circular(8),
            ),
            child: Icon(
              tool['icon'] as IconData,
              color: isGhost ? const Color(0xFF94A3B8) : primaryColor,
              size: 20,
            ),
          ),
          Expanded(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  tool['name'] as String,
                  style: TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w600,
                    color: isGhost
                        ? const Color(0xFF94A3B8)
                        : const Color(0xFF0F172A),
                  ),
                  overflow: TextOverflow.ellipsis,
                ),
                Text(
                  tool['category'] as String,
                  style: TextStyle(
                    fontSize: 12,
                    color: isGhost
                        ? const Color(0xFFCBD5E1)
                        : const Color(0xFF64748B),
                  ),
                  overflow: TextOverflow.ellipsis,
                ),
              ],
            ),
          ),
          // Drag indicator
          if (!isGhost)
            Padding(
              padding: const EdgeInsets.all(8.0),
              child: Container(
                padding: const EdgeInsets.all(4),
                decoration: BoxDecoration(
                  color: (tool['color'] as Color).withOpacity(0.1),
                  borderRadius: BorderRadius.circular(6),
                ),
                child: Icon(
                  Icons.drag_indicator,
                  color: (tool['color'] as Color),
                  size: 16,
                ),
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildDockerImageCard(DockerImage image,
      {bool isDragging = false, bool isGhost = false}) {
    final color =
        image.isOfficial ? const Color(0xFF10B981) : const Color(0xFF6366F1);
    final bgColor =
        image.isOfficial ? const Color(0xFFF0FDF4) : const Color(0xFFF0F9FF);

    return Container(
      width: isDragging ? 280 : double.infinity,
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: isGhost ? const Color(0xFFF1F5F9) : Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: isGhost ? const Color(0xFFE2E8F0) : color.withOpacity(0.2),
          width: 1,
        ),
        boxShadow: isDragging
            ? [
                BoxShadow(
                  color: Colors.black.withOpacity(0.15),
                  blurRadius: 20,
                  offset: const Offset(0, 8),
                ),
              ]
            : [
                BoxShadow(
                  color: Colors.black.withOpacity(0.04),
                  blurRadius: 8,
                  offset: const Offset(0, 2),
                ),
              ],
      ),
      child: Row(
        children: [
          // Docker icon container
          Container(
            width: 48,
            height: 48,
            decoration: BoxDecoration(
              color: isGhost ? const Color(0xFFE2E8F0) : bgColor,
              borderRadius: BorderRadius.circular(12),
              border: Border.all(
                color:
                    isGhost ? const Color(0xFFCBD5E1) : color.withOpacity(0.2),
              ),
            ),
            child: Icon(
              Icons.storage,
              color: isGhost ? const Color(0xFF94A3B8) : color,
              size: 24,
            ),
          ),
          const SizedBox(width: 16),
          // Content
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Expanded(
                      child: Text(
                        image.displayName,
                        style: TextStyle(
                          fontWeight: FontWeight.w700,
                          fontSize: 16,
                          color: isGhost
                              ? const Color(0xFF94A3B8)
                              : const Color(0xFF0F172A),
                        ),
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                    if (image.isOfficial) ...[
                      const SizedBox(width: 8),
                      Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 6, vertical: 2),
                        decoration: BoxDecoration(
                          color: const Color(0xFF10B981).withOpacity(0.1),
                          borderRadius: BorderRadius.circular(4),
                        ),
                        child: const Text(
                          'OFFICIAL',
                          style: TextStyle(
                            fontSize: 10,
                            fontWeight: FontWeight.w700,
                            color: Color(0xFF10B981),
                          ),
                        ),
                      ),
                    ],
                  ],
                ),
                const SizedBox(height: 4),
                Text(
                  image.shortDescription,
                  style: TextStyle(
                    fontSize: 13,
                    color: isGhost
                        ? const Color(0xFFCBD5E1)
                        : const Color(0xFF64748B),
                    height: 1.3,
                  ),
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                ),
                const SizedBox(height: 4),
                Row(
                  children: [
                    Expanded(
                      child: _buildStatItem(
                        Icons.star,
                        image.starCount.toString(),
                        isGhost: isGhost,
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: _buildStatItem(
                        Icons.download,
                        image.formattedPullCount,
                        isGhost: isGhost,
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
          // Drag indicator
          if (!isGhost)
            Container(
              padding: const EdgeInsets.all(4),
              decoration: BoxDecoration(
                color: color.withOpacity(0.1),
                borderRadius: BorderRadius.circular(6),
              ),
              child: Icon(
                Icons.drag_indicator,
                color: color,
                size: 16,
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildStatItem(IconData icon, String value, {bool isGhost = false}) {
    return Row(
      children: [
        Icon(
          icon,
          size: 12,
          color: isGhost ? const Color(0xFFCBD5E1) : const Color(0xFF64748B),
        ),
        const SizedBox(width: 4),
        Text(
          value,
          style: TextStyle(
            fontSize: 11,
            color: isGhost ? const Color(0xFFCBD5E1) : const Color(0xFF64748B),
          ),
        ),
      ],
    );
  }
}
