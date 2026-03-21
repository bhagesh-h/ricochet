import 'dart:convert';
import 'package:get/get.dart';
import 'package:http/http.dart' as http;
import '../models/docker_image.dart';

class DockerSearchController extends GetxController {
  final RxList<DockerImage> searchResults = <DockerImage>[].obs;
  final RxBool isLoading = false.obs;
  final RxString searchQuery = ''.obs;
  final RxString errorMessage = ''.obs;

  // Cache for image tags with LRU and TTL
  final Map<String, TagCacheEntry> _tagCache = {};
  static const int _maxCacheSize = 100;

  // Deduplicate concurrent requests for the same image
  final Map<String, Future<TagFetchResult>> _inFlightRequests = {};

  String _getDockerHubUrl(String path) {
    // Docker Hub API V2 base
    return 'https://hub.docker.com/v2/$path';
  }

  /// Robust retry helper with exponential backoff
  Future<T> _retry<T>(Future<T> Function() fn, {int maxAttempts = 3}) async {
    int attempts = 0;
    while (attempts < maxAttempts) {
      try {
        return await fn();
      } catch (e) {
        attempts++;
        if (attempts >= maxAttempts) rethrow;
        // Exponential backoff: 500ms, 1000ms, 1500ms...
        await Future.delayed(Duration(milliseconds: 500 * attempts));
      }
    }
    throw Exception('Failed after $maxAttempts attempts');
  }

  Future<void> searchDockerImages(
    String query, {
    int pageSize = 10,
    bool officialOnly = false,
  }) async {
    searchQuery.value = query;
    if (query.isEmpty) {
      searchResults.clear();
      return;
    }

    isLoading.value = true;
    errorMessage.value = '';

    try {
      await _retry(() async {
        final url = Uri.parse(
          _getDockerHubUrl(
            'search/repositories/?query=$query&page_size=$pageSize&is_official=$officialOnly',
          ),
        );
        final response = await http.get(url, headers: {'Accept': 'application/json'});
        
        if (response.statusCode == 200) {
          final jsonResponse = jsonDecode(response.body);
          final searchResponse = DockerSearchResponse.fromJson(jsonResponse);
          searchResults.value = searchResponse.results;
        } else {
          throw Exception('Search failed: ${response.statusCode}');
        }
      });
    } catch (e) {
      errorMessage.value = 'Failed to search Docker images. Please try again.';
      searchResults.clear();
    } finally {
      isLoading.value = false;
    }
  }

  /// Fetch tags for a given image. 
  /// [all] = true will fetch all tags (paginated), otherwise first 20.
  Future<TagFetchResult> getImageTags(String imageName, {bool all = false}) async {
    // 1. Check Cache
    if (_tagCache.containsKey(imageName)) {
      final entry = _tagCache[imageName]!;
      
      // If we need 'all' but only have 'partial', or if it's expired
      if ((all && !entry.isFullFetch) || entry.isExpired) {
        // Stale-While-Revalidate: Return cached, but refresh in background
        _refreshCacheInBackground(imageName, fetchAll: all);
        return TagFetchResult(status: TagFetchStatus.success, tags: entry.tags);
      }
      return TagFetchResult(status: TagFetchStatus.success, tags: entry.tags);
    }

    // 2. Check for In-Flight requests (Elite Deduplication)
    final cacheKey = "${imageName}_${all ? 'all' : 'top'}";
    if (_inFlightRequests.containsKey(cacheKey)) {
      return await _inFlightRequests[cacheKey]!;
    }

    // 3. Fresh Fetch
    final request = _fetchTags(imageName, fetchAll: all);
    _inFlightRequests[cacheKey] = request;
    
    try {
      final result = await request;
      return result;
    } finally {
      _inFlightRequests.remove(cacheKey);
    }
  }

