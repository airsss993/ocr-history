import 'dart:convert';
import 'dart:typed_data';

import 'ocr_result.dart';

class HistoryEntry {
  final String id;
  final String imageBase64;
  final OcrImageResult ocrResult;
  final DateTime createdAt;

  HistoryEntry({
    required this.id,
    required this.imageBase64,
    required this.ocrResult,
    required this.createdAt,
  });

  Uint8List get imageBytes => base64Decode(imageBase64);

  factory HistoryEntry.fromJson(Map<String, dynamic> json) {
    return HistoryEntry(
      id: json['id'] as String,
      imageBase64: json['imageBase64'] as String,
      ocrResult: OcrImageResult.fromJson(
        json['ocrResult'] as Map<String, dynamic>,
      ),
      createdAt: DateTime.parse(json['createdAt'] as String),
    );
  }

  Map<String, dynamic> toJson() => {
    'id': id,
    'imageBase64': imageBase64,
    'ocrResult': ocrResult.toJson(),
    'createdAt': createdAt.toIso8601String(),
  };
}
