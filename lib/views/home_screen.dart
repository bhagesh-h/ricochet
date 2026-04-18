import 'dart:io';
import 'package:flutter/material.dart';
import 'package:get/get.dart';
import '../controllers/home_controller.dart';
import '../models/pipeline_template.dart';
import '../services/docker_service.dart';
import 'widgets/ricochet_logo.dart';
import 'widgets/about_dialog.dart';

// ─────────────────────────────────────────────────────────────────────────────
// HomeScreen — root widget
// ─────────────────────────────────────────────────────────────────────────────

class HomeScreen extends StatelessWidget {
  const HomeScreen({Key? key}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF0F2F5),
      body: Column(
        children: [
          const _TopBar(),
          Expanded(
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: const [
                _LeftPanel(),
                Expanded(child: _RightPanel()),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Top bar
// ─────────────────────────────────────────────────────────────────────────────

class _TopBar extends StatelessWidget {
  const _TopBar();

  @override
  Widget build(BuildContext context) {
    return Container(
      height: 52,
      decoration: const BoxDecoration(
        color: Colors.white,
        border: Border(bottom: BorderSide(color: Color(0xFFE2E8F0))),
      ),
      padding: const EdgeInsets.symmetric(horizontal: 24),
      child: Row(
        children: [
          // Brand mark
          const RicochetLogo(height: 20),
          const Spacer(),
          // Keyboard shortcut hint
          _TopBarButton(
            icon: Icons.keyboard_rounded,
            tooltip: 'Keyboard shortcuts',
            onTap: _showShortcuts,
          ),
          const SizedBox(width: 4),
          _TopBarButton(
            icon: Icons.info_outline_rounded,
            tooltip: 'About Ricochet',
            onTap: () => Get.dialog(const ModernAboutDialog()),
          ),
        ],
      ),
    );
  }

  void _showShortcuts() {
    // Use ⌘ on macOS, Ctrl on Windows/Linux to match what the OS actually sends.
    final mod = Platform.isMacOS ? '⌘' : 'Ctrl';
    final shortcuts = [
      ('$mod + Z', 'Undo'),
      ('$mod + Shift + Z  /  $mod + Y', 'Redo'),
      ('Delete / Backspace', 'Remove selected node'),
      ('Scroll wheel', 'Zoom in / out'),
      ('Drag on canvas', 'Pan view'),
      ('Escape', 'Deselect all'),
    ];

    Get.dialog(
      Dialog(
        shape:
            RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        child: Container(
          width: 440,
          padding: const EdgeInsets.all(28),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text('Keyboard Shortcuts',
                  style: TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.w700,
                      color: Color(0xFF0F172A))),
              const SizedBox(height: 20),
              ...shortcuts.map(_shortcutRow),
              const SizedBox(height: 20),
              Align(
                alignment: Alignment.centerRight,
                child: TextButton(
                  onPressed: Get.back,
                  child: const Text('Close'),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _shortcutRow((String, String) s) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: Row(
        children: [
          Container(
            padding:
                const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
            decoration: BoxDecoration(
              color: const Color(0xFFF1F5F9),
              borderRadius: BorderRadius.circular(5),
              border: Border.all(color: const Color(0xFFE2E8F0)),
            ),
            child: Text(s.$1,
                style: const TextStyle(
                    fontSize: 11,
                    fontFamily: 'monospace',
                    color: Color(0xFF0F172A))),
          ),
          const SizedBox(width: 12),
          Text(s.$2,
              style: const TextStyle(
                  fontSize: 13, color: Color(0xFF475569))),
        ],
      ),
    );
  }
}

class _TopBarButton extends StatelessWidget {
  final IconData icon;
  final String tooltip;
  final VoidCallback onTap;

  const _TopBarButton(
      {required this.icon, required this.tooltip, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return Tooltip(
      message: tooltip,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(8),
        child: Container(
          width: 34,
          height: 34,
          decoration: BoxDecoration(borderRadius: BorderRadius.circular(8)),
          child: Icon(icon, size: 18, color: const Color(0xFF64748B)),
        ),
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Left panel — branding + recent pipelines
// ─────────────────────────────────────────────────────────────────────────────

class _LeftPanel extends StatefulWidget {
  const _LeftPanel();

  @override
  State<_LeftPanel> createState() => _LeftPanelState();
}

class _LeftPanelState extends State<_LeftPanel> {

  @override
  Widget build(BuildContext context) {
    final ctrl = Get.find<HomeController>();
    return Container(
      width: 272,
      decoration: const BoxDecoration(
        color: Colors.white,
        border: Border(right: BorderSide(color: Color(0xFFE2E8F0))),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Section header
          const Padding(
            padding: EdgeInsets.fromLTRB(20, 24, 20, 12),
            child: Text(
              'RECENT PIPELINES',
              style: TextStyle(
                fontSize: 10.5,
                fontWeight: FontWeight.w700,
                color: Color(0xFF94A3B8),
                letterSpacing: 0.9,
              ),
            ),
          ),
          // Recent list
          Expanded(
            child: Obx(() {
              if (ctrl.isLoadingRecent.value) {
                return const Center(
                  child: SizedBox(
                    width: 20,
                    height: 20,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  ),
                );
              }
              if (ctrl.recentPipelines.isEmpty) {
                return _EmptyRecent(ctrl: ctrl);
              }
              return ListView.builder(
                padding: const EdgeInsets.symmetric(vertical: 4),
                itemCount: ctrl.recentPipelines.length,
                itemBuilder: (_, i) => _RecentItem(
                  key: ValueKey(ctrl.recentPipelines[i]['folderPath'] ?? i),
                  item: ctrl.recentPipelines[i],
                  ctrl: ctrl,
                ),
              );
            }),
          ),
          // Footer
          Container(
            padding: const EdgeInsets.all(16),
            decoration: const BoxDecoration(
              border:
                  Border(top: BorderSide(color: Color(0xFFE2E8F0))),
            ),
            child: SizedBox(
              width: double.infinity,
              child: OutlinedButton.icon(
                onPressed: () =>
                    Get.find<HomeController>().openBlankPipeline(),
                icon: const Icon(Icons.add_rounded, size: 16),
                label: const Text('New Blank Pipeline'),
                style: OutlinedButton.styleFrom(
                  foregroundColor: const Color(0xFF6366F1),
                  side: const BorderSide(color: Color(0xFF6366F1)),
                  padding: const EdgeInsets.symmetric(vertical: 10),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _RecentItem extends StatefulWidget {
  final Map<String, String> item;
  final HomeController ctrl;

  const _RecentItem({
    super.key,
    required this.item,
    required this.ctrl,
  });

  @override
  State<_RecentItem> createState() => _RecentItemState();
}

class _RecentItemState extends State<_RecentItem> {
  bool _isHovered = false;

  @override
  Widget build(BuildContext context) {
    final item = widget.item;
    final ctrl = widget.ctrl;
    final name = item['name'] ?? 'Pipeline';
    final path = item['folderPath'] ?? '';
    final short = path.length > 35 ? '…${path.substring(path.length - 35)}' : path;

    return MouseRegion(
      onEnter: (_) => setState(() => _isHovered = true),
      onExit: (_) => setState(() => _isHovered = false),
      child: GestureDetector(
        onTap: () => ctrl.openRecentPipeline(item),
        child: Container(
          margin: const EdgeInsets.symmetric(horizontal: 10, vertical: 2),
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 9),
          decoration: BoxDecoration(
            color: _isHovered
                ? const Color(0xFFF1F5F9)
                : Colors.transparent,
            borderRadius: BorderRadius.circular(8),
          ),
          child: Row(
            children: [
              Container(
                width: 36,
                height: 36,
                decoration: BoxDecoration(
                  color: const Color(0xFFEFF6FF),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: const Icon(Icons.account_tree_rounded,
                    size: 18, color: Color(0xFF6366F1)),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      name,
                      style: const TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.w600,
                        color: Color(0xFF0F172A),
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                    const SizedBox(height: 2),
                    Text(
                      short,
                      style: const TextStyle(
                          fontSize: 10.5, color: Color(0xFF94A3B8)),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ],
                ),
              ),
              if (_isHovered)
                const Icon(Icons.chevron_right_rounded,
                    size: 16, color: Color(0xFF94A3B8)),
            ],
          ),
        ),
      ),
    );
  }
}

class _EmptyRecent extends StatelessWidget {
  final HomeController ctrl;
  const _EmptyRecent({required this.ctrl});

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 44,
              height: 44,
              decoration: BoxDecoration(
                color: const Color(0xFFF1F5F9),
                borderRadius: BorderRadius.circular(12),
              ),
              child: const Icon(Icons.history_rounded,
                  color: Color(0xFF94A3B8), size: 22),
            ),
            const SizedBox(height: 12),
            const Text(
              'No recent pipelines',
              style: TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.w600,
                  color: Color(0xFF475569)),
            ),
            const SizedBox(height: 4),
            const Text(
              'Your pipelines will appear here\nonce you create one.',
              textAlign: TextAlign.center,
              style: TextStyle(fontSize: 11.5, color: Color(0xFF94A3B8)),
            ),
          ],
        ),
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Right panel — blank card + category-filtered template grid
// ─────────────────────────────────────────────────────────────────────────────

class _RightPanel extends StatefulWidget {
  const _RightPanel();

  @override
  State<_RightPanel> createState() => _RightPanelState();
}

class _RightPanelState extends State<_RightPanel> {
  String _selectedCategory = 'All';

  List<PipelineTemplate> get _filtered => _selectedCategory == 'All'
      ? AppTemplates.all
      : AppTemplates.all
          .where((t) => t.category == _selectedCategory)
          .toList();

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      padding: const EdgeInsets.fromLTRB(40, 36, 40, 40),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // ── Heading ──────────────────────────────────────────────────────────
          const Text(
            'New Pipeline',
            style: TextStyle(
              fontSize: 26,
              fontWeight: FontWeight.w800,
              color: Color(0xFF0F172A),
              letterSpacing: -0.5,
            ),
          ),
          const SizedBox(height: 6),
          const Text(
            'Start blank or pick a curated template to get up and running fast.',
            style: TextStyle(fontSize: 13.5, color: Color(0xFF64748B)),
          ),
          const SizedBox(height: 32),

          // ── Blank pipeline card ────────────────────────────────────────────
          _BlankCard(onTap: Get.find<HomeController>().openBlankPipeline),
          const SizedBox(height: 40),

          // ── Templates heading + category chips ────────────────────────────
          Row(
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              const Text(
                'Templates',
                style: TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.w700,
                  color: Color(0xFF0F172A),
                ),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: SingleChildScrollView(
                  scrollDirection: Axis.horizontal,
                  child: Row(
                    children:
                        AppTemplates.categories.map((cat) {
                      final active = cat == _selectedCategory;
                      return Padding(
                        padding: const EdgeInsets.only(right: 8),
                        child: ChoiceChip(
                          label: Text(cat),
                          selected: active,
                          onSelected: (_) =>
                              setState(() => _selectedCategory = cat),
                          selectedColor: const Color(0xFF6366F1),
                          backgroundColor: Colors.white,
                          labelStyle: TextStyle(
                            fontSize: 12,
                            fontWeight: FontWeight.w500,
                            color: active
                                ? Colors.white
                                : const Color(0xFF475569),
                          ),
                          side: BorderSide(
                            color: active
                                ? const Color(0xFF6366F1)
                                : const Color(0xFFE2E8F0),
                          ),
                          padding: const EdgeInsets.symmetric(
                              horizontal: 12, vertical: 4),
                          visualDensity: VisualDensity.compact,
                        ),
                      );
                    }).toList(),
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 20),

          // ── Template cards grid ───────────────────────────────────────────
          Wrap(
            spacing: 16,
            runSpacing: 16,
            children: _filtered
                .map((t) => _TemplateCard(template: t))
                .toList(),
          ),
        ],
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Blank pipeline card
// ─────────────────────────────────────────────────────────────────────────────

class _BlankCard extends StatefulWidget {
  final Future<void> Function() onTap;
  const _BlankCard({required this.onTap});

  @override
  State<_BlankCard> createState() => _BlankCardState();
}

class _BlankCardState extends State<_BlankCard> {
  bool _hovering = false;

  @override
  Widget build(BuildContext context) {
    return MouseRegion(
      onEnter: (_) => setState(() => _hovering = true),
      onExit: (_) => setState(() => _hovering = false),
      cursor: SystemMouseCursors.click,
      child: GestureDetector(
        onTap: widget.onTap,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 175),
          width: 218,
          height: 150,
          clipBehavior: Clip.hardEdge,
          transform: _hovering
              ? (Matrix4.identity()..translate(0.0, -3.0))
              : Matrix4.identity(),
          decoration: BoxDecoration(
            gradient: const LinearGradient(
              colors: [Color(0xFF6366F1), Color(0xFF8B5CF6)],
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
            ),
            borderRadius: BorderRadius.circular(14),
            boxShadow: [
              BoxShadow(
                color: const Color(0xFF6366F1)
                    .withOpacity(_hovering ? 0.4 : 0.18),
                blurRadius: _hovering ? 20 : 10,
                offset: Offset(0, _hovering ? 8 : 3),
              ),
            ],
          ),
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                // Top row
                Row(
                  children: [
                    const Icon(Icons.add_rounded, color: Colors.white, size: 22),
                    const Spacer(),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                      decoration: BoxDecoration(
                        color: Colors.white.withOpacity(0.22),
                        borderRadius: BorderRadius.circular(20),
                      ),
                      child: const Text(
                        'Start Fresh',
                        style: TextStyle(
                            fontSize: 9.5,
                            color: Colors.white,
                            fontWeight: FontWeight.w600),
                      ),
                    ),
                  ],
                ),
                // Bottom group
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Text(
                      'Blank Pipeline',
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        fontSize: 14.5,
                        fontWeight: FontWeight.w700,
                        color: Colors.white,
                        letterSpacing: -0.2,
                      ),
                    ),
                    const SizedBox(height: 3),
                    Text(
                      'Any workload  ·  Custom tools',
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                          fontSize: 11,
                          color: Colors.white.withOpacity(0.75)),
                    ),
                    const SizedBox(height: 6),
                    SingleChildScrollView(
                      scrollDirection: Axis.horizontal,
                      child: Row(
                        children: [
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2),
                            decoration: BoxDecoration(
                              color: Colors.white.withOpacity(0.18),
                              borderRadius: BorderRadius.circular(4),
                            ),
                            child: const Text(
                              'drag-&-drop',
                              style: TextStyle(fontSize: 9.5, color: Colors.white),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Template card
// ─────────────────────────────────────────────────────────────────────────────

class _TemplateCard extends StatefulWidget {
  final PipelineTemplate template;
  const _TemplateCard({required this.template});

  @override
  State<_TemplateCard> createState() => _TemplateCardState();
}

class _TemplateCardState extends State<_TemplateCard> {
  bool _hovering = false;

  void _openPreview() {
    Get.dialog(
      _TemplatePreviewDialog(template: widget.template),
      barrierDismissible: false,
    );
  }

  @override
  Widget build(BuildContext context) {
    final t = widget.template;
    return MouseRegion(
      onEnter: (_) => setState(() => _hovering = true),
      onExit: (_) => setState(() => _hovering = false),
      cursor: SystemMouseCursors.click,
      child: GestureDetector(
        onTap: _openPreview,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 175),
          width: 218,
          height: 150,
          clipBehavior: Clip.hardEdge,
          transform: _hovering
              ? (Matrix4.identity()..translate(0.0, -3.0))
              : Matrix4.identity(),
          decoration: BoxDecoration(
            gradient:
                LinearGradient(colors: t.gradientColors, begin: Alignment.topLeft, end: Alignment.bottomRight),
            borderRadius: BorderRadius.circular(14),
            boxShadow: [
              BoxShadow(
                color: t.gradientColors.first
                    .withOpacity(_hovering ? 0.4 : 0.18),
                blurRadius: _hovering ? 20 : 10,
                offset: Offset(0, _hovering ? 8 : 3),
              ),
            ],
          ),
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                // Top row: icon + category
                Row(
                  children: [
                    Icon(t.icon, color: Colors.white, size: 22),
                    const Spacer(),
                    Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 8, vertical: 3),
                      decoration: BoxDecoration(
                        color: Colors.white.withOpacity(0.22),
                        borderRadius: BorderRadius.circular(20),
                      ),
                      child: Text(
                        t.category,
                        style: const TextStyle(
                            fontSize: 9.5,
                            color: Colors.white,
                            fontWeight: FontWeight.w600),
                      ),
                    ),
                  ],
                ),
                // Bottom group: name + meta + badges
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      t.name,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        fontSize: 14.5,
                        fontWeight: FontWeight.w700,
                        color: Colors.white,
                        letterSpacing: -0.2,
                      ),
                    ),
                    const SizedBox(height: 3),
                    Text(
                      '${t.difficulty}  ·  ${t.estimatedTime}',
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                          fontSize: 11,
                          color: Colors.white.withOpacity(0.75)),
                    ),
                    const SizedBox(height: 6),
                    // Tool badges
                    SingleChildScrollView(
                      scrollDirection: Axis.horizontal,
                      child: Row(
                        children: t.requiredImages.map((img) {
                          final short = img.split('/').last;
                          return Container(
                            margin: const EdgeInsets.only(right: 5),
                            padding: const EdgeInsets.symmetric(
                                horizontal: 7, vertical: 2),
                            decoration: BoxDecoration(
                              color: Colors.white.withOpacity(0.18),
                              borderRadius: BorderRadius.circular(4),
                            ),
                            child: Text(
                              short,
                              style: const TextStyle(
                                  fontSize: 9.5, color: Colors.white),
                            ),
                          );
                        }).toList(),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Template preview dialog — shows requirements + download + open actions
// ─────────────────────────────────────────────────────────────────────────────

class _TemplatePreviewDialog extends StatefulWidget {
  final PipelineTemplate template;
  const _TemplatePreviewDialog({required this.template});

  @override
  State<_TemplatePreviewDialog> createState() =>
      _TemplatePreviewDialogState();
}

class _TemplatePreviewDialogState extends State<_TemplatePreviewDialog> {
  // null = still checking; true = local; false = missing
  late final Map<String, bool?> _imageStatus;
  bool _isDownloading = false;
  final Map<String, double> _downloadProgress = {};
  String? _currentDownloading;
  String? _errorMessage;

  @override
  void initState() {
    super.initState();
    _imageStatus = {for (final i in widget.template.requiredImages) i: null};
    _checkImages();
  }

  Future<void> _checkImages() async {
    final svc = DockerService();
    for (final img in widget.template.requiredImages) {
      final exists = await svc.imageExists(img);
      if (!mounted) return;
      setState(() => _imageStatus[img] = exists);
    }
  }

  bool get _allLocal =>
      _imageStatus.values.isNotEmpty &&
      _imageStatus.values.every((v) => v == true);

  bool get _isChecking =>
      _imageStatus.values.any((v) => v == null);

  List<String> get _missingImages =>
      _imageStatus.entries
          .where((e) => e.value == false)
          .map((e) => e.key)
          .toList();

  Future<void> _openNow() async {
    Get.back();
    await Get.find<HomeController>().openTemplate(widget.template);
  }

  Future<void> _downloadAndOpen() async {
    setState(() {
      _isDownloading = true;
      _errorMessage = null;
    });
    try {
      final svc = DockerService();
      for (final img in _missingImages) {
        if (!mounted) return;
        setState(() {
          _currentDownloading = img;
          _downloadProgress[img] = 0.0;
        });
        await for (final progress in svc.pullImage(img)) {
          if (!mounted) return;
          setState(() => _downloadProgress[img] = progress.percentage);
        }
        if (!mounted) return;
        setState(() => _imageStatus[img] = true);
      }
      await _openNow();
    } catch (e) {
      if (mounted) {
        setState(() {
          _isDownloading = false;
          _errorMessage = 'Download failed: $e';
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final t = widget.template;
    return Dialog(
      backgroundColor: Colors.transparent,
      child: Container(
        width: 520,
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(20),
          boxShadow: const [
            BoxShadow(
                color: Color(0x28000000),
                blurRadius: 40,
                offset: Offset(0, 16)),
          ],
        ),
        clipBehavior: Clip.hardEdge,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // ── Gradient header ─────────────────────────────────────────────
            Container(
              height: 120,
              decoration: BoxDecoration(
                gradient: LinearGradient(
                    colors: t.gradientColors,
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight),
              ),
              padding: const EdgeInsets.fromLTRB(24, 20, 24, 20),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Icon(t.icon, color: Colors.white, size: 24),
                      const Spacer(),
                      Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 10, vertical: 4),
                        decoration: BoxDecoration(
                          color: Colors.white.withOpacity(0.22),
                          borderRadius: BorderRadius.circular(20),
                        ),
                        child: Row(
                          children: [
                            const Icon(Icons.schedule_rounded,
                                color: Colors.white70, size: 12),
                            const SizedBox(width: 4),
                            Text(t.estimatedTime,
                                style: const TextStyle(
                                    color: Colors.white70, fontSize: 11)),
                          ],
                        ),
                      ),
                    ],
                  ),
                  const Spacer(),
                  Text(
                    t.name,
                    style: const TextStyle(
                      fontSize: 20,
                      fontWeight: FontWeight.w800,
                      color: Colors.white,
                      letterSpacing: -0.4,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Row(
                    children: [
                      _difficultyDot(t.difficulty),
                      const SizedBox(width: 6),
                      Text(
                        t.difficulty,
                        style: const TextStyle(
                            color: Colors.white70, fontSize: 12),
                      ),
                      const SizedBox(width: 12),
                      ...t.tags.take(3).map((tag) => Container(
                            margin: const EdgeInsets.only(right: 4),
                            padding: const EdgeInsets.symmetric(
                                horizontal: 7, vertical: 2),
                            decoration: BoxDecoration(
                              color: Colors.white.withOpacity(0.18),
                              borderRadius: BorderRadius.circular(4),
                            ),
                            child: Text(tag,
                                style: const TextStyle(
                                    fontSize: 10,
                                    color: Colors.white)),
                          )),
                    ],
                  ),
                ],
              ),
            ),

            // ── Body ─────────────────────────────────────────────────────────
            Padding(
              padding: const EdgeInsets.fromLTRB(24, 20, 24, 0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Description
                  Text(
                    t.description,
                    style: const TextStyle(
                        fontSize: 13.5,
                        color: Color(0xFF475569),
                        height: 1.55),
                  ),
                  const SizedBox(height: 20),

                  // Pipeline preview
                  _buildPipelinePreview(),
                  const SizedBox(height: 20),

                  // Requirements
                  if (t.requiredImages.isNotEmpty) ...[
                    const Text(
                      'DOCKER IMAGES REQUIRED',
                      style: TextStyle(
                        fontSize: 10.5,
                        fontWeight: FontWeight.w700,
                        color: Color(0xFF94A3B8),
                        letterSpacing: 0.8,
                      ),
                    ),
                    const SizedBox(height: 10),
                    ...t.requiredImages.map(_buildImageRow),
                  ],

                  // Error banner
                  if (_errorMessage != null) ...[
                    const SizedBox(height: 12),
                    Container(
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: const Color(0xFFFEF2F2),
                        borderRadius: BorderRadius.circular(8),
                        border:
                            Border.all(color: const Color(0xFFFCA5A5)),
                      ),
                      child: Row(
                        children: [
                          const Icon(Icons.error_outline_rounded,
                              color: Color(0xFFEF4444), size: 16),
                          const SizedBox(width: 8),
                          Expanded(
                            child: Text(_errorMessage!,
                                style: const TextStyle(
                                    fontSize: 12,
                                    color: Color(0xFFB91C1C))),
                          ),
                        ],
                      ),
                    ),
                  ],
                ],
              ),
            ),

            // ── Actions ───────────────────────────────────────────────────────
            Padding(
              padding: const EdgeInsets.fromLTRB(24, 20, 24, 24),
              child: Row(
                children: [
                  TextButton(
                    onPressed:
                        _isDownloading ? null : () => Get.back(),
                    child: const Text('Cancel'),
                  ),
                  const Spacer(),
                  if (!_allLocal &&
                      !_isChecking &&
                      !_isDownloading) ...[
                    OutlinedButton(
                      onPressed: _openNow,
                      style: OutlinedButton.styleFrom(
                        foregroundColor: const Color(0xFF475569),
                        side: const BorderSide(
                            color: Color(0xFFCBD5E1)),
                        padding: const EdgeInsets.symmetric(
                            horizontal: 18, vertical: 12),
                      ),
                      child: const Text('Open Anyway'),
                    ),
                    const SizedBox(width: 12),
                  ],
                  _buildPrimaryButton(),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildPipelinePreview() {
    final nodeLabels = widget.template.nodes.map((def) {
      if (def.nodeType == 'Input') return 'Input';
      if (def.nodeType == 'Output') return 'Output';
      if (def.nodeType.startsWith('docker:')) {
        return def.nodeType
            .substring(7)
            .split(':')
            .first
            .split('/')
            .last;
      }
      return def.nodeType;
    }).toList();

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      decoration: BoxDecoration(
        color: const Color(0xFFF8FAFC),
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: const Color(0xFFE2E8F0)),
      ),
      child: SingleChildScrollView(
        scrollDirection: Axis.horizontal,
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            for (int i = 0; i < nodeLabels.length; i++) ...[
              Container(
                padding: const EdgeInsets.symmetric(
                    horizontal: 12, vertical: 6),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(7),
                  border: Border.all(color: const Color(0xFFE2E8F0)),
                  boxShadow: const [
                    BoxShadow(
                        color: Color(0x08000000),
                        blurRadius: 4,
                        offset: Offset(0, 1))
                  ],
                ),
                child: Text(nodeLabels[i],
                    style: const TextStyle(
                        fontSize: 11.5,
                        fontWeight: FontWeight.w600,
                        color: Color(0xFF334155))),
              ),
              if (i < nodeLabels.length - 1)
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 6),
                  child: Icon(Icons.arrow_forward_rounded,
                      size: 14,
                      color: const Color(0xFF94A3B8)),
                ),
            ],
          ],
        ),
      ),
    );
  }

  Widget _buildImageRow(String image) {
    final status = _imageStatus[image];
    final short = image.split('/').last;
    final isDownloading =
        _isDownloading && _currentDownloading == image;
    final progress = _downloadProgress[image] ?? 0.0;

    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Row(
        children: [
          Container(
            width: 32,
            height: 32,
            decoration: BoxDecoration(
              color: const Color(0xFFF1F5F9),
              borderRadius: BorderRadius.circular(7),
            ),
            child: const Icon(Icons.dns_rounded,
                size: 16, color: Color(0xFF64748B)),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  image,
                  style: const TextStyle(
                      fontSize: 12.5,
                      fontWeight: FontWeight.w500,
                      color: Color(0xFF1E293B),
                      fontFamily: 'monospace'),
                ),
                if (isDownloading) ...[
                  const SizedBox(height: 4),
                  ClipRRect(
                    borderRadius: BorderRadius.circular(3),
                    child: LinearProgressIndicator(
                      value: progress > 0 ? progress : null,
                      minHeight: 3,
                      backgroundColor: const Color(0xFFE2E8F0),
                      valueColor: AlwaysStoppedAnimation(
                          widget.template.gradientColors.first),
                    ),
                  ),
                ],
              ],
            ),
          ),
          const SizedBox(width: 10),
          _statusBadge(status, short, isDownloading),
        ],
      ),
    );
  }

  Widget _statusBadge(bool? status, String short, bool isDownloading) {
    if (isDownloading) {
      return const SizedBox(
        width: 16,
        height: 16,
        child: CircularProgressIndicator(strokeWidth: 2),
      );
    }
    if (status == null) {
      return const SizedBox(
        width: 14,
        height: 14,
        child: CircularProgressIndicator(
            strokeWidth: 2,
            valueColor: AlwaysStoppedAnimation(Color(0xFF94A3B8))),
      );
    }
    return Container(
      padding:
          const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(
        color: status
            ? const Color(0xFFECFDF5)
            : const Color(0xFFFFF7ED),
        borderRadius: BorderRadius.circular(6),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(
            status
                ? Icons.check_circle_rounded
                : Icons.cloud_download_rounded,
            size: 12,
            color: status
                ? const Color(0xFF059669)
                : const Color(0xFFF97316),
          ),
          const SizedBox(width: 4),
          Text(
            status ? 'Ready' : 'Not downloaded',
            style: TextStyle(
              fontSize: 10.5,
              fontWeight: FontWeight.w600,
              color: status
                  ? const Color(0xFF059669)
                  : const Color(0xFFF97316),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildPrimaryButton() {
    final label = _isDownloading
        ? 'Downloading…'
        : (_isChecking
            ? 'Checking…'
            : (_allLocal
                ? 'Create Pipeline'
                : 'Download & Create'));
    final enabled = !_isDownloading && !_isChecking;

    return ElevatedButton(
      onPressed: enabled
          ? (_allLocal ? _openNow : _downloadAndOpen)
          : null,
      style: ElevatedButton.styleFrom(
        backgroundColor: widget.template.gradientColors.first,
        foregroundColor: Colors.white,
        disabledBackgroundColor:
            widget.template.gradientColors.first.withOpacity(0.5),
        disabledForegroundColor: Colors.white60,
        padding:
            const EdgeInsets.symmetric(horizontal: 22, vertical: 12),
        shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(10)),
        elevation: 0,
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (_isDownloading || _isChecking) ...[
            const SizedBox(
              width: 14,
              height: 14,
              child: CircularProgressIndicator(
                  strokeWidth: 2,
                  valueColor:
                      AlwaysStoppedAnimation(Colors.white70)),
            ),
            const SizedBox(width: 8),
          ],
          Text(label,
              style: const TextStyle(
                  fontWeight: FontWeight.w600, fontSize: 13)),
        ],
      ),
    );
  }

  Widget _difficultyDot(String difficulty) {
    const colors = {
      'Beginner': Color(0xFF10B981),
      'Intermediate': Color(0xFFF59E0B),
      'Advanced': Color(0xFFEF4444),
    };
    final c = colors[difficulty] ?? Colors.white;
    return Container(
      width: 8,
      height: 8,
      decoration: BoxDecoration(color: c, shape: BoxShape.circle),
    );
  }
}
