import 'package:shared_preferences/shared_preferences.dart';

enum OcrProvider { yandex, gemini }

class SettingsService {
  static const String _providerKey = 'ocr_provider';
  static const String _geminiApiKeyKey = 'gemini_api_key';

  Future<OcrProvider> getOcrProvider() async {
    final prefs = await SharedPreferences.getInstance();
    final value = prefs.getString(_providerKey);
    if (value == 'gemini') {
      return OcrProvider.gemini;
    }
    return OcrProvider.yandex;
  }

  Future<void> setOcrProvider(OcrProvider provider) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_providerKey, provider.name);
  }

  Future<String?> getGeminiApiKey() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getString(_geminiApiKeyKey);
  }

  Future<void> setGeminiApiKey(String? key) async {
    final prefs = await SharedPreferences.getInstance();
    if (key == null || key.isEmpty) {
      await prefs.remove(_geminiApiKeyKey);
    } else {
      await prefs.setString(_geminiApiKeyKey, key);
    }
  }
}
