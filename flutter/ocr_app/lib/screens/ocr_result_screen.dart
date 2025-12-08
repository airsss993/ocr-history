import 'dart:typed_data';

import 'package:flutter/material.dart';

import '../models/ocr_result.dart';
import '../services/history_service.dart';
import '../widgets/image_viewer_dialog.dart';
import '../widgets/ocr_text_display.dart';

class ImageWithResult {
  final Uint8List bytes;
  final String filename;
  final OcrImageResult? result;

  ImageWithResult({required this.bytes, required this.filename, this.result});
}

class OcrResultScreen extends StatefulWidget {
  final List<ImageWithResult> images;

  const OcrResultScreen({super.key, required this.images});

  @override
  State<OcrResultScreen> createState() => _OcrResultScreenState();
}

class _OcrResultScreenState extends State<OcrResultScreen> {
  final PageController _pageController = PageController();
  final HistoryService _historyService = HistoryService();
  int _currentPage = 0;

  @override
  void initState() {
    super.initState();
    _saveToHistory();
  }

  Future<void> _saveToHistory() async {
    for (final image in widget.images) {
      if (image.result != null && image.result!.isSuccess) {
        await _historyService.addEntry(
          imageBytes: image.bytes,
          ocrResult: image.result!,
        );
      }
    }
  }

  void _openImageViewer(Uint8List bytes, OcrTextAnnotation textAnnotation) {
    ImageViewerDialog.show(
      context,
      imageBytes: bytes,
      textAnnotation: textAnnotation,
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(
          widget.images.length > 1
              ? 'Результат (${_currentPage + 1}/${widget.images.length})'
              : 'Результат',
        ),
      ),
      body: PageView.builder(
        controller: _pageController,
        itemCount: widget.images.length,
        onPageChanged: (index) {
          setState(() => _currentPage = index);
        },
        itemBuilder: (context, index) {
          final image = widget.images[index];
          final result = image.result;

          return SingleChildScrollView(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                _buildImagePreview(image.bytes, result?.textAnnotation),
                const SizedBox(height: 24),
                if (result?.textAnnotation != null)
                  OcrTextDisplay(textAnnotation: result!.textAnnotation!)
                else if (result?.error != null)
                  _buildErrorWidget(result!.error!)
                else
                  const Text(
                    'Текст не распознан',
                    style: TextStyle(color: Colors.grey),
                  ),
              ],
            ),
          );
        },
      ),
      bottomNavigationBar: widget.images.length > 1
          ? SafeArea(
              child: Padding(
                padding: const EdgeInsets.all(8),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: List.generate(
                    widget.images.length,
                    (index) => Container(
                      width: 8,
                      height: 8,
                      margin: const EdgeInsets.symmetric(horizontal: 4),
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        color: index == _currentPage
                            ? Theme.of(context).primaryColor
                            : Colors.grey.shade300,
                      ),
                    ),
                  ),
                ),
              ),
            )
          : null,
    );
  }

  Widget _buildImagePreview(
    Uint8List bytes,
    OcrTextAnnotation? textAnnotation,
  ) {
    return GestureDetector(
      onTap: textAnnotation != null
          ? () => _openImageViewer(bytes, textAnnotation)
          : null,
      child: Container(
        constraints: const BoxConstraints(maxHeight: 250),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: Colors.grey.shade300, width: 2),
        ),
        child: ClipRRect(
          borderRadius: BorderRadius.circular(10),
          child: Stack(
            alignment: Alignment.center,
            children: [
              Image.memory(bytes, fit: BoxFit.contain),
              if (textAnnotation != null)
                Positioned(
                  right: 8,
                  bottom: 8,
                  child: Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 12,
                      vertical: 6,
                    ),
                    decoration: BoxDecoration(
                      color: Colors.black54,
                      borderRadius: BorderRadius.circular(20),
                    ),
                    child: const Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(Icons.fullscreen, color: Colors.white, size: 18),
                        SizedBox(width: 4),
                        Text(
                          'Открыть',
                          style: TextStyle(color: Colors.white, fontSize: 12),
                        ),
                      ],
                    ),
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildErrorWidget(String error) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.red.shade50,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: Colors.red.shade200),
      ),
      child: Row(
        children: [
          Icon(Icons.error_outline, color: Colors.red.shade700),
          const SizedBox(width: 12),
          Expanded(
            child: Text(
              'Ошибка: $error',
              style: TextStyle(color: Colors.red.shade700),
            ),
          ),
        ],
      ),
    );
  }

  @override
  void dispose() {
    _pageController.dispose();
    super.dispose();
  }
}
