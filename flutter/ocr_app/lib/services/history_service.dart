import 'dart:convert';
import 'dart:math';
import 'dart:typed_data';

import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';

import '../config/app_config.dart';
import '../models/history_entry.dart';
import '../models/ocr_result.dart';

class HistoryService {
  static const _clientIdKey = 'client_id';

  String? _clientId;

  Future<String> _getClientId() async {
    if (_clientId != null) return _clientId!;

    final prefs = await SharedPreferences.getInstance();
    _clientId = prefs.getString(_clientIdKey);

    if (_clientId == null) {
      _clientId = _generateUuid();
      await prefs.setString(_clientIdKey, _clientId!);
    }

    return _clientId!;
  }

  String _generateUuid() {
    final random = Random.secure();
    final bytes = List<int>.generate(16, (_) => random.nextInt(256));
    bytes[6] = (bytes[6] & 0x0f) | 0x40;
    bytes[8] = (bytes[8] & 0x3f) | 0x80;

    final hex = bytes.map((b) => b.toRadixString(16).padLeft(2, '0')).join();
    return '${hex.substring(0, 8)}-${hex.substring(8, 12)}-'
        '${hex.substring(12, 16)}-${hex.substring(16, 20)}-${hex.substring(20)}';
  }

  Future<List<HistoryEntry>> getHistory() async {
    final clientId = await _getClientId();

    try {
      final response = await http.get(
        Uri.parse(AppConfig.historyEndpoint),
        headers: {'X-Client-ID': clientId},
      );

      if (response.statusCode == 200) {
        final json = jsonDecode(response.body) as Map<String, dynamic>;
        final entries = json['entries'] as List<dynamic>? ?? [];
        return entries
            .map((e) => HistoryEntry.fromJson(e as Map<String, dynamic>))
            .toList();
      }
    } catch (e) {
      // Return empty list on error
    }

    return [];
  }

  Future<HistoryEntry?> addEntry({
    required Uint8List imageBytes,
    required OcrImageResult ocrResult,
  }) async {
    final clientId = await _getClientId();
    final imageBase64 = base64Encode(imageBytes);

    try {
      final response = await http.post(
        Uri.parse(AppConfig.historyEndpoint),
        headers: {'X-Client-ID': clientId, 'Content-Type': 'application/json'},
        body: jsonEncode({
          'imageBase64': imageBase64,
          'ocrResult': ocrResult.toJson(),
        }),
      );

      if (response.statusCode == 200) {
        final json = jsonDecode(response.body) as Map<String, dynamic>;
        final entry = json['entry'] as Map<String, dynamic>?;
        if (entry != null) {
          return HistoryEntry.fromJson(entry);
        }
      }
    } catch (e) {
      // Ignore errors
    }

    return null;
  }

  Future<void> deleteEntry(String id) async {
    final clientId = await _getClientId();

    try {
      await http.delete(
        Uri.parse('${AppConfig.historyEndpoint}/$id'),
        headers: {'X-Client-ID': clientId},
      );
    } catch (e) {
      // Ignore errors
    }
  }

  Future<void> clearHistory() async {
    final clientId = await _getClientId();

    try {
      await http.delete(
        Uri.parse(AppConfig.historyEndpoint),
        headers: {'X-Client-ID': clientId},
      );
    } catch (e) {
      // Ignore errors
    }
  }
}
