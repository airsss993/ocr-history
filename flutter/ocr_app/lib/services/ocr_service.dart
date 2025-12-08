import 'dart:convert';
import 'dart:typed_data';

import 'package:http/http.dart' as http;

import '../config/app_config.dart';
import '../models/ocr_result.dart';
import 'settings_service.dart';

class OcrException implements Exception {
  final String message;
  final int? statusCode;

  OcrException(this.message, {this.statusCode});

  @override
  String toString() => message;
}

class ImageData {
  final Uint8List bytes;
  final String filename;

  ImageData({required this.bytes, required this.filename});
}

class OcrService {
  Future<OcrApiResponse> recognizeImages(
    List<ImageData> images, {
    OcrProvider provider = OcrProvider.yandex,
    String? geminiApiKey,
  }) async {
    final endpoint = provider == OcrProvider.gemini
        ? AppConfig.ocrGeminiEndpoint
        : AppConfig.ocrYandexEndpoint;

    final uri = Uri.parse(endpoint);
    final request = http.MultipartRequest('POST', uri);

    if (provider == OcrProvider.gemini) {
      if (geminiApiKey == null || geminiApiKey.isEmpty) {
        throw OcrException('Gemini API ключ не указан');
      }
      request.headers['X-Gemini-API-Key'] = geminiApiKey;
    }

    for (final image in images) {
      final file = http.MultipartFile.fromBytes(
        'images',
        image.bytes,
        filename: image.filename,
      );
      request.files.add(file);
    }

    final http.StreamedResponse streamedResponse;
    try {
      streamedResponse = await request.send();
    } catch (e) {
      throw OcrException('Не удалось подключиться к серверу');
    }

    final response = await http.Response.fromStream(streamedResponse);

    if (response.statusCode == 200) {
      final json = jsonDecode(response.body) as Map<String, dynamic>;
      return OcrApiResponse.fromJson(json);
    } else if (response.statusCode == 401) {
      throw OcrException('Неверный API ключ', statusCode: response.statusCode);
    } else {
      try {
        final json = jsonDecode(response.body) as Map<String, dynamic>;
        throw OcrException(
          json['message'] as String? ?? 'Ошибка сервера',
          statusCode: response.statusCode,
        );
      } catch (e) {
        if (e is OcrException) rethrow;
        throw OcrException(
          'Ошибка сервера: ${response.statusCode}',
          statusCode: response.statusCode,
        );
      }
    }
  }
}
