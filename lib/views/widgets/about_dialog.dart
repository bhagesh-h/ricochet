import 'package:flutter/material.dart';
import 'package:get/get.dart';

class _AppFeature {
  final String title;
  final String description;
  final IconData icon;
  final List<Color> gradient;

  const _AppFeature({
    required this.title,
    required this.description,
    required this.icon,
    required this.gradient,
  });
}

const List<_AppFeature> _features = [
  _AppFeature(
    title: 'Visual Canvas',
    description: 'Infinite canvas with smooth pan and zoom, drag-and-drop nodes, Bezier curve connections, and real-time cycle detection. Build pipelines as intuitively as drawing on a whiteboard.',
    icon: Icons.account_tree_rounded,
    gradient: [Color(0xFF6366F1), Color(0xFF8B5CF6)],
  ),
  _AppFeature(
    title: 'Multi-Tab Editor',
    description: 'Work on multiple pipelines simultaneously with Chrome-style independent tabs. Enjoy automatic debounced saving, session restoration, and independent undo/redo histories for every tab.',
    icon: Icons.tab_rounded,
    gradient: [Color(0xFF3B82F6), Color(0xFF06B6D4)],
  ),
  _AppFeature(
    title: 'Built-in Tools',
    description: 'Drag pre-configured nodes from the sidebar for essential bioinformatics tasks including FastQC, Trimmomatic, BWA, STAR, and Samtools with intelligent default parameters.',
    icon: Icons.biotech_rounded,
    gradient: [Color(0xFF10B981), Color(0xFF059669)],
  ),
  _AppFeature(
    title: 'Docker Registry Hub',
    description: 'Live search the Docker Hub registry directly inside Ricochet. It features smart default tag resolution, layer-by-layer download progress, and in-memory LRU eviction caching.',
    icon: Icons.hub_rounded,
    gradient: [Color(0xFFF59E0B), Color(0xFFEA580C)],
  ),
  _AppFeature(
    title: 'Extensive Configuration',
    description: 'Each node exposes fully editable parameters including Docker Image, Tag, Command, Volume Mounts, Environment Variables, and Port Mappings allowing fine-tuned operational control.',
    icon: Icons.settings_rounded,
    gradient: [Color(0xFF64748B), Color(0xFF334155)],
  ),
  _AppFeature(
    title: 'Execution Engine',
    description: 'An advanced Kahn\'s algorithm Topological Sort determines data-flow and execution order, automatically translating node connections into container volume binds and environment variables.',
    icon: Icons.play_circle_fill_rounded,
    gradient: [Color(0xFFEC4899), Color(0xFFE11D48)],
  ),
  _AppFeature(
    title: 'Compose Export',
    description: 'Export your visual pipelines instantly into a production-ready docker-compose.yml bundle. This portable archive includes environment variable files and automatically generated documentation.',
    icon: Icons.file_download_rounded,
    gradient: [Color(0xFF8B5CF6), Color(0xFFD946EF)],
  ),
  _AppFeature(
    title: 'Workspace Management',
    description: 'Pipeline results are safely written to timestamped output run directories locally. Input and output bindings are inherently managed to prevent stale data conflicts.',
    icon: Icons.folder_special_rounded,
    gradient: [Color(0xFF14B8A6), Color(0xFF0F766E)],
  ),
];

class ModernAboutDialog extends StatefulWidget {
  const ModernAboutDialog({Key? key}) : super(key: key);

  @override
  State<ModernAboutDialog> createState() => _ModernAboutDialogState();
}

class _ModernAboutDialogState extends State<ModernAboutDialog> {
  _AppFeature? _selectedFeature;

