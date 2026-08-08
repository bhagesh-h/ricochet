import 'package:flutter/material.dart';
import 'package:get/get.dart';

import '../../controllers/ai_controller.dart';
import '../../models/ai_connectivity_settings.dart';
class AiAssistantSettingsSection extends StatefulWidget {
  const AiAssistantSettingsSection({super.key});

  @override
  State<AiAssistantSettingsSection> createState() =>
      _AiAssistantSettingsSectionState();
}

class _AiAssistantSettingsSectionState extends State<AiAssistantSettingsSection>
    with SingleTickerProviderStateMixin {
  bool _expanded = false;
  late final AnimationController _pulseCtrl;
  final _baseUrlCtrl = TextEditingController();
  final _modelCtrl = TextEditingController();
  final _apiKeyCtrl = TextEditingController();
  bool _showApiKey = false;
  bool _showAdvanced = false;

  @override
  void initState() {
    super.initState();
    _pulseCtrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1200),
    )..repeat(reverse: true);
    final ai = Get.find<AiController>();
    ai.notifySettingsOpened();
    _syncFields(ai);
    ever(ai.connectivity, (_) => _syncFields(ai));
    ever(ai.apiKey, (_) => _syncFields(ai));
  }

  void _syncFields(AiController ai) {
    final baseUrl = ai.connectivity.value.baseUrl;
    if (_baseUrlCtrl.text != baseUrl) {
      _baseUrlCtrl.text = baseUrl;
    }
    final model = ai.connectivity.value.model;
    if (_modelCtrl.text != model) {
      _modelCtrl.text = model;
    }
    final key = ai.apiKey.value;
    if (_apiKeyCtrl.text != key) {
      _apiKeyCtrl.text = key;
    }
  }

  @override
  void dispose() {
    _pulseCtrl.dispose();
    _baseUrlCtrl.dispose();
    _modelCtrl.dispose();
    _apiKeyCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final ai = Get.find<AiController>();

    return Obx(() {
      if (ai.isLoading.value) {
        return const Padding(
          padding: EdgeInsets.symmetric(vertical: 24),
          child: Center(
            child: SizedBox(
              width: 22,
              height: 22,
              child: CircularProgressIndicator(strokeWidth: 2),
            ),
          ),
        );
      }

      return Column(
        children: [
          _SummaryRow(
            expanded: _expanded,
            onTap: () => setState(() => _expanded = !_expanded),
            pillState: ai.pillState.value,
            enabled: ai.connectivity.value.enabled,
            pulse: _pulseCtrl,
          ),
          if (_expanded) ...[
            const SizedBox(height: 8),
            _EnabledTile(
              enabled: ai.connectivity.value.enabled,
              isSaving: ai.isSaving.value,
              onChanged: ai.setEnabled,
            ),
            if (ai.connectivity.value.enabled) ...[
              const SizedBox(height: 8),
              _buildForm(ai),
            ],
          ],
        ],
      );
    });
  }

  Widget _buildForm(AiController ai) {
    final conn = ai.connectivity.value;
    return Padding(
      padding: const EdgeInsets.fromLTRB(12, 0, 12, 12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _label('Provider preset'),
          const SizedBox(height: 6),
          DropdownButtonFormField<AiProviderPreset>(
            value: conn.providerPreset,
            decoration: _fieldDecoration(),
            items: const [
              DropdownMenuItem(
                value: AiProviderPreset.ollama,
                child: Text('Ollama (local)'),
              ),
              DropdownMenuItem(
                value: AiProviderPreset.lmStudio,
                child: Text('LM Studio (local)'),
              ),
              DropdownMenuItem(
                value: AiProviderPreset.openai,
                child: Text('OpenAI'),
              ),
              DropdownMenuItem(
                value: AiProviderPreset.openRouter,
                child: Text('OpenRouter'),
              ),
              DropdownMenuItem(
                value: AiProviderPreset.groq,
                child: Text('Groq'),
              ),
              DropdownMenuItem(
                value: AiProviderPreset.custom,
                child: Text('Custom'),
              ),
            ],
            onChanged: ai.isSaving.value ? null : (v) {
              if (v != null) ai.applyPreset(v);
            },
          ),
          const SizedBox(height: 14),
          _label('Base URL'),
          const SizedBox(height: 6),
          TextField(
            controller: _baseUrlCtrl,
            decoration: _fieldDecoration(
              hint: 'https://api.openai.com/v1',
            ),
            onChanged: ai.onBaseUrlChanged,
            onEditingComplete: ai.persistConnectivityAndKey,
          ),
          const SizedBox(height: 14),
          _label('API key'),
          const SizedBox(height: 6),
          TextField(
            controller: _apiKeyCtrl,
            obscureText: !_showApiKey,
            decoration: _fieldDecoration(hint: 'Optional for localhost').copyWith(
              suffixIcon: IconButton(
                icon: Icon(
                  _showApiKey ? Icons.visibility_off : Icons.visibility,
                  size: 18,
                ),
                onPressed: () => setState(() => _showApiKey = !_showApiKey),
              ),
            ),
            onChanged: (v) => ai.apiKey.value = v,
            onEditingComplete: ai.persistConnectivityAndKey,
          ),
          const SizedBox(height: 14),
          _label('Model'),
          const SizedBox(height: 6),
          TextField(
            controller: _modelCtrl,
            decoration: _fieldDecoration(hint: 'e.g. gpt-4o-mini'),
            onChanged: (v) {
              ai.connectivity.value =
                  ai.connectivity.value.copyWith(model: v, connectionVerified: false);
            },
            onEditingComplete: ai.persistConnectivityAndKey,
          ),
          const SizedBox(height: 12),
          InkWell(
            onTap: () => setState(() => _showAdvanced = !_showAdvanced),
            child: Row(
              children: [
                Icon(
                  _showAdvanced
                      ? Icons.expand_less
                      : Icons.expand_more,
                  size: 18,
                  color: const Color(0xFF64748B),
                ),
                const SizedBox(width: 4),
                const Text(
                  'Advanced',
                  style: TextStyle(
                    fontSize: 12.5,
                    fontWeight: FontWeight.w600,
                    color: Color(0xFF64748B),
                  ),
                ),
              ],
            ),
          ),
          if (_showAdvanced) ...[
            const SizedBox(height: 10),
            _label('Timeout (seconds)'),
            Slider(
              value: conn.timeoutSeconds.toDouble(),
              min: 15,
              max: 180,
              divisions: 11,
              label: '${conn.timeoutSeconds}s',
              onChanged: ai.isSaving.value
                  ? null
                  : (v) {
                      ai.connectivity.value = conn.copyWith(
                        timeoutSeconds: v.round(),
                      );
                    },
              onChangeEnd: (_) => ai.persistConnectivityAndKey(),
            ),
            SwitchListTile(
              contentPadding: EdgeInsets.zero,
              title: const Text(
                'Share anonymous usage',
                style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600),
              ),
              subtitle: const Text(
                'Help improve AI Assistant (no pipeline data)',
                style: TextStyle(fontSize: 11.5),
              ),
              value: conn.telemetryOptIn,
              activeColor: const Color(0xFF6366F1),
              onChanged: ai.isSaving.value
                  ? null
                  : (v) async {
                      await ai.saveConnectivity(
                        conn.copyWith(telemetryOptIn: v),
                      );
                    },
            ),
          ],
          const SizedBox(height: 16),
          _ConnectionTestPanel(ai: ai, pulse: _pulseCtrl),
        ],
      ),
    );
  }

  Widget _label(String text) => Text(
        text,
        style: const TextStyle(
          fontSize: 12.5,
          fontWeight: FontWeight.w700,
          color: Color(0xFF475569),
        ),
      );

  InputDecoration _fieldDecoration({String? hint}) => InputDecoration(
        hintText: hint,
        filled: true,
        fillColor: Colors.white,
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(8),
          borderSide: const BorderSide(color: Color(0xFFE2E8F0)),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(8),
          borderSide: const BorderSide(color: Color(0xFFE2E8F0)),
        ),
        contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      );
}

