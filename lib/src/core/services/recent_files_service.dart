import 'package:shared_preferences/shared_preferences.dart';
import '../models/pdf_item.dart';

class RecentFilesService {
  static const String _keyRecentFiles = 'koto_recent_pdf_files';
  static const int _maxRecentFiles = 25;

  static Future<List<PdfItem>> getRecentFiles() async {
    final prefs = await SharedPreferences.getInstance();
    final List<String>? jsonList = prefs.getStringList(_keyRecentFiles);

    if (jsonList == null) return [];

    return jsonList
        .map((item) => PdfItem.fromJson(item))
        .toList()
      ..sort((a, b) => b.lastOpened.compareTo(a.lastOpened));
  }

  static Future<void> addRecentFile(PdfItem newItem) async {
    final prefs = await SharedPreferences.getInstance();
    List<PdfItem> currentList = await getRecentFiles();

    // Remove if duplicate path exists
    currentList.removeWhere((item) => item.path == newItem.path);

    // Insert at beginning
    currentList.insert(0, newItem);

    // Limit list size
    if (currentList.length > _maxRecentFiles) {
      currentList = currentList.sublist(0, _maxRecentFiles);
    }

    final jsonList = currentList.map((item) => item.toJson()).toList();
    await prefs.setStringList(_keyRecentFiles, jsonList);
  }

  static Future<void> removeRecentFile(String path) async {
    final prefs = await SharedPreferences.getInstance();
    List<PdfItem> currentList = await getRecentFiles();

    currentList.removeWhere((item) => item.path == path);

    final jsonList = currentList.map((item) => item.toJson()).toList();
    await prefs.setStringList(_keyRecentFiles, jsonList);
  }

  static Future<void> clearAll() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(_keyRecentFiles);
  }
}