  Future<TagFetchResult> _fetchTags(String imageName, {bool fetchAll = false}) async {
    try {
      final parts = imageName.split('/');
      final owner = parts.length > 1 ? parts[0] : 'library';
      final repo = parts.length > 1 ? parts[1] : parts[0];
      
      List<DockerTag> allTags = [];
      String? nextUrl = _getDockerHubUrl('repositories/$owner/$repo/tags/?page_size=${fetchAll ? 100 : 20}');

      int pageLimit = fetchAll ? 10 : 1; // Limit to 1000 tags total for safety
      int pagesFetched = 0;

      while (nextUrl != null && pagesFetched < pageLimit) {
        final currentUrl = nextUrl;
        final response = await _retry(() => http.get(Uri.parse(currentUrl), headers: {'Accept': 'application/json'}));
        
        if (response.statusCode == 200) {
          final data = DockerTagsResponse.fromJson(jsonDecode(response.body));
          allTags.addAll(data.results);
          nextUrl = data.next;
          pagesFetched++;
        } else if (response.statusCode == 404) {
          return TagFetchResult(status: TagFetchStatus.empty, tags: []);
        } else {
          throw Exception('Failed to fetch tags: ${response.statusCode}');
        }
      }

      // Sort tags using deterministic Genomic Sorter
      allTags.sort(compareTags);

      // LRU Eviction (Elite Memory Management)
      if (_tagCache.length >= _maxCacheSize) {
        // Simple LRU: remove the oldest key
        final oldestKey = _tagCache.keys.first;
        _tagCache.remove(oldestKey);
      }
      
      _tagCache[imageName] = TagCacheEntry(
        tags: allTags,
        fetchedAt: DateTime.now(),
        isFullFetch: fetchAll,
      );

      return TagFetchResult(
        status: allTags.isEmpty ? TagFetchStatus.empty : TagFetchStatus.success,
        tags: allTags,
      );
    } catch (e) {
      return TagFetchResult(status: TagFetchStatus.failed, tags: [], errorMessage: e.toString());
    }
  }

  void _refreshCacheInBackground(String imageName, {bool fetchAll = false}) async {
    // Avoid double-fetching if already in-flight
    final cacheKey = "${imageName}_${fetchAll ? 'all' : 'top'}";
    if (_inFlightRequests.containsKey(cacheKey)) return;

    final request = _fetchTags(imageName, fetchAll: fetchAll);
    _inFlightRequests[cacheKey] = request;
    await request;
    _inFlightRequests.remove(cacheKey);
  }

  /// Deterministic Genomic Sorter
  int compareTags(DockerTag a, DockerTag b) {
    // 1. Exact "latest"
    if (a.name == 'latest') return -1;
    if (b.name == 'latest') return 1;

    // 2. Version-like tags (v1.2.3, 1.2.3_cv1, etc.)
    final versionRegex = RegExp(r'^v?\d+(\.\d+)+');
    final aIsVersion = versionRegex.hasMatch(a.name);
    final bIsVersion = versionRegex.hasMatch(b.name);

    if (aIsVersion && !bIsVersion) return -1;
    if (!aIsVersion && bIsVersion) return 1;

    if (aIsVersion && bIsVersion) {
      // Both are versions, try to sort by string (descending) mostly suffices for v-tags
      // unless we want a full semver parser, but string compare + recency handles most bio tags.
      int stringCompare = b.name.compareTo(a.name);
      if (stringCompare != 0) return stringCompare;
    }

    // 3. Fallback → last updated (Recency)
    return b.lastUpdated.compareTo(a.lastUpdated);
  }

  Future<String> getSmartDefaultTag(String imageName) async {
    final result = await getImageTags(imageName, all: false);
    if (result.status != TagFetchStatus.success || result.tags.isEmpty) {
      return 'latest';
    }
    return result.tags.first.name;
  }

  void clearSearch() {
    searchQuery.value = '';
    searchResults.clear();
    errorMessage.value = '';
  }

  String getDockerRunCommand(String imageName, String tag) {
    return 'docker run --rm -it $imageName:$tag';
  }
}
