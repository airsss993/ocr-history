import 'dart:io';

import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';

import '../widgets/image_grid_item.dart';

class PhotoPickerScreen extends StatefulWidget {
  const PhotoPickerScreen({super.key});

  @override
  State<PhotoPickerScreen> createState() => _PhotoPickerScreenState();
}

class _PhotoPickerScreenState extends State<PhotoPickerScreen> {
  static const int _maxImages = 10;
  final List<File> _images = [];
  final ImagePicker _picker = ImagePicker();

  Future<void> _pickFromGallery() async {
    final int remainingSlots = _maxImages - _images.length;
    if (remainingSlots <= 0) {
      _showLimitReachedMessage();
      return;
    }

    final List<XFile> pickedFiles = await _picker.pickMultiImage();
    if (pickedFiles.isNotEmpty) {
      setState(() {
        final filesToAdd = pickedFiles.take(remainingSlots);
        _images.addAll(filesToAdd.map((xFile) => File(xFile.path)));
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
      setState(() {
        _images.add(File(photo.path));
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

  @override
  Widget build(BuildContext context) {
    return Scaffold(
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
                            imageFile: _images[index],
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
          ],
        ),
      ),
    );
  }
}
