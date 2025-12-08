import 'dart:typed_data';
import 'dart:ui' as ui;

import 'package:flutter/material.dart';

import '../models/ocr_result.dart';

class ImageWithOverlay extends StatefulWidget {
  final Uint8List imageBytes;
  final OcrTextAnnotation textAnnotation;
  final bool showWords;
  final bool showLines;

  const ImageWithOverlay({
    super.key,
    required this.imageBytes,
    required this.textAnnotation,
    this.showWords = true,
    this.showLines = false,
  });

  @override
  State<ImageWithOverlay> createState() => _ImageWithOverlayState();
}

class _ImageWithOverlayState extends State<ImageWithOverlay> {
  ui.Image? _decodedImage;

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

        return SizedBox(
          width: maxWidth,
          height: displayHeight,
          child: Stack(
            children: [
              Positioned.fill(
                child: Image.memory(widget.imageBytes, fit: BoxFit.contain),
              ),
              // Lines overlay
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
              // Words overlay with tooltips
              if (widget.showWords && _decodedImage != null)
                ...widget.textAnnotation.allWords.map((word) {
                  return _buildBoundingBoxWidget(
                    box: word.boundingBox,
                    text: word.text,
                    scaleX: scaleX,
                    scaleY: scaleY,
                    color: Colors.blue,
                    borderWidth: 1.0,
                    showTooltip: true,
                  );
                }),
            ],
          ),
        );
      },
    );
  }

  Widget _buildBoundingBoxWidget({
    required OcrBoundingBox box,
    required String text,
    required double scaleX,
    required double scaleY,
    required Color color,
    required double borderWidth,
    bool showTooltip = false,
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

    final child = Container(
      width: width,
      height: height,
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.3),
        border: Border.all(color: color, width: borderWidth),
      ),
    );

    return Positioned(
      left: minX,
      top: minY,
      child: showTooltip
          ? Tooltip(
              message: text,
              preferBelow: false,
              decoration: BoxDecoration(
                color: Colors.grey.shade800,
                borderRadius: BorderRadius.circular(4),
              ),
              textStyle: const TextStyle(color: Colors.white, fontSize: 14),
              waitDuration: const Duration(milliseconds: 200),
              child: MouseRegion(
                cursor: SystemMouseCursors.click,
                child: child,
              ),
            )
          : child,
    );
  }
}
