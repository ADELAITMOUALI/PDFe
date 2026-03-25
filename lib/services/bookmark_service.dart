import 'dart:convert';
import 'package:shared_preferences/shared_preferences.dart';
import '../models/bookmark.dart';

class BookmarkService {
  static String _key(String fileId) => 'bookmarks_$fileId';

  static Future<List<Bookmark>> getBookmarks(String fileId) async {
    final prefs = await SharedPreferences.getInstance();
    final jsonList = prefs.getStringList(_key(fileId)) ?? [];
    return jsonList.map((j) {
      try {
        return Bookmark.fromMap(jsonDecode(j) as Map<String, dynamic>);
      } catch (_) {
        return null;
      }
    }).whereType<Bookmark>().toList()
      ..sort((a, b) => a.page.compareTo(b.page));
  }

  static Future<void> addBookmark(Bookmark bookmark) async {
    final prefs = await SharedPreferences.getInstance();
    final existing = await getBookmarks(bookmark.fileId);
    // Remove duplicate page
    final filtered = existing.where((b) => b.page != bookmark.page).toList();
    filtered.add(bookmark);
    filtered.sort((a, b) => a.page.compareTo(b.page));
    final jsonList = filtered.map((b) => jsonEncode(b.toMap())).toList();
    await prefs.setStringList(_key(bookmark.fileId), jsonList);
  }

  static Future<void> removeBookmark(String fileId, int page) async {
    final prefs = await SharedPreferences.getInstance();
    final existing = await getBookmarks(fileId);
    final filtered = existing.where((b) => b.page != page).toList();
    final jsonList = filtered.map((b) => jsonEncode(b.toMap())).toList();
    await prefs.setStringList(_key(fileId), jsonList);
  }

  static Future<bool> isBookmarked(String fileId, int page) async {
    final bookmarks = await getBookmarks(fileId);
    return bookmarks.any((b) => b.page == page);
  }

  static Future<void> clearBookmarks(String fileId) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(_key(fileId));
  }
}
