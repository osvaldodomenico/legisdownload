import 'dart:convert';
import 'package:shared_preferences/shared_preferences.dart';

class HistoryEntry {
  final String platform;
  final String title;
  final String format;
  final DateTime downloadedAt;

  HistoryEntry({required this.platform, required this.title,
      required this.format, required this.downloadedAt});

  Map<String, dynamic> toJson() => {
        'platform': platform,
        'title': title,
        'format': format,
        'downloadedAt': downloadedAt.toIso8601String(),
      };

  factory HistoryEntry.fromJson(Map<String, dynamic> j) => HistoryEntry(
        platform: j['platform'],
        title: j['title'],
        format: j['format'],
        downloadedAt: DateTime.parse(j['downloadedAt']),
      );
}

class HistoryService {
  static const _key = 'download_history';
  static const _maxEntries = 20;

  static Future<List<HistoryEntry>> load() async {
    final prefs = await SharedPreferences.getInstance();
    final raw = prefs.getStringList(_key) ?? [];
    return raw.map((s) => HistoryEntry.fromJson(jsonDecode(s))).toList();
  }

  static Future<void> add(HistoryEntry entry) async {
    final prefs = await SharedPreferences.getInstance();
    final raw = prefs.getStringList(_key) ?? [];
    raw.insert(0, jsonEncode(entry.toJson()));
    if (raw.length > _maxEntries) raw.removeRange(_maxEntries, raw.length);
    await prefs.setStringList(_key, raw);
  }

  static Future<void> clear() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(_key);
  }
}
