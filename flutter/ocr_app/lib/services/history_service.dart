import 'dart:convert';
import 'dart:typed_data';

import 'package:shared_preferences/shared_preferences.dart';

import '../models/history_entry.dart';
import '../models/ocr_result.dart';

class HistoryService {
  static const _historyKey = 'ocr_history';

  SharedPreferences? _prefs;

  Future<SharedPreferences> get _preferences async {
    _prefs ??= await SharedPreferences.getInstance();
    return _prefs!;
  }

  Future<List<HistoryEntry>> getHistory() async {
    final prefs = await _preferences;
    final jsonString = prefs.getString(_historyKey);

    if (jsonString == null || jsonString.isEmpty) {
      return [];
    }

    final jsonList = jsonDecode(jsonString) as List<dynamic>;
    return jsonList
        .map((e) => HistoryEntry.fromJson(e as Map<String, dynamic>))
        .toList()
      ..sort((a, b) => b.createdAt.compareTo(a.createdAt));
  }

  Future<HistoryEntry> addEntry({
    required Uint8List imageBytes,
    required OcrImageResult ocrResult,
  }) async {
    final timestamp = DateTime.now().millisecondsSinceEpoch;
    final imageBase64 = base64Encode(imageBytes);

    final entry = HistoryEntry(
      id: timestamp.toString(),
      imageBase64: imageBase64,
      ocrResult: ocrResult,
      createdAt: DateTime.now(),
    );

    final history = await getHistory();
    history.insert(0, entry);

    final prefs = await _preferences;
    final jsonString = jsonEncode(history.map((e) => e.toJson()).toList());
    await prefs.setString(_historyKey, jsonString);

    return entry;
  }

  Future<void> deleteEntry(String id) async {
    final history = await getHistory();
    history.removeWhere((e) => e.id == id);

    final prefs = await _preferences;
    final jsonString = jsonEncode(history.map((e) => e.toJson()).toList());
    await prefs.setString(_historyKey, jsonString);
  }

  Future<void> clearHistory() async {
    final prefs = await _preferences;
    await prefs.remove(_historyKey);
  }
}
