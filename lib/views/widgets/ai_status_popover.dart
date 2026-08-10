import 'package:flutter/material.dart';
import 'package:get/get.dart';

import '../../controllers/ai_controller.dart';
import '../../controllers/home_controller.dart';

class AiStatusPopover extends StatelessWidget {
  static const double width = 300;

  final AiController ai;

  const AiStatusPopover({super.key, required this.ai});

  @override
  Widget build(BuildContext context) {
    return Material(
      elevation: 12,
      borderRadius: BorderRadius.circular(12),
      color: Colors.white,
      child: Container(
        width: width,
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: const Color(0xFFE2E8F0)),
        ),
        child: Obx(() {
          final conn = ai.connectivity.value;
          final probing = ai.testPhase.value == AiConnectionTestPhase.probing ||
              ai.inFlightRequestCount.value > 0;

          return Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                probing ? 'AI · Connecting' : ai.pillLabel,
                style: const TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.w800,
                  color: Color(0xFF0F172A),
                ),
              ),
              const SizedBox(height: 8),
              if (conn.model.isNotEmpty)
                _row('Model', conn.model),
              if (conn.baseUrl.isNotEmpty)
                _row('Endpoint', _truncate(conn.baseUrl, 36)),
              if (ai.testLatencyMs.value > 0 && conn.connectionVerified)
                _row('Last test', '${ai.testLatencyMs.value}ms'),
              if (probing) ...[
                const SizedBox(height: 8),
                const LinearProgressIndicator(minHeight: 2),
                const SizedBox(height: 6),
                Text(
                  ai.testMessage.value.isNotEmpty
                      ? ai.testMessage.value
                      : 'Working…',
                  style: const TextStyle(fontSize: 11.5, color: Color(0xFF64748B)),
                ),
              ],
              const SizedBox(height: 14),
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: [
                  OutlinedButton(
                    onPressed: () {
                      Get.back();
                      Get.find<HomeController>().openSettings();
                    },
                    child: const Text('Open AI Settings'),
                  ),
                  if (!probing)
                    FilledButton(
                      onPressed: () async {
                        await ai.testConnection();
                      },
                      style: FilledButton.styleFrom(
                        backgroundColor: const Color(0xFF6366F1),
                      ),
                      child: const Text('Test again'),
                    ),
                ],
              ),
            ],
          );
        }),
      ),
    );
  }

  Widget _row(String label, String value) => Padding(
        padding: const EdgeInsets.only(bottom: 4),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            SizedBox(
              width: 72,
              child: Text(
                label,
                style: const TextStyle(fontSize: 11, color: Color(0xFF94A3B8)),
              ),
            ),
            Expanded(
              child: Text(
                value,
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(fontSize: 11.5, color: Color(0xFF475569)),
              ),
            ),
          ],
        ),
      );

  String _truncate(String s, int max) =>
      s.length <= max ? s : '${s.substring(0, max)}…';
}
