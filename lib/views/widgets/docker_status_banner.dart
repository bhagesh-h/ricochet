import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:url_launcher/url_launcher.dart';
import '../../controllers/docker_controller.dart';
import '../../models/docker_info.dart';

/// Banner showing Docker status at the top of the app
class DockerStatusBanner extends StatelessWidget {
  const DockerStatusBanner({Key? key}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    final DockerController dockerCtrl = Get.find();

    return Obx(() {
      final status = dockerCtrl.status.value;

      // Don't show banner if Docker is running (unless Apple Silicon)
      if (status == DockerStatus.running &&
          !dockerCtrl.shouldShowAppleSiliconNotice) {
        return const SizedBox.shrink();
      }

      // Don't show while checking (only on first load)
      if (status == DockerStatus.checking &&
          dockerCtrl.lastCheckTime.value == null) {
        return const SizedBox.shrink();
      }

      return _buildBanner(context, dockerCtrl, status);
    });
  }

  Widget _buildBanner(
      BuildContext context, DockerController dockerCtrl, DockerStatus status) {
    final config = _getBannerConfig(status, dockerCtrl);

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      decoration: BoxDecoration(
        color: config.backgroundColor,
        border: Border(
          bottom: BorderSide(color: config.borderColor, width: 1),
        ),
      ),
      child: Row(
        children: [
          // Icon
          Icon(
            config.icon,
            color: config.iconColor,
            size: 20,
          ),
          const SizedBox(width: 12),

          // Message
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  config.title,
                  style: TextStyle(
                    color: config.textColor,
                    fontWeight: FontWeight.w600,
                    fontSize: 13,
                  ),
                ),
                if (config.subtitle != null) ...[
                  const SizedBox(height: 2),
                  Text(
                    config.subtitle!,
                    style: TextStyle(
                      color: config.textColor.withOpacity(0.8),
                      fontSize: 12,
                    ),
                  ),
                ],
              ],
            ),
          ),

          // Action button
          if (config.actionLabel != null)
            TextButton(
              onPressed: () => config.onAction?.call(dockerCtrl),
              style: TextButton.styleFrom(
                foregroundColor: config.actionColor,
                padding:
                    const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
              ),
              child: Text(
                config.actionLabel!,
                style: const TextStyle(
                  fontWeight: FontWeight.w600,
                  fontSize: 12,
                ),
              ),
            ),

          // Refresh button
          if (status != DockerStatus.running)
            IconButton(
              onPressed: dockerCtrl.isChecking.value
                  ? null
                  : () => dockerCtrl.retryConnection(),
              icon: dockerCtrl.isChecking.value
                  ? SizedBox(
                      width: 16,
                      height: 16,
                      child: CircularProgressIndicator(
                        strokeWidth: 2,
                        valueColor: AlwaysStoppedAnimation(config.iconColor),
                      ),
                    )
                  : Icon(Icons.refresh, size: 18, color: config.iconColor),
              tooltip: 'Retry',
              padding: EdgeInsets.zero,
              constraints: const BoxConstraints(),
            ),
        ],
      ),
    );
  }

  _BannerConfig _getBannerConfig(
      DockerStatus status, DockerController dockerCtrl) {
    switch (status) {
      case DockerStatus.running:
        // Apple Silicon notice
        if (dockerCtrl.shouldShowAppleSiliconNotice) {
          return _BannerConfig(
            backgroundColor: const Color(0xFFEFF6FF),
            borderColor: const Color(0xFFBFDBFE),
            icon: Icons.info_outline,
            iconColor: const Color(0xFF3B82F6),
            textColor: const Color(0xFF1E40AF),
            title: 'Apple Silicon Detected',
            subtitle: dockerCtrl.appleSiliconNotice,
            actionLabel: null,
            actionColor: const Color(0xFF3B82F6),
            onAction: null,
          );
        }
        // Normal running state (shouldn't show)
        return _BannerConfig(
          backgroundColor: const Color(0xFFF0FDF4),
          borderColor: const Color(0xFFBBF7D0),
          icon: Icons.check_circle_outline,
          iconColor: const Color(0xFF10B981),
          textColor: const Color(0xFF065F46),
          title: dockerCtrl.statusMessage,
          subtitle: dockerCtrl.detailsMessage,
          actionLabel: null,
          actionColor: const Color(0xFF10B981),
          onAction: null,
        );

      case DockerStatus.stopped:
        return _BannerConfig(
          backgroundColor: const Color(0xFFFFFBEB),
          borderColor: const Color(0xFFFDE68A),
          icon: Icons.warning_amber_rounded,
          iconColor: const Color(0xFFF59E0B),
          textColor: const Color(0xFF92400E),
          title: 'Docker is not running',
          subtitle: dockerCtrl.helpMessage,
          actionLabel: 'Help',
          actionColor: const Color(0xFFF59E0B),
          onAction: (ctrl) => _showHelpDialog(ctrl),
        );

      case DockerStatus.notInstalled:
        return _BannerConfig(
          backgroundColor: const Color(0xFFFEF2F2),
          borderColor: const Color(0xFFFECACA),
          icon: Icons.error_outline,
          iconColor: const Color(0xFFEF4444),
          textColor: const Color(0xFF991B1B),
          title: 'Docker Desktop is not installed',
          subtitle: dockerCtrl.helpMessage,
          actionLabel: 'Download',
          actionColor: const Color(0xFFEF4444),
          onAction: (ctrl) => _launchDockerDownload(ctrl),
        );

      case DockerStatus.checking:
        return _BannerConfig(
          backgroundColor: const Color(0xFFF8FAFC),
          borderColor: const Color(0xFFE2E8F0),
          icon: Icons.hourglass_empty,
          iconColor: const Color(0xFF64748B),
          textColor: const Color(0xFF334155),
          title: 'Checking Docker status...',
          subtitle: null,
          actionLabel: null,
          actionColor: const Color(0xFF64748B),
          onAction: null,
        );

      case DockerStatus.error:
        return _BannerConfig(
          backgroundColor: const Color(0xFFFEF2F2),
          borderColor: const Color(0xFFFECACA),
          icon: Icons.error_outline,
          iconColor: const Color(0xFFEF4444),
          textColor: const Color(0xFF991B1B),
          title: 'Failed to check Docker status',
          subtitle: dockerCtrl.errorMessage.value.isNotEmpty
              ? dockerCtrl.errorMessage.value
              : 'Please check your Docker installation',
          actionLabel: 'Help',
          actionColor: const Color(0xFFEF4444),
          onAction: (ctrl) => _showHelpDialog(ctrl),
        );
    }
  }

  void _launchDockerDownload(DockerController ctrl) async {
    final url = Uri.parse(ctrl.downloadUrl);
    if (await canLaunchUrl(url)) {
      await launchUrl(url, mode: LaunchMode.externalApplication);
    }
  }

  void _showHelpDialog(DockerController ctrl) {
    Get.dialog(
      AlertDialog(
        title: const Text('Docker Setup Help'),
        content: SingleChildScrollView(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                'Platform: ${ctrl.platformName}',
                style: const TextStyle(fontWeight: FontWeight.w600),
              ),
              const SizedBox(height: 8),
              Text(
                'Architecture: ${ctrl.architectureName}',
                style: const TextStyle(fontWeight: FontWeight.w600),
              ),
              const SizedBox(height: 16),
              const Text(
                'Steps to resolve:',
                style: TextStyle(fontWeight: FontWeight.w600),
              ),
              const SizedBox(height: 8),
              Text(ctrl.helpMessage),
              const SizedBox(height: 16),
              if (ctrl.status.value == DockerStatus.notInstalled)
                ElevatedButton.icon(
                  onPressed: () {
                    Get.back();
                    _launchDockerDownload(ctrl);
                  },
                  icon: const Icon(Icons.download),
                  label: const Text('Download Docker Desktop'),
                ),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Get.back(),
            child: const Text('Close'),
          ),
          TextButton(
            onPressed: () {
              Get.back();
              ctrl.retryConnection();
            },
            child: const Text('Retry'),
          ),
        ],
      ),
    );
  }
}

class _BannerConfig {
  final Color backgroundColor;
  final Color borderColor;
  final IconData icon;
  final Color iconColor;
  final Color textColor;
  final String title;
  final String? subtitle;
  final String? actionLabel;
  final Color actionColor;
  final Function(DockerController)? onAction;

  _BannerConfig({
    required this.backgroundColor,
    required this.borderColor,
    required this.icon,
    required this.iconColor,
    required this.textColor,
    required this.title,
    this.subtitle,
    this.actionLabel,
    required this.actionColor,
    this.onAction,
  });
}