class _SummaryRow extends StatelessWidget {
  final bool expanded;
  final VoidCallback onTap;
  final AiPillState pillState;
  final bool enabled;
  final AnimationController pulse;

  const _SummaryRow({
    required this.expanded,
    required this.onTap,
    required this.pillState,
    required this.enabled,
    required this.pulse,
  });

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(12),
      child: Padding(
        padding: const EdgeInsets.fromLTRB(16, 14, 16, 14),
        child: Row(
          children: [
            _StatusDot(state: pillState, enabled: enabled, pulse: pulse),
            const SizedBox(width: 12),
            const Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'AI Assistant',
                    style: TextStyle(
                      fontSize: 14.5,
                      fontWeight: FontWeight.w700,
                      color: Color(0xFF0F172A),
                    ),
                  ),
                  SizedBox(height: 2),
                  Text(
                    'API connectivity for pipeline and command assist',
                    style: TextStyle(fontSize: 12, color: Color(0xFF64748B)),
                  ),
                ],
              ),
            ),
            Text(
              expanded ? 'Hide' : 'Configure',
              style: const TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.w600,
                color: Color(0xFF6366F1),
              ),
            ),
            Icon(
              expanded ? Icons.expand_less : Icons.expand_more,
              color: const Color(0xFF6366F1),
            ),
          ],
        ),
      ),
    );
  }
}

