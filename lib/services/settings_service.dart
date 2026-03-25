import 'package:shared_preferences/shared_preferences.dart';
import '../models/reading_mode.dart';

class SettingsService {
  static const _readingModeKey = 'reading_mode';
  static const _lastPagePrefix = 'last_page_';

  static Future<ReadingMode> getReadingMode() async {
    final prefs = await SharedPreferences.getInstance();
    final value = prefs.getString(_readingModeKey) ?? ReadingMode.light.key;
    return ReadingMode.values.firstWhere(
      (m) => m.key == value,
      orElse: () => ReadingMode.light,
    );
  }

  static Future<void> setReadingMode(ReadingMode mode) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_readingModeKey, mode.key);
  }

  static Future<int> getLastPage(String fileId) async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getInt('$_lastPagePrefix$fileId') ?? 0;
  }

  static Future<void> setLastPage(String fileId, int page) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setInt('$_lastPagePrefix$fileId', page);
  }
}
