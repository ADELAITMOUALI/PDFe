import 'dart:convert';
import 'dart:io';
import 'package:shared_preferences/shared_preferences.dart';
import '../models/pdf_file.dart';

class FileService {
  static const _recentKey = 'recent_pdfs';
  static const _maxRecent = 20;

  static Future<List<PdfFile>> getRecentFiles() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final jsonList = prefs.getStringList(_recentKey) ?? [];
      final files = <PdfFile>[];
      for (final json in jsonList) {
        try {
          final map = jsonDecode(json) as Map<String, dynamic>;
          final file = PdfFile.fromMap(map);
          // Only include files that still exist
          if (File(file.path).existsSync()) {
            files.add(file);
          }
        } catch (_) {}
      }
      files.sort((a, b) => b.openedAt.compareTo(a.openedAt));
      return files;
    } catch (_) {
      return [];
    }
  }

  static Future<void> addRecentFile(PdfFile file) async {
    final prefs = await SharedPreferences.getInstance();
    final existing = await getRecentFiles();
    // Remove duplicate path
    final filtered = existing.where((f) => f.path != file.path).toList();
    filtered.insert(0, file);
    final trimmed = filtered.take(_maxRecent).toList();
    final jsonList = trimmed.map((f) => jsonEncode(f.toMap())).toList();
    await prefs.setStringList(_recentKey, jsonList);
  }

  static Future<void> removeRecentFile(String id) async {
    final prefs = await SharedPreferences.getInstance();
    final existing = await getRecentFiles();
    final filtered = existing.where((f) => f.id != id).toList();
    final jsonList = filtered.map((f) => jsonEncode(f.toMap())).toList();
    await prefs.setStringList(_recentKey, jsonList);
  }

  static Future<void> clearRecentFiles() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(_recentKey);
  }

  static int getTotalSize(List<PdfFile> files) {
    return files.fold(0, (sum, f) => sum + f.sizeBytes);
  }

  static String formatTotalSize(int bytes) {
    if (bytes >= 1024 * 1024) {
      return '${(bytes / (1024 * 1024)).toStringAsFixed(1)} MB';
    } else if (bytes >= 1024) {
      return '${(bytes / 1024).toStringAsFixed(1)} KB';
    }
    return '$bytes B';
  }
}