class _StatusDot extends StatelessWidget {
  final AiPillState state;
  final bool enabled;
  final AnimationController pulse;

  const _StatusDot({
    required this.state,
    required this.enabled,
    required this.pulse,
  });

  @override
  Widget build(BuildContext context) {
    if (!enabled) {
      return Container(
        width: 10,
        height: 10,
        decoration: const BoxDecoration(
          color: Color(0xFFCBD5E1),
          shape: BoxShape.circle,
        ),
      );
    }

    Color color;
    switch (state) {
      case AiPillState.connecting:
      case AiPillState.disconnected:
        color = state == AiPillState.connecting
            ? const Color(0xFFF59E0B)
            : const Color(0xFF94A3B8);
        return AnimatedBuilder(
          animation: pulse,
          builder: (_, __) => Container(
            width: 10,
            height: 10,
            decoration: BoxDecoration(
              color: color.withOpacity(0.5 + pulse.value * 0.5),
              shape: BoxShape.circle,
            ),
          ),
        );
      case AiPillState.ready:
        color = const Color(0xFF6366F1);
      case AiPillState.readyLocal:
        color = const Color(0xFF059669);
      case AiPillState.error:
        color = const Color(0xFFEF4444);
      case AiPillState.hidden:
        color = const Color(0xFFCBD5E1);
    }

    return Container(
      width: 10,
      height: 10,
      decoration: BoxDecoration(color: color, shape: BoxShape.circle),
    );
  }
}

class _EnabledTile extends StatefulWidget {
  final bool enabled;
  final bool isSaving;
  final Future<void> Function(bool) onChanged;

  const _EnabledTile({
    required this.enabled,
    required this.isSaving,
    required this.onChanged,
  });

  @override
  State<_EnabledTile> createState() => _EnabledTileState();
}

class _EnabledTileState extends State<_EnabledTile> {
  bool _toggling = false;

