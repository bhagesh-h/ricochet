import '../theme/ai_motion_tokens.dart';

enum AiProviderPreset {
  ollama,
  lmStudio,
  openai,
  openRouter,
  groq,
  custom,
}

enum AiLatencyBucket {
  fast,
  moderate,
  slow;

  static AiLatencyBucket fromDuration(Duration elapsed, {required bool timedOut}) {
    if (timedOut) return slow;
    if (elapsed < AiMotionTokens.latencyThresholdSlow) return fast;
    if (elapsed < AiMotionTokens.latencyThresholdVerySlow) return moderate;
    return slow;
  }
}

class AiConnectivitySettings {
  static const double defaultTemperature = 0.2;
  static const int defaultMaxTokens = 2048;
  static const int defaultTimeoutSeconds = 60;

  final bool enabled;
  final AiProviderPreset providerPreset;
  final String baseUrl;
  final String model;
  final double temperature;
  final int maxTokens;
  final int timeoutSeconds;
  final bool telemetryOptIn;
  final bool connectionVerified;

  const AiConnectivitySettings({
    this.enabled = false,
    this.providerPreset = AiProviderPreset.custom,
    this.baseUrl = '',
    this.model = '',
    this.temperature = defaultTemperature,
    this.maxTokens = defaultMaxTokens,
    this.timeoutSeconds = defaultTimeoutSeconds,
    this.telemetryOptIn = false,
    this.connectionVerified = false,
  });

  static const Map<AiProviderPreset, String> presetUrlTemplates = {
    AiProviderPreset.ollama: 'http://127.0.0.1:11434/v1',
    AiProviderPreset.lmStudio: 'http://127.0.0.1:1234/v1',
    AiProviderPreset.openai: 'https://api.openai.com/v1',
    AiProviderPreset.openRouter: 'https://openrouter.ai/api/v1',
    AiProviderPreset.groq: 'https://api.groq.com/openai/v1',
    AiProviderPreset.custom: '',
  };

  static const Map<AiProviderPreset, String> presetModelHints = {
    AiProviderPreset.ollama: 'llama3.2',
    AiProviderPreset.lmStudio: 'local-model',
    AiProviderPreset.openai: 'gpt-4o-mini',
    AiProviderPreset.openRouter: 'openai/gpt-4o-mini',
    AiProviderPreset.groq: 'llama-3.1-8b-instant',
    AiProviderPreset.custom: '',
  };

  String get normalizedBaseUrl {
    final trimmed = baseUrl.trim();
    if (trimmed.isEmpty) return '';
    return trimmed.endsWith('/') ? trimmed.substring(0, trimmed.length - 1) : trimmed;
  }

  bool get isLoopbackHost {
    final uri = Uri.tryParse(normalizedBaseUrl);
    if (uri == null) return false;
    final host = uri.host.toLowerCase();
    return host == '127.0.0.1' || host == 'localhost' || host == '::1';
  }

  bool urlMatchesPreset(AiProviderPreset preset) {
    if (preset == AiProviderPreset.custom) return true;
    final template = presetUrlTemplates[preset] ?? '';
    return normalizedBaseUrl == template;
  }

  AiConnectivitySettings copyWith({
    bool? enabled,
    AiProviderPreset? providerPreset,
    String? baseUrl,
    String? model,
    double? temperature,
    int? maxTokens,
    int? timeoutSeconds,
    bool? telemetryOptIn,
    bool? connectionVerified,
  }) {
    return AiConnectivitySettings(
      enabled: enabled ?? this.enabled,
      providerPreset: providerPreset ?? this.providerPreset,
      baseUrl: baseUrl ?? this.baseUrl,
      model: model ?? this.model,
      temperature: temperature ?? this.temperature,
      maxTokens: maxTokens ?? this.maxTokens,
      timeoutSeconds: timeoutSeconds ?? this.timeoutSeconds,
      telemetryOptIn: telemetryOptIn ?? this.telemetryOptIn,
      connectionVerified: connectionVerified ?? this.connectionVerified,
    );
  }

  Map<String, dynamic> toJson() => {
        'enabled': enabled,
        'providerPreset': providerPreset.name,
        'baseUrl': baseUrl,
        'model': model,
        'temperature': temperature,
        'maxTokens': maxTokens,
        'timeoutSeconds': timeoutSeconds,
        'telemetryOptIn': telemetryOptIn,
        'connectionVerified': connectionVerified,
      };

  factory AiConnectivitySettings.fromJson(Map<String, dynamic> json) {
    final presetName = json['providerPreset']?.toString() ?? 'custom';
    final preset = AiProviderPreset.values.firstWhere(
      (p) => p.name == presetName,
      orElse: () => AiProviderPreset.custom,
    );

    return AiConnectivitySettings(
      enabled: json['enabled'] == true,
      providerPreset: preset,
      baseUrl: json['baseUrl']?.toString() ?? '',
      model: json['model']?.toString() ?? '',
      temperature: (json['temperature'] is num)
          ? (json['temperature'] as num).toDouble()
          : defaultTemperature,
      maxTokens: json['maxTokens'] is int
          ? json['maxTokens'] as int
          : int.tryParse(json['maxTokens']?.toString() ?? '') ??
              defaultMaxTokens,
      timeoutSeconds: json['timeoutSeconds'] is int
          ? json['timeoutSeconds'] as int
          : int.tryParse(json['timeoutSeconds']?.toString() ?? '') ??
              defaultTimeoutSeconds,
      telemetryOptIn: json['telemetryOptIn'] == true,
      connectionVerified: json['connectionVerified'] == true,
    );
  }
}