  @override
  Widget build(BuildContext context) {
    return Dialog(
      backgroundColor: Colors.transparent,
      elevation: 0,
      child: Container(
        width: 850,
        height: 600,
        clipBehavior: Clip.antiAlias,
        decoration: BoxDecoration(
          color: const Color(0xFFF8FAFC),
          borderRadius: BorderRadius.circular(24),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.15),
              blurRadius: 40,
              offset: const Offset(0, 20),
            )
          ],
        ),
        child: Column(
          children: [
            // Fixed Modern Header
            _buildHeader(),
            // Dynamic Body
            Expanded(
              child: AnimatedSwitcher(
                duration: const Duration(milliseconds: 350),
                switchInCurve: Curves.easeOutCubic,
                switchOutCurve: Curves.easeInCubic,
                transitionBuilder: (child, animation) {
                  return FadeTransition(
                    opacity: animation,
                    child: SlideTransition(
                      position: Tween<Offset>(
                        begin: const Offset(0.02, 0.0),
                        end: Offset.zero,
                      ).animate(animation),
                      child: child,
                    ),
                  );
                },
                child: _selectedFeature == null
                    ? _buildGalleryView()
                    : _buildFeatureDetailView(_selectedFeature!),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildHeader() {
    return Container(
      height: 100,
      padding: const EdgeInsets.symmetric(horizontal: 32),
      decoration: const BoxDecoration(
        color: Colors.white,
        border: Border(bottom: BorderSide(color: Color(0xFFE2E8F0))),
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(
              gradient: const LinearGradient(
                colors: [Color(0xFF6366F1), Color(0xFF8B5CF6)],
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              ),
              borderRadius: BorderRadius.circular(12),
            ),
            child: const Icon(Icons.account_tree_rounded, color: Colors.white, size: 28),
          ),
          const SizedBox(width: 16),
          Column(
            mainAxisAlignment: MainAxisAlignment.center,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text(
                'Ricochet',
                style: TextStyle(
                  fontSize: 24,
                  fontWeight: FontWeight.w800,
                  color: Color(0xFF0F172A),
                  letterSpacing: -0.5,
                ),
              ),
              const SizedBox(height: 4),
              Row(
                children: [
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                    decoration: BoxDecoration(
                      color: const Color(0xFFEFF6FF),
                      borderRadius: BorderRadius.circular(6),
                    ),
                    child: const Text(
                      'v1.0.0',
                      style: TextStyle(
                        fontSize: 11,
                        color: Color(0xFF3B82F6),
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ),
                  const SizedBox(width: 10),
                  const Text(
                    'Visual Bioinformatics Data Pipelines',
                    style: TextStyle(
                      fontSize: 13,
                      color: Color(0xFF64748B),
                    ),
                  )
                ],
              )
            ],
          ),
          const Spacer(),
          // Close button
          IconButton(
            onPressed: () => Get.back(),
            icon: const Icon(Icons.close_rounded, color: Color(0xFF94A3B8)),
            hoverColor: const Color(0xFFF1F5F9),
            splashRadius: 24,
            tooltip: 'Close',
          ),
        ],
      ),
    );
  }

  Widget _buildGalleryView() {
    return Container(
      key: const ValueKey('galleryView'),
      padding: const EdgeInsets.all(32),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Explore Features',
            style: TextStyle(
              fontSize: 20,
              fontWeight: FontWeight.w700,
              color: Color(0xFF1E293B),
            ),
          ),
          const SizedBox(height: 6),
          const Text(
            'Select a card to view detailed information about the capabilities of Ricochet.',
            style: TextStyle(fontSize: 14, color: Color(0xFF64748B)),
          ),
          const SizedBox(height: 24),
          Expanded(
            child: GridView.builder(
              itemCount: _features.length,
              gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                crossAxisCount: 4,
                crossAxisSpacing: 16,
                mainAxisSpacing: 16,
                childAspectRatio: 1.1,
              ),
              itemBuilder: (context, index) {
                return _FeatureCard(
                  feature: _features[index],
                  onTap: () => setState(() => _selectedFeature = _features[index]),
                );
              },
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildFeatureDetailView(_AppFeature feature) {
    return Container(
      key: ValueKey('detailView_${feature.title}'),
      padding: const EdgeInsets.symmetric(horizontal: 48, vertical: 40),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Back button
          InkWell(
            onTap: () => setState(() => _selectedFeature = null),
            borderRadius: BorderRadius.circular(8),
            child: Padding(
              padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 4),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: const [
                  Icon(Icons.arrow_back_rounded, size: 18, color: Color(0xFF3B82F6)),
                  SizedBox(width: 8),
                  Text(
                    'Back to Gallery',
                    style: TextStyle(
                      color: Color(0xFF3B82F6),
                      fontSize: 14,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 32),
          // Large stylized icon
          Container(
            width: 80,
            height: 80,
            decoration: BoxDecoration(
              gradient: LinearGradient(
                colors: feature.gradient,
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              ),
              borderRadius: BorderRadius.circular(20),
              boxShadow: [
                BoxShadow(
                  color: feature.gradient.first.withOpacity(0.35),
                  blurRadius: 20,
                  offset: const Offset(0, 10),
                ),
              ],
            ),
            child: Icon(feature.icon, size: 40, color: Colors.white),
          ),
          const SizedBox(height: 32),
          Text(
            feature.title,
            style: const TextStyle(
              fontSize: 32,
              fontWeight: FontWeight.w800,
              color: Color(0xFF0F172A),
              letterSpacing: -0.5,
            ),
          ),
          const SizedBox(height: 20),
          Text(
            feature.description,
            style: const TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.w400,
              color: Color(0xFF475569),
              height: 1.6,
            ),
          ),
          const Spacer(),
          // Generic decorative element to make it look like "App Showcase"
          Container(
            height: 8,
            width: 60,
            decoration: BoxDecoration(
              gradient: LinearGradient(colors: feature.gradient),
              borderRadius: BorderRadius.circular(4),
            ),
          ),
        ],
      ),
    );
  }
}

class _FeatureCard extends StatefulWidget {
  final _AppFeature feature;
  final VoidCallback onTap;

  const _FeatureCard({required this.feature, required this.onTap});

  @override
  State<_FeatureCard> createState() => _FeatureCardState();
}

class _FeatureCardState extends State<_FeatureCard> {
  bool _isHovered = false;

  @override
  Widget build(BuildContext context) {
    return MouseRegion(
      onEnter: (_) => setState(() => _isHovered = true),
      onExit: (_) => setState(() => _isHovered = false),
      cursor: SystemMouseCursors.click,
      child: GestureDetector(
        onTap: widget.onTap,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 200),
          curve: Curves.fastOutSlowIn,
          padding: const EdgeInsets.all(20),
          transform: _isHovered ? (Matrix4.identity()..translate(0.0, -4.0)) : Matrix4.identity(),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(16),
            border: Border.all(
              color: _isHovered ? widget.feature.gradient.first.withOpacity(0.5) : const Color(0xFFE2E8F0),
              width: 1.5,
            ),
            boxShadow: [
              if (_isHovered)
                BoxShadow(
                  color: widget.feature.gradient.first.withOpacity(0.15),
                  blurRadius: 16,
                  offset: const Offset(0, 8),
                )
              else
                BoxShadow(
                  color: Colors.black.withOpacity(0.03),
                  blurRadius: 8,
                  offset: const Offset(0, 4),
                ),
            ],
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    colors: widget.feature.gradient,
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                  ),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Icon(widget.feature.icon, size: 24, color: Colors.white),
              ),
              const Spacer(),
              Text(
                widget.feature.title,
                style: const TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.w700,
                  color: Color(0xFF1E293B),
                ),
              ),
              const SizedBox(height: 6),
              const Text(
                'View details →',
                style: TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w600,
                  color: Color(0xFF94A3B8),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
