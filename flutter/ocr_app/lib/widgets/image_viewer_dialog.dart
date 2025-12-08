import 'dart:typed_data';

import 'package:flutter/material.dart';

import '../models/ocr_result.dart';
import 'image_with_overlay.dart';

class ImageViewerDialog extends StatelessWidget {
  final Uint8List imageBytes;
  final OcrTextAnnotation textAnnotation;

  const ImageViewerDialog({
    super.key,
    required this.imageBytes,
    required this.textAnnotation,
  });

  static Future<void> show(
    BuildContext context, {
    required Uint8List imageBytes,
    required OcrTextAnnotation textAnnotation,
  }) {
    return showDialog(
      context: context,
      barrierColor: Colors.black87,
      builder: (context) => ImageViewerDialog(
        imageBytes: imageBytes,
        textAnnotation: textAnnotation,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Dialog(
      backgroundColor: Colors.transparent,
      insetPadding: EdgeInsets.zero,
      child: Stack(
        fit: StackFit.expand,
        children: [
          GestureDetector(
            onTap: () => Navigator.of(context).pop(),
            child: Container(color: Colors.transparent),
          ),
          Center(
            child: InteractiveViewer(
              minScale: 0.5,
              maxScale: 4.0,
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: ImageWithOverlay(
                  imageBytes: imageBytes,
                  textAnnotation: textAnnotation,
                  showWords: true,
                  showLines: false,
                  enableWordTap: true,
                ),
              ),
            ),
          ),
          Positioned(
            top: 16,
            right: 16,
            child: SafeArea(
              child: IconButton(
                onPressed: () => Navigator.of(context).pop(),
                icon: const Icon(Icons.close, color: Colors.white, size: 32),
                style: IconButton.styleFrom(backgroundColor: Colors.black54),
              ),
            ),
          ),
          Positioned(
            bottom: 16,
            left: 0,
            right: 0,
            child: SafeArea(
              child: Center(
                child: Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 16,
                    vertical: 8,
                  ),
                  decoration: BoxDecoration(
                    color: Colors.black54,
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: const Text(
                    'Нажмите на слово для просмотра',
                    style: TextStyle(color: Colors.white70, fontSize: 12),
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