  Future<void> _handleChanged(bool value) async {
    if (_toggling || widget.isSaving) return;
    setState(() => _toggling = true);
    try {
      await widget.onChanged(value);
    } catch (_) {
      if (!mounted) return;
      Get.snackbar(
        'Could not save setting',
        'Your AI Assistant preference was not saved. Please try again.',
        snackPosition: SnackPosition.BOTTOM,
        backgroundColor: const Color(0xFFEF4444),
        colorText: Colors.white,
        margin: const EdgeInsets.all(16),
        duration: const Duration(seconds: 3),
      );
    } finally {
      if (mounted) setState(() => _toggling = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final disabled = widget.isSaving || _toggling;
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 12),
      child: SwitchListTile(
        contentPadding: const EdgeInsets.symmetric(horizontal: 4),
        title: const Text(
          'Enable AI Assistant',
          style: TextStyle(fontSize: 14, fontWeight: FontWeight.w700),
        ),
        subtitle: Text(
          AiController.enabledTooltip,
          style: const TextStyle(fontSize: 12),
        ),
        value: widget.enabled,
        activeColor: const Color(0xFF6366F1),
        onChanged: disabled ? null : _handleChanged,
      ),
    );
  }
}

class _ConnectionTestPanel extends StatelessWidget {
  final AiController ai;
  final AnimationController pulse;

  const _ConnectionTestPanel({required this.ai, required this.pulse});

  @override
  Widget build(BuildContext context) {
    return Obx(() {
      final phase = ai.testPhase.value;
      final probing = phase == AiConnectionTestPhase.probing;

      return Container(
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: const Color(0xFFF8FAFC),
          borderRadius: BorderRadius.circular(10),
          border: Border.all(color: const Color(0xFFE2E8F0)),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                if (probing)
                  AnimatedBuilder(
                    animation: pulse,
                    builder: (_, __) => Container(
                      width: 10,
                      height: 10,
                      margin: const EdgeInsets.only(right: 8),
                      decoration: BoxDecoration(
                        color: const Color(0xFFF59E0B)
                            .withOpacity(0.4 + pulse.value * 0.6),
                        shape: BoxShape.circle,
                      ),
                    ),
                  ),
                if (phase == AiConnectionTestPhase.success)
                  const Icon(Icons.check_circle, color: Color(0xFF059669), size: 18),
                if (phase == AiConnectionTestPhase.failure)
                  const Icon(Icons.cancel, color: Color(0xFFEF4444), size: 18),
                if (phase == AiConnectionTestPhase.success ||
                    phase == AiConnectionTestPhase.failure)
                  const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    probing
                        ? ai.testMessage.value
                        : phase == AiConnectionTestPhase.idle
                            ? 'Verify your endpoint responds.'
                            : ai.testMessage.value,
                    style: const TextStyle(fontSize: 12.5, color: Color(0xFF475569)),
                  ),
                ),
              ],
            ),
            if (phase == AiConnectionTestPhase.success &&
                ai.testSnippet.value != null) ...[
              const SizedBox(height: 8),
              Text(
                'Response: ${ai.testSnippet.value}',
                style: const TextStyle(
                  fontSize: 11.5,
                  fontFamily: 'monospace',
                  color: Color(0xFF059669),
                ),
              ),
              Text(
                'Latency: ${ai.testLatencyMs.value}ms',
                style: const TextStyle(fontSize: 11, color: Color(0xFF64748B)),
              ),
            ],
            const SizedBox(height: 12),
            SizedBox(
              width: double.infinity,
              child: FilledButton.icon(
                onPressed: probing ? null : () => ai.testConnection(),
                icon: probing
                    ? const SizedBox(
                        width: 14,
                        height: 14,
                        child: CircularProgressIndicator(
                          strokeWidth: 2,
                          color: Colors.white,
                        ),
                      )
                    : const Icon(Icons.bolt_rounded, size: 16),
                label: Text(probing ? 'Testing…' : 'Test Connection'),
                style: FilledButton.styleFrom(
                  backgroundColor: const Color(0xFF6366F1),
                  padding: const EdgeInsets.symmetric(vertical: 12),
                ),
              ),
            ),
            if (phase != AiConnectionTestPhase.idle && !probing) ...[
              const SizedBox(height: 8),
              Align(
                alignment: Alignment.centerRight,
                child: TextButton(
                  onPressed: ai.resetTestPhase,
                  child: const Text('Dismiss'),
                ),
              ),
            ],
          ],
        ),
      );
    });
  }
}
