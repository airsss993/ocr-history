import 'dart:typed_data';

import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';

import '../services/ocr_service.dart';
import '../widgets/image_grid_item.dart';
import '../widgets/loading_overlay.dart';
import 'history_screen.dart';
import 'ocr_result_screen.dart';

class SelectedImage {
  final Uint8List bytes;
  final String filename;

  SelectedImage({required this.bytes, required this.filename});
}

class PhotoPickerScreen extends StatefulWidget {
  const PhotoPickerScreen({super.key});

  @override
  State<PhotoPickerScreen> createState() => _PhotoPickerScreenState();
}

class _PhotoPickerScreenState extends State<PhotoPickerScreen> {
  static const int _maxImages = 10;
  final List<SelectedImage> _images = [];
  final ImagePicker _picker = ImagePicker();
  final OcrService _ocrService = OcrService();
  bool _isLoading = false;

  Future<void> _pickFromGallery() async {
    final int remainingSlots = _maxImages - _images.length;
    if (remainingSlots <= 0) {
      _showLimitReachedMessage();
      return;
    }

    final List<XFile> pickedFiles = await _picker.pickMultiImage();
    if (pickedFiles.isNotEmpty) {
      final filesToAdd = pickedFiles.take(remainingSlots).toList();
      final newImages = <SelectedImage>[];

      for (final xFile in filesToAdd) {
        final bytes = await xFile.readAsBytes();
        newImages.add(SelectedImage(bytes: bytes, filename: xFile.name));
      }

      setState(() {
        _images.addAll(newImages);
      });
    }
  }

  Future<void> _takePhoto() async {
    if (_images.length >= _maxImages) {
      _showLimitReachedMessage();
      return;
    }

    final XFile? photo = await _picker.pickImage(source: ImageSource.camera);
    if (photo != null) {
      final bytes = await photo.readAsBytes();
      setState(() {
        _images.add(SelectedImage(bytes: bytes, filename: photo.name));
      });
    }
  }

  void _removeImage(int index) {
    setState(() {
      _images.removeAt(index);
    });
  }

  void _showLimitReachedMessage() {
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text('Достигнут лимит в 10 фотографий'),
        duration: Duration(seconds: 2),
      ),
    );
  }

  Future<void> _recognizeImages() async {
    if (_images.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Сначала выберите фотографии')),
      );
      return;
    }

    setState(() => _isLoading = true);

    try {
      final imageDataList = _images
          .map((img) => ImageData(bytes: img.bytes, filename: img.filename))
          .toList();

      final response = await _ocrService.recognizeImages(imageDataList);

      if (mounted) {
        final imagesWithResults = <ImageWithResult>[];

        for (var i = 0; i < _images.length; i++) {
          final result = i < response.results.length
              ? response.results[i]
              : null;
          imagesWithResults.add(
            ImageWithResult(
              bytes: _images[i].bytes,
              filename: _images[i].filename,
              result: result,
            ),
          );
        }

        Navigator.push(
          context,
          MaterialPageRoute(
            builder: (context) => OcrResultScreen(images: imagesWithResults),
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('Ошибка: ${e.toString()}')));
      }
    } finally {
      if (mounted) {
        setState(() => _isLoading = false);
      }
    }
  }

  void _openHistory() {
    Navigator.push(
      context,
      MaterialPageRoute(builder: (context) => const HistoryScreen()),
    );
  }

  @override
  Widget build(BuildContext context) {
    return LoadingOverlay(
      isLoading: _isLoading,
      message: 'Распознавание текста...',
      child: Scaffold(
        appBar: AppBar(
          title: const Text('OCR Hist'),
          actions: [
            IconButton(
              icon: const Icon(Icons.history),
              tooltip: 'История',
              onPressed: _openHistory,
            ),
          ],
        ),
        body: SafeArea(
          child: Column(
            children: [
              Expanded(
                child: _images.isEmpty
                    ? const Center(
                        child: Text(
                          'Нет выбранных фотографий',
                          style: TextStyle(fontSize: 16, color: Colors.grey),
                        ),
                      )
                    : Padding(
                        padding: const EdgeInsets.all(16),
                        child: GridView.builder(
                          gridDelegate:
                              const SliverGridDelegateWithFixedCrossAxisCount(
                                crossAxisCount: 3,
                                crossAxisSpacing: 8,
                                mainAxisSpacing: 8,
                              ),
                          itemCount: _images.length,
                          itemBuilder: (context, index) {
                            return ImageGridItem(
                              imageBytes: _images[index].bytes,
                              onRemove: () => _removeImage(index),
                            );
                          },
                        ),
                      ),
              ),
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16),
                child: Text(
                  'Выбрано: ${_images.length}/$_maxImages',
                  style: const TextStyle(fontSize: 14, color: Colors.grey),
                ),
              ),
              const SizedBox(height: 16),
              if (_images.isNotEmpty)
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 16),
                  child: SizedBox(
                    width: double.infinity,
                    child: ElevatedButton(
                      onPressed: _recognizeImages,
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.green,
                      ),
                      child: const Text('Распознать'),
                    ),
                  ),
                ),
              if (_images.isNotEmpty) const SizedBox(height: 12),
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16),
                child: SizedBox(
                  width: double.infinity,
                  child: ElevatedButton(
                    onPressed: _pickFromGallery,
                    child: const Text('Выбрать из галереи'),
                  ),
                ),
              ),
              if (!kIsWeb) ...[
                const SizedBox(height: 12),
                Padding(
                  padding: const EdgeInsets.fromLTRB(16, 0, 16, 24),
                  child: SizedBox(
                    width: double.infinity,
                    child: ElevatedButton(
                      onPressed: _takePhoto,
                      child: const Text('Сделать фото'),
                    ),
                  ),
                ),
              ] else
                const SizedBox(height: 24),
            ],
          ),
        ),
      ),
    );
  }
}
