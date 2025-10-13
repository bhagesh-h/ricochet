class DockerImage {
  final String repoName;
  final String shortDescription;
  final int starCount;
  final int pullCount;
  final String repoOwner;
  final bool isAutomated;
  final bool isOfficial;

  DockerImage({
    required this.repoName,
    required this.shortDescription,
    required this.starCount,
    required this.pullCount,
    required this.repoOwner,
    required this.isAutomated,
    required this.isOfficial,
  });

  factory DockerImage.fromJson(Map<String, dynamic> json) {
    return DockerImage(
      repoName: json['repo_name'] ?? '',
      shortDescription: json['short_description'] ?? '',
      starCount: json['star_count'] ?? 0,
      pullCount: json['pull_count'] ?? 0,
      repoOwner: json['repo_owner'] ?? '',
      isAutomated: json['is_automated'] ?? false,
      isOfficial: json['is_official'] ?? false,
    );
  }

  String get formattedPullCount {
    if (pullCount >= 1000000000) {
      return '${(pullCount / 1000000000).toStringAsFixed(1)}B';
    } else if (pullCount >= 1000000) {
      return '${(pullCount / 1000000).toStringAsFixed(1)}M';
    } else if (pullCount >= 1000) {
      return '${(pullCount / 1000).toStringAsFixed(1)}K';
    }
    return pullCount.toString();
  }

  String get displayName {
    if (repoOwner.isNotEmpty) {
      return '$repoOwner/$repoName';
    }
    return repoName;
  }
}

class DockerSearchResponse {
  final int count;
  final String? next;
  final String? previous;
  final List<DockerImage> results;

  DockerSearchResponse({
    required this.count,
    this.next,
    this.previous,
    required this.results,
  });

  factory DockerSearchResponse.fromJson(Map<String, dynamic> json) {
    return DockerSearchResponse(
      count: json['count'] ?? 0,
      next: json['next'],
      previous: json['previous'],
      results: (json['results'] as List<dynamic>?)
          ?.map((item) => DockerImage.fromJson(item))
          .toList() ??
          [],
    );
  }
}

class DockerTag {
  final String name;
  final int? size;
  final String? architecture;
  final String? os;
  final String? digest;

  DockerTag({
    required this.name,
    this.size,
    this.architecture,
    this.os,
    this.digest,
  });

  factory DockerTag.fromJson(Map<String, dynamic> json) {
    return DockerTag(
      name: json['name'] ?? '',
      size: json['full_size'],
      architecture: json['architecture'],
      os: json['os'],
      digest: json['digest'],
    );
  }
}

class DockerTagsResponse {
  final int count;
  final String? next;
  final String? previous;
  final List<DockerTag> results;

  DockerTagsResponse({
    required this.count,
    this.next,
    this.previous,
    required this.results,
  });

  factory DockerTagsResponse.fromJson(Map<String, dynamic> json) {
    return DockerTagsResponse(
      count: json['count'] ?? 0,
      next: json['next'],
      previous: json['previous'],
      results: (json['results'] as List<dynamic>?)
          ?.map((item) => DockerTag.fromJson(item))
          .toList() ??
          [],
    );
  }
}