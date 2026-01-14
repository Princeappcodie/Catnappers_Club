import 'dart:io';
import 'package:dio/dio.dart';
import 'package:path_provider/path_provider.dart';
import 'package:flutter/foundation.dart';

class TempCacheService {
  static const String _cacheDirName = 'temp_media_cache';

  /// Get the directory for temporary media cache
  static Future<Directory> _getCacheDirectory() async {
    final tempDir = await getTemporaryDirectory();
    final cacheDir = Directory('${tempDir.path}/$_cacheDirName');
    if (!await cacheDir.exists()) {
      await cacheDir.create(recursive: true);
    }
    return cacheDir;
  }

  /// Clears the entire temporary media cache.
  /// Should be called on app startup.
  static Future<void> clearCache() async {
    try {
      final tempDir = await getTemporaryDirectory();
      final cacheDir = Directory('${tempDir.path}/$_cacheDirName');
      if (await cacheDir.exists()) {
        await cacheDir.delete(recursive: true);
        debugPrint('🧹 Temp cache cleared successfully.');
      }
    } catch (e) {
      debugPrint('❌ Error clearing temp cache: $e');
    }
  }

  /// Downloads a file from [url] to the cache directory and returns the local file path.
  /// If the file already exists in cache, returns the path immediately.
  static Future<String> getCachedFilePath(String url) async {
    try {
      if (url.isEmpty) throw Exception("Empty URL");

      // Generate a safe filename from the URL
      final filename = _generateFileName(url);
      final cacheDir = await _getCacheDirectory();
      final file = File('${cacheDir.path}/$filename');

      if (await file.exists()) {
        debugPrint('✅ File found in cache: ${file.path}');
        return file.path;
      }

      debugPrint('⬇️ Downloading to cache: $url');
      final dio = Dio();
      await dio.download(url, file.path);
      
      debugPrint('✅ Download complete: ${file.path}');
      return file.path;
    } catch (e) {
      debugPrint('❌ Cache download failed: $e');
      // If download fails, return the original URL to allow streaming fallback
      return url;
    }
  }

  static String _generateFileName(String url) {
    // Simple hash-based filename or just sanitized string
    return url.hashCode.toString() + '_' + url.split('/').last.split('?').first;
  }
}
