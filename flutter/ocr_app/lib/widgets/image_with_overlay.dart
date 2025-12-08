import 'dart:typed_data';
import 'dart:ui' as ui;

import 'package:flutter/material.dart';

import '../models/ocr_result.dart';

class ImageWithOverlay extends StatefulWidget {
  final Uint8List imageBytes;
  final OcrTextAnnotation textAnnotation;
  final bool showWords;
  final bool showLines;
  final bool enableWordTap;

  const ImageWithOverlay({
    super.key,
    required this.imageBytes,
    required this.textAnnotation,
    this.showWords = true,
    this.showLines = false,
    this.enableWordTap = false,
  });

  @override
  State<ImageWithOverlay> createState() => _ImageWithOverlayState();
}

class _SelectedWord {
  final String text;
  final double left;
  final double top;
  final double width;

  _SelectedWord({
    required this.text,
    required this.left,
    required this.top,
    required this.width,
  });
}

class _ImageWithOverlayState extends State<ImageWithOverlay> {
  ui.Image? _decodedImage;
  _SelectedWord? _selectedWord;

  @override
  void initState() {
    super.initState();
    _loadImage();
  }

  @override
  void didUpdateWidget(ImageWithOverlay oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.imageBytes != widget.imageBytes) {
      _loadImage();
      _selectedWord = null;
    }
  }

  Future<void> _loadImage() async {
    final codec = await ui.instantiateImageCodec(widget.imageBytes);
    final frame = await codec.getNextFrame();
    if (mounted) {
      setState(() {
        _decodedImage = frame.image;
      });
    }
  }

  void _onWordTap(String text, double left, double top, double width) {
    setState(() {
      if (_selectedWord?.text == text &&
          _selectedWord?.left == left &&
          _selectedWord?.top == top) {
        _selectedWord = null;
      } else {
        _selectedWord = _SelectedWord(
          text: text,
          left: left,
          top: top,
          width: width,
        );
      }
    });
  }

  void _clearSelection() {
    if (_selectedWord != null) {
      setState(() {
        _selectedWord = null;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final maxWidth = constraints.maxWidth;
        final annotationWidth = widget.textAnnotation.width.toDouble();
        final annotationHeight = widget.textAnnotation.height.toDouble();

        if (annotationWidth == 0 || annotationHeight == 0) {
          return Image.memory(widget.imageBytes, fit: BoxFit.contain);
        }

        final aspectRatio = annotationWidth / annotationHeight;
        final displayHeight = maxWidth / aspectRatio;
        final scaleX = maxWidth / annotationWidth;
        final scaleY = displayHeight / annotationHeight;

        return GestureDetector(
          onTap: _clearSelection,
          child: SizedBox(
            width: maxWidth,
            height: displayHeight,
            child: Stack(
              clipBehavior: Clip.none,
              children: [
                Positioned.fill(
                  child: Image.memory(widget.imageBytes, fit: BoxFit.contain),
                ),
                if (widget.showLines && _decodedImage != null)
                  ...widget.textAnnotation.allLines.map((line) {
                    return _buildBoundingBoxWidget(
                      box: line.boundingBox,
                      text: line.text,
                      scaleX: scaleX,
                      scaleY: scaleY,
                      color: Colors.green,
                      borderWidth: 2.0,
                    );
                  }),
                if (widget.showWords && _decodedImage != null)
                  ...widget.textAnnotation.allWords.map((word) {
                    return _buildBoundingBoxWidget(
                      box: word.boundingBox,
                      text: word.text,
                      scaleX: scaleX,
                      scaleY: scaleY,
                      color: Colors.blue,
                      borderWidth: 1.0,
                      isTappable: widget.enableWordTap,
                    );
                  }),
                if (_selectedWord != null)
                  Positioned(
                    left:
                        _selectedWord!.left +
                        (_selectedWord!.width / 2) -
                        _calculateLabelWidth(_selectedWord!.text) / 2,
                    top: _selectedWord!.top - 32,
                    child: _buildWordLabel(_selectedWord!.text),
                  ),
              ],
            ),
          ),
        );
      },
    );
  }

  double _calculateLabelWidth(String text) {
    final textPainter = TextPainter(
      text: TextSpan(text: text, style: const TextStyle(fontSize: 14)),
      textDirection: TextDirection.ltr,
    )..layout();
    return textPainter.width + 24;
  }

  Widget _buildWordLabel(String text) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      decoration: BoxDecoration(
        color: Colors.black87,
        borderRadius: BorderRadius.circular(6),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.3),
            blurRadius: 4,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Text(
        text,
        style: const TextStyle(
          color: Colors.white,
          fontSize: 14,
          fontWeight: FontWeight.w500,
        ),
      ),
    );
  }

  Widget _buildBoundingBoxWidget({
    required OcrBoundingBox box,
    required String text,
    required double scaleX,
    required double scaleY,
    required Color color,
    required double borderWidth,
    bool isTappable = false,
  }) {
    if (box.vertices.length < 4) return const SizedBox.shrink();

    final xs = box.vertices.map((v) => v.x * scaleX).toList();
    final ys = box.vertices.map((v) => v.y * scaleY).toList();

    final minX = xs.reduce((a, b) => a < b ? a : b);
    final maxX = xs.reduce((a, b) => a > b ? a : b);
    final minY = ys.reduce((a, b) => a < b ? a : b);
    final maxY = ys.reduce((a, b) => a > b ? a : b);

    final width = maxX - minX;
    final height = maxY - minY;

    if (width <= 0 || height <= 0) return const SizedBox.shrink();

    final isSelected =
        _selectedWord != null &&
        _selectedWord!.text == text &&
        _selectedWord!.left == minX &&
        _selectedWord!.top == minY;

    final child = Container(
      width: width,
      height: height,
      decoration: BoxDecoration(
        color: isSelected
            ? Colors.blue.withValues(alpha: 0.5)
            : color.withValues(alpha: 0.3),
        border: Border.all(
          color: isSelected ? Colors.blue.shade700 : color,
          width: isSelected ? 2.0 : borderWidth,
        ),
      ),
    );

    return Positioned(
      left: minX,
      top: minY,
      child: isTappable
          ? GestureDetector(
              onTap: () => _onWordTap(text, minX, minY, width),
              child: MouseRegion(
                cursor: SystemMouseCursors.click,
                child: child,
              ),
            )
          : child,
    );
  }
}
