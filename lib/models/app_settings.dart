class AppSettings {
  static const int defaultMaxParallelJobs = 2;
  static const int minMaxParallelJobs = 1;
  static const int maxMaxParallelJobs = 16;

  final bool parallelExecutionEnabled;
  final int maxParallelJobs;

  const AppSettings({
    this.parallelExecutionEnabled = false,
    this.maxParallelJobs = defaultMaxParallelJobs,
  });

  AppSettings copyWith({
    bool? parallelExecutionEnabled,
    int? maxParallelJobs,
  }) {
    return AppSettings(
      parallelExecutionEnabled:
          parallelExecutionEnabled ?? this.parallelExecutionEnabled,
      maxParallelJobs: maxParallelJobs ?? this.maxParallelJobs,
    );
  }

  Map<String, dynamic> toJson() => {
        'parallelExecutionEnabled': parallelExecutionEnabled,
        'maxParallelJobs': maxParallelJobs,
      };

  factory AppSettings.fromJson(Map<String, dynamic> json) {
    final rawMax = json['maxParallelJobs'];
    final parsedMax = rawMax is int
        ? rawMax
        : int.tryParse(rawMax?.toString() ?? '') ??
            defaultMaxParallelJobs;

    return AppSettings(
      parallelExecutionEnabled: json['parallelExecutionEnabled'] == true,
      maxParallelJobs: parsedMax.clamp(minMaxParallelJobs, maxMaxParallelJobs),
    );
  }
}
