import 'package:flutter/material.dart';
import 'package:get/get.dart';

import '../../controllers/ai_controller.dart';
import '../../controllers/ai_draft_controller.dart';
import '../../models/ai_draft_session.dart';
import 'ai_ghost_unknown_chips.dart';

class AiGenerateCard extends StatefulWidget {
  const AiGenerateCard({super.key});

  @override
  State<AiGenerateCard> createState() => _AiGenerateCardState();
}

class _AiGenerateCardState extends State<AiGenerateCard> {
  final _controller = TextEditingController();
  bool _submitting = false;

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (!Get.isRegistered<AiController>()) return const SizedBox.shrink();
    final ai = Get.find<AiController>();

    return Obx(() {
      final enabled = ai.connectivity.value.enabled;
      final verified = ai.connectivity.value.connectionVerified;
      final canGenerate = enabled && verified;

      return Container(
        margin: const EdgeInsets.only(bottom: 32),
        padding: const EdgeInsets.all(20),
        decoration: BoxDecoration(
          gradient: const LinearGradient(
            colors: [Color(0xFFEEF2FF), Color(0xFFF8FAFC)],
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
          ),
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: const Color(0xFFC7D2FE)),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Row(
              children: [
                Icon(Icons.auto_awesome, color: Color(0xFF6366F1), size: 18),
                SizedBox(width: 8),
                Text(
                  'AI Assistant',
                  style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w800,
                    color: Color(0xFF312E81),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 6),
            Text(
              !enabled
                  ? 'Enable AI Assistant in Settings to generate pipelines from a description.'
                  : !verified
                      ? 'Run Test Connection in Settings before generating.'
                      : 'Describe your analysis goal — Ricochet will draft a pipeline you can review before accepting.',
              style: const TextStyle(fontSize: 12.5, color: Color(0xFF475569), height: 1.45),
            ),
            const SizedBox(height: 14),
            TextField(
              controller: _controller,
              enabled: canGenerate && !_submitting,
              maxLines: 3,
              minLines: 2,
              onChanged: (_) => setState(() {}),
              decoration: InputDecoration(
                hintText: 'e.g. QC raw FASTQ reads, align to reference, export BAM',
                filled: true,
                fillColor: Colors.white,
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(10),
                  borderSide: const BorderSide(color: Color(0xFFE2E8F0)),
                ),
                enabledBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(10),
                  borderSide: const BorderSide(color: Color(0xFFE2E8F0)),
                ),
              ),
            ),
            const SizedBox(height: 12),
            Align(
              alignment: Alignment.centerRight,
              child: FilledButton.icon(
                onPressed: canGenerate && !_submitting && _controller.text.trim().isNotEmpty
                    ? _onGenerate
                    : null,
                icon: _submitting
                    ? const SizedBox(
                        width: 14,
                        height: 14,
                        child: CircularProgressIndicator(
                          strokeWidth: 2,
                          color: Colors.white,
                        ),
                      )
                    : const Icon(Icons.auto_awesome, size: 16),
                label: Text(_submitting ? 'Opening editor…' : 'Generate pipeline'),
                style: FilledButton.styleFrom(
                  backgroundColor: const Color(0xFF6366F1),
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                ),
              ),
            ),
          ],
        ),
      );
    });
  }

  Future<void> _onGenerate() async {
    final text = _controller.text.trim();
    if (text.isEmpty) return;
    setState(() => _submitting = true);
    try {
      await Get.find<AiDraftController>().openGenerateFromHome(text);
    } finally {
      if (mounted) setState(() => _submitting = false);
    }
  }
}

class AiPreviewPanel extends StatelessWidget {
  static const double width = 380;
  /// Matches the editor status bar height in [main.dart].
  static const double statusBarInset = 28;

  const AiPreviewPanel({super.key});

  @override
  Widget build(BuildContext context) {
    if (!Get.isRegistered<AiDraftController>()) return const SizedBox.shrink();
    final draft = Get.find<AiDraftController>();

    return Padding(
      padding: const EdgeInsets.only(bottom: statusBarInset),
      child: Container(
        width: width,
        decoration: const BoxDecoration(
          color: Colors.white,
          border: Border(
            left: BorderSide(color: Color(0xFFE2E8F0)),
          ),
          boxShadow: [
            BoxShadow(
              color: Color(0x0A000000),
              blurRadius: 16,
              offset: Offset(-4, 0),
            ),
          ],
        ),
        child: _PanelBody(draft: draft),
      ),
    );
  }
}

class _PanelBody extends StatefulWidget {
  final AiDraftController draft;
  const _PanelBody({required this.draft});

  @override
  State<_PanelBody> createState() => _PanelBodyState();
}

