import 'dart:io';

import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:window_manager/window_manager.dart';

import '../controllers/home_controller.dart';
import '../controllers/settings_controller.dart';
import '../models/app_settings.dart';
import 'settings/ai_assistant_section.dart';
import 'widgets/ricochet_logo.dart';
import 'widgets/window_buttons.dart';

class SettingsPage extends StatelessWidget {
  const SettingsPage({super.key});

  @override
  Widget build(BuildContext context) {
    final settingsCtrl = Get.find<SettingsController>();
    final homeCtrl = Get.find<HomeController>();

    return Scaffold(
      backgroundColor: const Color(0xFFF0F2F5),
      body: Column(
        children: [
          DragToMoveArea(
            child: Container(
              height: 52,
              decoration: const BoxDecoration(
                color: Colors.white,
                border: Border(bottom: BorderSide(color: Color(0xFFE2E8F0))),
              ),
              padding: EdgeInsets.only(left: Platform.isMacOS ? 80 : 24),
              child: Row(
                children: [
                  IconButton(
                    tooltip: 'Back to Home',
                    onPressed: homeCtrl.goHome,
                    icon: const Icon(Icons.arrow_back_rounded,
                        size: 20, color: Color(0xFF64748B)),
                  ),
                  const SizedBox(width: 4),
                  const RicochetLogo(height: 20),
                  const SizedBox(width: 12),
                  const Text(
                    'Settings',
                    style: TextStyle(
                      fontSize: 15,
                      fontWeight: FontWeight.w700,
                      color: Color(0xFF0F172A),
                    ),
                  ),
                  const Spacer(),
                  if (!Platform.isMacOS) ...[
                    const VerticalDivider(
                      width: 1,
                      color: Color(0xFFE2E8F0),
                      indent: 16,
                      endIndent: 16,
                    ),
                    const WindowButtons(),
                  ],
                ],
              ),
            ),
          ),
          Expanded(
            child: SingleChildScrollView(
              padding: const EdgeInsets.fromLTRB(40, 36, 40, 40),
              child: Align(
                alignment: Alignment.topCenter,
                child: ConstrainedBox(
                  constraints: const BoxConstraints(maxWidth: 720),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text(
                        'Preferences',
                        style: TextStyle(
                          fontSize: 26,
                          fontWeight: FontWeight.w800,
                          color: Color(0xFF0F172A),
                          letterSpacing: -0.5,
                        ),
                      ),
                      const SizedBox(height: 6),
                      const Text(
                        'Tune how Ricochet runs your pipelines on this machine.',
                        style: TextStyle(fontSize: 13.5, color: Color(0xFF64748B)),
                      ),
                      const SizedBox(height: 28),
                      _SettingsSection(
                        title: 'Execution',
                        subtitle:
                            'Control how pipeline nodes are scheduled during a run.',
                        child: Obx(() {
                          if (settingsCtrl.isLoading.value) {
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
                              _ParallelExecutionTile(
                                enabled:
                                    settingsCtrl.parallelExecutionEnabled.value,
                                onChanged: settingsCtrl.setParallelExecutionEnabled,
                              ),
                              if (settingsCtrl.parallelExecutionEnabled.value)
                                _MaxParallelJobsTile(
                                  value: settingsCtrl.maxParallelJobs.value,
                                  logicalProcessors:
                                      settingsCtrl.logicalProcessorCount.value,
                                  effectiveCap:
                                      settingsCtrl.effectiveParallelCap.value,
                                  systemRecommendedCap:
                                      settingsCtrl.systemRecommendedCap,
                                  onChanged: settingsCtrl.setMaxParallelJobs,
                                ),
                            ],
                          );
                        }),
                      ),
                      const SizedBox(height: 16),
                      _SettingsSection(
                        title: 'AI Assistant',
                        subtitle:
                            'Connect an OpenAI-compatible API for pipeline and command assist.',
                        child: const AiAssistantSettingsSection(),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _SettingsSection extends StatelessWidget {
  final String title;
  final String subtitle;
  final Widget child;

  const _SettingsSection({
    required this.title,
    required this.subtitle,
    required this.child,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: const Color(0xFFE2E8F0)),
        boxShadow: const [
          BoxShadow(
            color: Color(0x08000000),
            blurRadius: 12,
            offset: Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(24, 22, 24, 0),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: const TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w700,
                    color: Color(0xFF0F172A),
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  subtitle,
                  style: const TextStyle(
                    fontSize: 12.5,
                    color: Color(0xFF64748B),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 8),
          child,
        ],
      ),
    );
  }
}

class _ParallelExecutionTile extends StatefulWidget {
  final bool enabled;
  final Future<void> Function(bool) onChanged;

  const _ParallelExecutionTile({
    required this.enabled,
    required this.onChanged,
  });

  @override
  State<_ParallelExecutionTile> createState() => _ParallelExecutionTileState();
}

class _ParallelExecutionTileState extends State<_ParallelExecutionTile> {
  bool _isSaving = false;

  String get _platformLabel {
    if (Platform.isWindows) return 'Windows';
    if (Platform.isMacOS) return 'macOS';
    return 'this machine';
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.fromLTRB(12, 4, 12, 12),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: widget.enabled
              ? const Color(0xFF6366F1).withOpacity(0.2)
              : const Color(0xFFE2E8F0),
        ),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: 42,
            height: 42,
            decoration: BoxDecoration(
              color: widget.enabled
                  ? const Color(0xFFEEF2FF)
                  : const Color(0xFFF1F5F9),
              borderRadius: BorderRadius.circular(10),
            ),
            child: Icon(
              Icons.account_tree_outlined,
              size: 22,
              color: widget.enabled
                  ? const Color(0xFF6366F1)
                  : const Color(0xFF64748B),
            ),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    const Expanded(
                      child: Text(
                        'Parallel Execution',
                        style: TextStyle(
                          fontSize: 14.5,
                          fontWeight: FontWeight.w700,
                          color: Color(0xFF0F172A),
                        ),
                      ),
                    ),
                    Switch.adaptive(
                      value: widget.enabled,
                      activeColor: const Color(0xFF6366F1),
                      onChanged: _isSaving
                          ? null
                          : (value) async {
                              setState(() => _isSaving = true);
                              try {
                                await widget.onChanged(value);
                              } catch (_) {
                                if (!context.mounted) return;
                                Get.snackbar(
                                  'Could not save setting',
                                  'Your preference was not saved. Please try again.',
                                  snackPosition: SnackPosition.BOTTOM,
                                  backgroundColor: const Color(0xFFEF4444),
                                  colorText: Colors.white,
                                  margin: const EdgeInsets.all(16),
                                  duration: const Duration(seconds: 3),
                                );
                                return;
                              } finally {
                                if (mounted) {
                                  setState(() => _isSaving = false);
                                }
                              }
                              if (!context.mounted) return;
                              Get.snackbar(
                                value
                                    ? 'Parallel execution enabled'
                                    : 'Parallel execution disabled',
                                value
                                    ? 'Independent branches will run concurrently on your local Docker daemon.'
                                    : 'Pipelines will run one node at a time, as before.',
                                snackPosition: SnackPosition.BOTTOM,
                                backgroundColor: const Color(0xFF1E293B),
                                colorText: Colors.white,
                                margin: const EdgeInsets.all(16),
                                duration: const Duration(seconds: 3),
                              );
                            },
                    ),
                  ],
                ),
                const SizedBox(height: 6),
                Text(
                  SettingsController.parallelExecutionSummary,
                  style: const TextStyle(
                    fontSize: 12.5,
                    height: 1.45,
                    color: Color(0xFF64748B),
                  ),
                ),
                const SizedBox(height: 8),
                Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Padding(
                      padding: EdgeInsets.only(top: 1),
                      child: Icon(
                        Icons.info_outline_rounded,
                        size: 14,
                        color: Color(0xFF6366F1),
                      ),
                    ),
                    const SizedBox(width: 6),
                    Expanded(
                      child: Text(
                        SettingsController.parallelExecutionPlatformNote(
                          _platformLabel,
                        ),
                        style: const TextStyle(
                          fontSize: 11.5,
                          height: 1.4,
                          fontWeight: FontWeight.w500,
                          color: Color(0xFF4338CA),
                        ),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _MaxParallelJobsTile extends StatefulWidget {
  final int value;
  final int logicalProcessors;
  final int effectiveCap;
  final int systemRecommendedCap;
  final Future<void> Function(int) onChanged;

  const _MaxParallelJobsTile({
    required this.value,
    required this.logicalProcessors,
    required this.effectiveCap,
    required this.systemRecommendedCap,
    required this.onChanged,
  });

  @override
  State<_MaxParallelJobsTile> createState() => _MaxParallelJobsTileState();
}

class _MaxParallelJobsTileState extends State<_MaxParallelJobsTile> {
  bool _isSaving = false;

  @override
  Widget build(BuildContext context) {
    final cappedBySystem = widget.value > widget.effectiveCap;

    return Container(
      margin: const EdgeInsets.fromLTRB(12, 0, 12, 12),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: const Color(0xFFE2E8F0)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                width: 42,
                height: 42,
                decoration: BoxDecoration(
                  color: const Color(0xFFF1F5F9),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: const Icon(
                  Icons.speed_rounded,
                  size: 22,
                  color: Color(0xFF64748B),
                ),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      'Max parallel jobs',
                      style: TextStyle(
                        fontSize: 14.5,
                        fontWeight: FontWeight.w700,
                        color: Color(0xFF0F172A),
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      SettingsController.maxParallelJobsSummary,
                      style: const TextStyle(
                        fontSize: 12.5,
                        height: 1.45,
                        color: Color(0xFF64748B),
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      'Default ${AppSettings.defaultMaxParallelJobs}. '
                      'This machine has ${widget.logicalProcessors} CPU '
                      'thread${widget.logicalProcessors == 1 ? '' : 's'}.',
                      style: const TextStyle(
                        fontSize: 11.5,
                        height: 1.4,
                        color: Color(0xFF94A3B8),
                      ),
                    ),
                  ],
                ),
              ),
              Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 10,
                  vertical: 4,
                ),
                decoration: BoxDecoration(
                  color: const Color(0xFFEEF2FF),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Text(
                  '${widget.value}',
                  style: const TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w800,
                    color: Color(0xFF4338CA),
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 14),
              SliderTheme(
                data: SliderTheme.of(context).copyWith(
                  activeTrackColor: const Color(0xFF6366F1),
                  inactiveTrackColor: const Color(0xFFE2E8F0),
                  thumbColor: const Color(0xFF6366F1),
                  overlayColor: const Color(0x336366F1),
                  trackHeight: 4,
                ),
                child: Slider(
                  value: widget.value.toDouble(),
                  min: AppSettings.minMaxParallelJobs.toDouble(),
                  max: AppSettings.maxMaxParallelJobs.toDouble(),
                  divisions: AppSettings.maxMaxParallelJobs -
                      AppSettings.minMaxParallelJobs,
                  label: '${widget.value}',
                  onChanged: _isSaving
                      ? null
                      : (value) async {
                          final next = value.round();
                          if (next == widget.value) return;
                          setState(() => _isSaving = true);
                          try {
                            await widget.onChanged(next);
                          } catch (_) {
                            if (!context.mounted) return;
                            Get.snackbar(
                              'Could not save setting',
                              'Your preference was not saved. Please try again.',
                              snackPosition: SnackPosition.BOTTOM,
                              backgroundColor: const Color(0xFFEF4444),
                              colorText: Colors.white,
                              margin: const EdgeInsets.all(16),
                              duration: const Duration(seconds: 3),
                            );
                          } finally {
                            if (mounted) setState(() => _isSaving = false);
                          }
                        },
                ),
              ),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    'Effective at run time: ${widget.effectiveCap} concurrent '
                    'container${widget.effectiveCap == 1 ? '' : 's'}',
                    style: const TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.w600,
                      color: Color(0xFF475569),
                    ),
                  ),
                  if (cappedBySystem)
                    const Text(
                      'Capped by CPU capacity',
                      style: TextStyle(
                        fontSize: 11.5,
                        fontWeight: FontWeight.w600,
                        color: Color(0xFF6366F1),
                      ),
                    ),
                ],
              ),
              if (widget.systemRecommendedCap < AppSettings.maxMaxParallelJobs)
                Padding(
                  padding: const EdgeInsets.only(top: 6),
                  child: Text(
                    'Recommended safe maximum on this machine: '
                    '${widget.systemRecommendedCap} '
                    '(1 thread reserved for the OS and Docker).',
                    style: const TextStyle(
                      fontSize: 11.5,
                      color: Color(0xFF94A3B8),
                    ),
                  ),
                ),
            ],
          ),
    );
  }
}
