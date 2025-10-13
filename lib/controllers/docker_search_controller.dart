import 'dart:convert';
import 'package:get/get.dart';
import 'package:http/http.dart' as http;
import '../models/docker_image.dart';
import 'package:flutter/foundation.dart' show kIsWeb;

class DockerSearchController extends GetxController {
  final RxList<DockerImage> searchResults = <DockerImage>[].obs;
  final RxBool isLoading = false.obs;
  final RxString searchQuery = ''.obs;
  final RxString errorMessage = ''.obs;

  String _getDockerHubUrl(String path) {
    if (kIsWeb) {
      // Use CORS proxy for web builds
      return 'https://hub.docker.com/v2/$path';
    } else {
      return 'https://hub.docker.com/v2/$path';
    }
  }

  Future<void> searchDockerImages(String query, {int pageSize = 10, bool officialOnly = true, int maxRetries = 2}) async {
    searchQuery.value = query;

    if (query.isEmpty) {
      searchResults.clear();
      return;
    }

    isLoading.value = true;
    errorMessage.value = '';
    int attempt = 0;

    while (attempt < maxRetries) {
      try {
        final url = Uri.parse(
          _getDockerHubUrl('search/repositories/?'
          'query=$query'
          '&page_size=$pageSize'
          '&is_official=$officialOnly')
        );
        final response = await http.get(
          url,
          headers: {
            'Accept': 'application/json',
          },
        );
        if (response.statusCode == 200) {
          final jsonResponse = jsonDecode(response.body);
          final searchResponse = DockerSearchResponse.fromJson(jsonResponse);
          searchResults.value = searchResponse.results;
          break; // Success, exit retry loop
        } else {
          errorMessage.value = 'Failed to search Docker images: ${response.statusCode}';
          searchResults.clear();
          break; // HTTP error, don't retry
        }
      } catch (e) {
        print('Error during Docker image search: $e');
        attempt++;
        if (attempt >= maxRetries) {
          if (e.toString().contains('Operation not permitted') ||
              e.toString().contains('SocketException') ||
              e.toString().contains('Failed to fetch')) {
            if (kIsWeb) {
              errorMessage.value = 'Network error: Unable to connect to Docker Hub. ';
            } else {
              errorMessage.value = 'Network error: Please check your internet connection and app permissions';
            }
          } else {
            errorMessage.value = 'Error searching Docker images: $e';
          }
          print('Error searching Docker images: $e');
          searchResults.clear();
        } else {
          // Wait before retrying
          await Future.delayed(const Duration(milliseconds: 500));
        }
      }
    }
    isLoading.value = false;
  }

  Future<List<DockerTag>> getImageTags(String imageName, {int pageSize = 5, int maxRetries = 2}) async {
    int attempt = 0;
    
    while (attempt < maxRetries) {
      try {
        // Handle official images (no owner) vs user images
        final parts = imageName.split('/');
        final owner = parts.length > 1 ? parts[0] : 'library';
        final repo = parts.length > 1 ? parts[1] : parts[0];

        final url = Uri.parse(
          _getDockerHubUrl('repositories/$owner/$repo/tags/?'
          'page_size=$pageSize&page=1')
        );

        final response = await http.get(
          url,
          headers: {
            'Accept': 'application/json',
          },
        );

        if (response.statusCode == 200) {
          final jsonResponse = jsonDecode(response.body);
          final tagsResponse = DockerTagsResponse.fromJson(jsonResponse);
          return tagsResponse.results;
        } else if (response.statusCode == 404) {
          throw Exception('Image not found: $imageName');
        } else {
          throw Exception('Failed to fetch tags: ${response.statusCode}');
        }
      } catch (e) {
        attempt++;
        if (attempt >= maxRetries) {
          if (e.toString().contains('Operation not permitted') ||
              e.toString().contains('SocketException') ||
              e.toString().contains('Failed to fetch')) {
            if (kIsWeb) {
              throw Exception('Network error: Unable to fetch tags due to CORS restrictions in web browsers');
            } else {
              throw Exception('Network error: Unable to fetch tags. Please check your connection');
            }
          } else {
            throw Exception('Error fetching tags: $e');
          }
        }
        // Wait before retrying
        await Future.delayed(const Duration(milliseconds: 500));
      }
    }
    return [];
  }

  void clearSearch() {
    searchQuery.value = '';
    searchResults.clear();
    errorMessage.value = '';
  }

  String getDockerRunCommand(String imageName, String tag) {
    return 'docker run --rm -it $imageName:$tag';
  }

  String getDockerPullCommand(String imageName, String tag) {
    return 'docker pull $imageName:$tag';
  }
}