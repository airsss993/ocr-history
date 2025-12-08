import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../models/ocr_result.dart';

class OcrTextDisplay extends StatelessWidget {
  final OcrTextAnnotation textAnnotation;

  const OcrTextDisplay({super.key, required this.textAnnotation});

  @override
  Widget build(BuildContext context) {
    final fullText = textAnnotation.fullText;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            const Text(
              'Распознанный текст:',
              style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
            ),
            IconButton(
              icon: const Icon(Icons.copy),
              tooltip: 'Копировать текст',
              onPressed: () {
                Clipboard.setData(ClipboardData(text: fullText));
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(
                    content: Text('Текст скопирован'),
                    duration: Duration(seconds: 1),
                  ),
                );
              },
            ),
          ],
        ),
        const SizedBox(height: 8),
        Container(
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            color: Colors.grey.shade100,
            borderRadius: BorderRadius.circular(8),
            border: Border.all(color: Colors.grey.shade300),
          ),
          child: SelectableText(
            fullText.isEmpty ? 'Текст не распознан' : fullText,
            style: TextStyle(
              fontSize: 14,
              height: 1.5,
              color: fullText.isEmpty ? Colors.grey : Colors.black87,
            ),
          ),
        ),
      ],
    );
  }
}
