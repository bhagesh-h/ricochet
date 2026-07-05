class AppSettings {
  final bool parallelExecutionEnabled;

  const AppSettings({
    this.parallelExecutionEnabled = false,
  });

  AppSettings copyWith({bool? parallelExecutionEnabled}) {
    return AppSettings(
      parallelExecutionEnabled:
          parallelExecutionEnabled ?? this.parallelExecutionEnabled,
    );
  }

  Map<String, dynamic> toJson() => {
        'parallelExecutionEnabled': parallelExecutionEnabled,
      };

  factory AppSettings.fromJson(Map<String, dynamic> json) {
    return AppSettings(
      parallelExecutionEnabled: json['parallelExecutionEnabled'] == true,
    );
  }
}
