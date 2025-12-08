import 'dart:typed_data';

import 'package:flutter/material.dart';

import '../models/ocr_result.dart';
import '../services/history_service.dart';
import '../widgets/image_with_overlay.dart';
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
  bool _showWords = true;
  bool _showLines = false;

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

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(
          widget.images.length > 1
              ? 'Результат (${_currentPage + 1}/${widget.images.length})'
              : 'Результат',
        ),
        actions: [
          PopupMenuButton<String>(
            icon: const Icon(Icons.visibility),
            tooltip: 'Отображение',
            onSelected: (value) {
              setState(() {
                if (value == 'words') {
                  _showWords = !_showWords;
                } else if (value == 'lines') {
                  _showLines = !_showLines;
                }
              });
            },
            itemBuilder: (context) => [
              CheckedPopupMenuItem(
                value: 'words',
                checked: _showWords,
                child: const Text('Показать слова'),
              ),
              CheckedPopupMenuItem(
                value: 'lines',
                checked: _showLines,
                child: const Text('Показать строки'),
              ),
            ],
          ),
        ],
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
                if (result?.textAnnotation != null)
                  ImageWithOverlay(
                    imageBytes: image.bytes,
                    textAnnotation: result!.textAnnotation!,
                    showWords: _showWords,
                    showLines: _showLines,
                  )
                else
                  Image.memory(image.bytes, fit: BoxFit.contain),
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
