import 'dart:convert';
import 'dart:typed_data';

import 'package:http/http.dart' as http;

import '../config/app_config.dart';
import '../models/ocr_result.dart';

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
  Future<OcrApiResponse> recognizeImages(List<ImageData> images) async {
    final uri = Uri.parse(AppConfig.ocrYandexEndpoint);
    final request = http.MultipartRequest('POST', uri);

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
