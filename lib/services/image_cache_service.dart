import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import 'package:path_provider/path_provider.dart';
import 'package:path/path.dart' as p;

class ImageCacheService {
  static Directory? _cacheDir;
  static final Map<String, File> _memoryCache = {};

  /// Fast synchronous in-memory lookup to prevent async flickering
  static File? getMemoryCachedFile(String url) {
    return _memoryCache[url];
  }

  static Future<Directory?> get _directory async {
    if (_cacheDir != null) return _cacheDir;
    if (kIsWeb) return null;
    try {
      final appDocDir = await getApplicationDocumentsDirectory();
      final dir = Directory(p.join(appDocDir.path, 'product_image_cache'));
      if (!await dir.exists()) {
        await dir.create(recursive: true);
      }
      _cacheDir = dir;
      return _cacheDir;
    } catch (_) {
      return null;
    }
  }

  static String _generateFileName(String url) {
    final uri = Uri.parse(url);
    final rawName = p.basename(uri.path);
    final sanitizeUrl = url.replaceAll(RegExp(r'[^a-zA-Z0-9]'), '_');
    final hash = sanitizeUrl.length > 50 ? sanitizeUrl.substring(sanitizeUrl.length - 50) : sanitizeUrl;
    if (rawName.contains('.')) {
      final ext = p.extension(rawName);
      return 'img_$hash$ext';
    }
    return 'img_$hash.jpg';
  }

  static Future<File?> getCachedImageFile(String url) async {
    if (kIsWeb || !url.startsWith('http')) return null;
    if (_memoryCache.containsKey(url)) {
      return _memoryCache[url];
    }
    try {
      final dir = await _directory;
      if (dir == null) return null;
      final fileName = _generateFileName(url);
      final file = File(p.join(dir.path, fileName));
      if (await file.exists() && (await file.length()) > 0) {
        _memoryCache[url] = file;
        return file;
      }
    } catch (_) {}
    return null;
  }

  static Future<File?> downloadAndCacheImage(String url) async {
    if (kIsWeb || !url.startsWith('http')) return null;
    if (_memoryCache.containsKey(url)) {
      return _memoryCache[url];
    }
    try {
      final dir = await _directory;
      if (dir == null) return null;
      final fileName = _generateFileName(url);
      final file = File(p.join(dir.path, fileName));

      final response = await http.get(Uri.parse(url)).timeout(const Duration(seconds: 15));
      if (response.statusCode == 200 && response.bodyBytes.isNotEmpty) {
        await file.writeAsBytes(response.bodyBytes);
        _memoryCache[url] = file;
        return file;
      }
    } catch (_) {}
    return null;
  }
}
