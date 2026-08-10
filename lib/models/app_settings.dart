import 'app_settings.dart';
import 'ai_connectivity_settings.dart';

class AppSettings {
  static const int defaultMaxParallelJobs = 2;
  static const int minMaxParallelJobs = 1;
  static const int maxMaxParallelJobs = 16;

  final bool parallelExecutionEnabled;
  final int maxParallelJobs;
  final AiConnectivitySettings aiAssistant;

  const AppSettings({
    this.parallelExecutionEnabled = false,
    this.maxParallelJobs = defaultMaxParallelJobs,
    this.aiAssistant = const AiConnectivitySettings(),
  });

  AppSettings copyWith({
    bool? parallelExecutionEnabled,
    int? maxParallelJobs,
    AiConnectivitySettings? aiAssistant,
  }) {
    return AppSettings(
      parallelExecutionEnabled:
          parallelExecutionEnabled ?? this.parallelExecutionEnabled,
      maxParallelJobs: maxParallelJobs ?? this.maxParallelJobs,
      aiAssistant: aiAssistant ?? this.aiAssistant,
    );
  }

  Map<String, dynamic> toJson() => {
        'parallelExecutionEnabled': parallelExecutionEnabled,
        'maxParallelJobs': maxParallelJobs,
        'aiAssistant': aiAssistant.toJson(),
      };

  factory AppSettings.fromJson(Map<String, dynamic> json) {
    final rawMax = json['maxParallelJobs'];
    final parsedMax = rawMax is int
        ? rawMax
        : int.tryParse(rawMax?.toString() ?? '') ??
            defaultMaxParallelJobs;

    final aiJson = json['aiAssistant'];
    final aiSettings = aiJson is Map<String, dynamic>
        ? AiConnectivitySettings.fromJson(aiJson)
        : const AiConnectivitySettings();

    return AppSettings(
      parallelExecutionEnabled: json['parallelExecutionEnabled'] == true,
      maxParallelJobs: parsedMax.clamp(minMaxParallelJobs, maxMaxParallelJobs),
      aiAssistant: aiSettings,
    );
  }
}