class _PanelBodyState extends State<_PanelBody> {
  late final TextEditingController _descriptionCtrl;
  final _listController = ScrollController();

  AiDraftController get draft => widget.draft;

  @override
  void initState() {
    super.initState();
    _descriptionCtrl = TextEditingController(text: draft.description.value);
  }

  @override
  void dispose() {
    _descriptionCtrl.dispose();
    _listController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Obx(() {
      final phase = draft.phase.value;
      _syncDescriptionField();

      return Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          _buildHeader(context),
          Expanded(child: _buildBody(phase)),
          if (phase == AiDraftPhase.draftActive) _buildActions(),
        ],
      );
    });
  }

  void _syncDescriptionField() {
    if (_descriptionCtrl.text != draft.description.value &&
        !draft.stepByStepActive.value) {
      _descriptionCtrl.text = draft.description.value;
    }
  }

  Widget _buildHeader(BuildContext context) {
    return Container(
      padding: const EdgeInsets.fromLTRB(16, 12, 4, 12),
      decoration: const BoxDecoration(
        gradient: LinearGradient(
          colors: [Color(0xFFEEF2FF), Color(0xFFF8FAFC)],
          begin: Alignment.centerLeft,
          end: Alignment.centerRight,
        ),
        border: Border(bottom: BorderSide(color: Color(0xFFE2E8F0))),
      ),
      child: Row(
        children: [
          Container(
            width: 28,
            height: 28,
            decoration: BoxDecoration(
              color: const Color(0xFF6366F1).withOpacity(0.12),
              borderRadius: BorderRadius.circular(8),
            ),
            child: const Icon(
              Icons.auto_awesome,
              size: 16,
              color: Color(0xFF6366F1),
            ),
          ),
          const SizedBox(width: 10),
          const Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'AI Preview',
                  style: TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w800,
                    color: Color(0xFF0F172A),
                  ),
                ),
                Text(
                  'Review before accepting',
                  style: TextStyle(
                    fontSize: 11,
                    color: Color(0xFF64748B),
                  ),
                ),
              ],
            ),
          ),
          IconButton(
            tooltip: 'Close',
            onPressed: () => _requestClose(context),
            icon: const Icon(Icons.close_rounded, size: 18),
          ),
        ],
      ),
    );
  }

  Widget _buildBody(AiDraftPhase phase) {
    if (phase == AiDraftPhase.streaming || phase == AiDraftPhase.validating) {
      return Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
              decoration: BoxDecoration(
                color: const Color(0xFFF8FAFC),
                borderRadius: BorderRadius.circular(10),
                border: Border.all(color: const Color(0xFFE2E8F0)),
              ),
              child: Row(
                children: [
                  const SizedBox(
                    width: 16,
                    height: 16,
                    child: CircularProgressIndicator(
                      strokeWidth: 2,
                      color: Color(0xFF6366F1),
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Text(
                      draft.waitingLabel,
                      style: const TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.w600,
                        color: Color(0xFF475569),
                      ),
                    ),
                  ),
                  TextButton(
                    onPressed: draft.cancelGenerate,
                    child: const Text('Cancel'),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 12),
            if (draft.streamText.value.isNotEmpty)
              Expanded(
                child: Container(
                  width: double.infinity,
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: const Color(0xFFF8FAFC),
                    borderRadius: BorderRadius.circular(10),
                    border: Border.all(color: const Color(0xFFE2E8F0)),
                  ),
                  child: SingleChildScrollView(
                    child: Text(
                      draft.streamText.value,
                      style: const TextStyle(
                        fontFamily: 'monospace',
                        fontSize: 11,
                        height: 1.45,
                        color: Color(0xFF64748B),
                      ),
                    ),
                  ),
                ),
              )
            else
              Expanded(
                child: Center(
                  child: Text(
                    phase == AiDraftPhase.validating
                        ? 'Validating pipeline structure…'
                        : 'Drafting your pipeline…',
                    style: const TextStyle(
                      fontSize: 12.5,
                      color: Color(0xFF94A3B8),
                    ),
                  ),
                ),
              ),
          ],
        ),
      );
    }

    if (phase == AiDraftPhase.error) {
      return Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              draft.errorMessage.value,
              style: const TextStyle(color: Color(0xFFB91C1C), fontSize: 13),
            ),
            const SizedBox(height: 12),
            OutlinedButton(
              onPressed: () => draft.closePanel(force: true),
              child: const Text('Dismiss'),
            ),
          ],
        ),
      );
    }

    return Padding(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Description',
            style: TextStyle(fontSize: 12, fontWeight: FontWeight.w700, color: Color(0xFF475569)),
          ),
          const SizedBox(height: 6),
          TextField(
            controller: _descriptionCtrl,
            maxLines: 3,
            onChanged: (v) => draft.description.value = v,
            decoration: InputDecoration(
              filled: true,
              fillColor: const Color(0xFFF8FAFC),
              border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
            ),
          ),
          const SizedBox(height: 14),
          const Text(
            'Suggested nodes',
            style: TextStyle(fontSize: 12, fontWeight: FontWeight.w700, color: Color(0xFF475569)),
          ),
          const SizedBox(height: 8),
          Expanded(
            child: ListView.builder(
              controller: _listController,
              itemCount: draft.ghosts.where((g) => !g.isSummary).length,
              itemBuilder: (_, i) {
                final ghost = draft.ghosts.where((g) => !g.isSummary).elementAt(i);
                final focused = draft.focusedGhostIndex.value == ghost.index;
                return _GhostRowWithChips(
                  ghost: ghost,
                  focused: focused,
                  onTap: () => draft.focusGhost(ghost.index),
                );
              },
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildActions() {
    final regenerateEnabled = draft.canRegenerate;
    return Container(
      padding: const EdgeInsets.fromLTRB(12, 10, 12, 12),
      decoration: const BoxDecoration(
        color: Colors.white,
        border: Border(top: BorderSide(color: Color(0xFFE2E8F0))),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Row(
            children: [
              Expanded(
                child: FilledButton(
                  onPressed: draft.acceptAll,
                  style: FilledButton.styleFrom(
                    backgroundColor: const Color(0xFF059669),
                    padding: const EdgeInsets.symmetric(vertical: 12),
                  ),
                  child: const Text('Accept all'),
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: OutlinedButton(
                  onPressed: draft.stepByStepActive.value
                      ? draft.acceptFocusedOrNext
                      : draft.startStepByStep,
                  style: OutlinedButton.styleFrom(
                    padding: const EdgeInsets.symmetric(vertical: 12),
                  ),
                  child: Text(
                    draft.stepByStepActive.value ? 'Accept next' : 'Step-by-step',
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Row(
            children: [
              Expanded(
                child: Tooltip(
                  message: regenerateEnabled
                      ? 'Generate a different pipeline approach'
                      : 'Finish review or discard remaining suggestions first.',
                  child: OutlinedButton(
                    onPressed: regenerateEnabled ? () => draft.regenerate() : null,
                    style: OutlinedButton.styleFrom(
                      padding: const EdgeInsets.symmetric(vertical: 12),
                    ),
                    child: const Text('Regenerate'),
                  ),
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: TextButton(
                  onPressed: () => draft.discardRemaining(
                    hadPartialAccept: draft.acceptedCount.value > 0,
                  ),
                  style: TextButton.styleFrom(
                    padding: const EdgeInsets.symmetric(vertical: 12),
                  ),
                  child: const Text('Discard'),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Future<void> _requestClose(BuildContext context) async {
    if (!draft.needsExitConfirm()) {
      draft.closePanel(force: true);
      return;
    }
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Leave review?'),
        content: const Text(
          'Accepted nodes stay; remaining suggestions will be removed.',
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Cancel')),
          FilledButton(onPressed: () => Navigator.pop(ctx, true), child: const Text('Leave')),
        ],
      ),
    );
    if (ok == true) {
      draft.discardRemaining(hadPartialAccept: draft.acceptedCount.value > 0);
      draft.closePanel(force: true);
    }
  }
}

class _GhostRowWithChips extends StatelessWidget {
  final AiGhostNode ghost;
  final bool focused;
  final VoidCallback onTap;

  const _GhostRowWithChips({
    required this.ghost,
    required this.focused,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final draft = Get.find<AiDraftController>();

    return InkWell(
      onTap: onTap,
      child: Container(
        margin: const EdgeInsets.only(bottom: 8),
        padding: const EdgeInsets.all(10),
        decoration: BoxDecoration(
          color: focused ? const Color(0xFFEEF2FF) : const Color(0xFFF8FAFC),
          borderRadius: BorderRadius.circular(8),
          border: Border.all(
            color: focused ? const Color(0xFF6366F1) : const Color(0xFFE2E8F0),
          ),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(
                  ghost.isUnknownImage
                      ? Icons.warning_amber_rounded
                      : Icons.hub_outlined,
                  size: 16,
                  color: ghost.isUnknownImage
                      ? const Color(0xFFF59E0B)
                      : const Color(0xFF6366F1),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    ghost.displayTitle,
                    style: const TextStyle(
                      fontSize: 12.5,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
                if (ghost.status == AiGhostStatus.accepted)
                  const Icon(Icons.check_circle, size: 16, color: Color(0xFF059669)),
              ],
            ),
            if (ghost.status == AiGhostStatus.pending)
              AiGhostUnknownChips(ghost: ghost, draft: draft),
          ],
        ),
      ),
    );
  }
}
