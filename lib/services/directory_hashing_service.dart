import 'dart:io';
import 'dart:convert';
import 'package:crypto/crypto.dart';
import 'package:path/path.dart' as p;

/// Service to calculate a stable MD5 hash of a directory's contents.
class DirectoryHashingService {
  /// File name used to cache the hash within the directory.
  static const String hashFileName = '.ricochet_hash';

  /// Calculates a recursive MD5 hash of all files in [directory].
  /// 
  /// The hash is stable because it sorts files by path and includes both
  /// the relative path and the file content in the digest.
  Future<String> calculateDirectoryHash(Directory directory, {String hashFileName = DirectoryHashingService.hashFileName}) async {
    if (!await directory.exists()) return '';

    final files = await directory
        .list(recursive: true)
        .where((entity) => entity is File && !entity.path.endsWith(hashFileName))
        .cast<File>()
        .toList();

    // Sort files by relative path to ensure deterministic hashing
    files.sort((a, b) => a.path.compareTo(b.path));

    final hashInput = _DigestSink();
    final md5Sink = md5.startChunkedConversion(hashInput);

    for (final file in files) {
      final relativePath = p.relative(file.path, from: directory.path);
      
      // Hash the path first
      md5Sink.add(utf8.encode(relativePath));
      
      // Then stream the file content to handle large files efficiently
      final stream = file.openRead();
      await for (final chunk in stream) {
        md5Sink.add(chunk);
      }
    }

    md5Sink.close();
    return hashInput.value.toString();
  }

  /// Saves [hash] into a [hashFileName] file inside [directory].
  Future<void> writeHashFile(Directory directory, String hash, {String hashFileName = DirectoryHashingService.hashFileName}) async {
    final hashFile = File(p.join(directory.path, hashFileName));
    await hashFile.writeAsString(hash);
  }

  /// Reads the cached hash from [hashFileName] inside [directory].
  /// Returns null if the file doesn't exist.
  Future<String?> readHashFile(Directory directory, {String hashFileName = DirectoryHashingService.hashFileName}) async {
    final hashFile = File(p.join(directory.path, hashFileName));
    if (await hashFile.exists()) {
      return await hashFile.readAsString();
    }
    return null;
  }
}

class _DigestSink implements Sink<Digest> {
  late Digest value;
  @override
  void add(Digest data) => value = data;
  @override
  void close() {}
}
