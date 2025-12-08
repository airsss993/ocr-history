import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../models/ocr_result.dart';

class OcrTextDisplay extends StatelessWidget {
  final OcrTextAnnotation? textAnnotation;
  final GeminiTextResult? geminiResult;

  const OcrTextDisplay({super.key, this.textAnnotation, this.geminiResult});

  String get _fullText {
    if (textAnnotation != null) {
      return textAnnotation!.fullText;
    }
    if (geminiResult != null) {
      return geminiResult!.fullText;
    }
    return '';
  }

  @override
  Widget build(BuildContext context) {
    if (geminiResult != null) {
      return _buildGeminiDisplay(context);
    }
    return _buildYandexDisplay(context);
  }

  Widget _buildYandexDisplay(BuildContext context) {
    final fullText = _fullText;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        _buildHeader(context, fullText),
        const SizedBox(height: 8),
        _buildTextContainer(fullText),
      ],
    );
  }

  Widget _buildGeminiDisplay(BuildContext context) {
    final gemini = geminiResult!;
    final fullText = gemini.textMarkdown ?? '';

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        _buildHeader(context, fullText),
        const SizedBox(height: 8),
        if (gemini.summary != null && gemini.summary!.isNotEmpty) ...[
          _buildSection('Краткое содержание', gemini.summary!),
          const SizedBox(height: 12),
        ],
        if (gemini.documentTitle != null &&
            gemini.documentTitle!.isNotEmpty) ...[
          _buildSection('Название документа', gemini.documentTitle!),
          const SizedBox(height: 12),
        ],
        _buildTextContainer(fullText, title: 'Распознанный текст'),
        if (gemini.notes != null && gemini.notes!.isNotEmpty) ...[
          const SizedBox(height: 12),
          _buildSection('Примечания', gemini.notes!, isNote: true),
        ],
        if (gemini.warnings.isNotEmpty) ...[
          const SizedBox(height: 12),
          _buildWarnings(gemini.warnings),
        ],
        if (gemini.language != null && gemini.language!.isNotEmpty) ...[
          const SizedBox(height: 8),
          Text(
            'Язык: ${gemini.language}',
            style: TextStyle(fontSize: 12, color: Colors.grey.shade600),
          ),
        ],
      ],
    );
  }

  Widget _buildHeader(BuildContext context, String fullText) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        const Text(
          'Результат распознавания:',
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
    );
  }

  Widget _buildSection(String title, String content, {bool isNote = false}) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Text(
          title,
          style: TextStyle(
            fontSize: 14,
            fontWeight: FontWeight.w600,
            color: isNote ? Colors.orange.shade700 : Colors.black87,
          ),
        ),
        const SizedBox(height: 4),
        Container(
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            color: isNote ? Colors.orange.shade50 : Colors.blue.shade50,
            borderRadius: BorderRadius.circular(8),
            border: Border.all(
              color: isNote ? Colors.orange.shade200 : Colors.blue.shade200,
            ),
          ),
          child: SelectableText(
            content,
            style: TextStyle(
              fontSize: 14,
              height: 1.4,
              color: isNote ? Colors.orange.shade900 : Colors.blue.shade900,
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildTextContainer(String text, {String? title}) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.grey.shade100,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: Colors.grey.shade300),
      ),
      child: SelectableText(
        text.isEmpty ? 'Текст не распознан' : text,
        style: TextStyle(
          fontSize: 14,
          height: 1.5,
          color: text.isEmpty ? Colors.grey : Colors.black87,
        ),
      ),
    );
  }

  Widget _buildWarnings(List<String> warnings) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Text(
          'Предупреждения',
          style: TextStyle(
            fontSize: 14,
            fontWeight: FontWeight.w600,
            color: Colors.red.shade700,
          ),
        ),
        const SizedBox(height: 4),
        Container(
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            color: Colors.red.shade50,
            borderRadius: BorderRadius.circular(8),
            border: Border.all(color: Colors.red.shade200),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: warnings
                .map(
                  (w) => Padding(
                    padding: const EdgeInsets.symmetric(vertical: 2),
                    child: Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Icon(
                          Icons.warning_amber,
                          size: 16,
                          color: Colors.red.shade700,
                        ),
                        const SizedBox(width: 8),
                        Expanded(
                          child: Text(
                            w,
                            style: TextStyle(
                              fontSize: 13,
                              color: Colors.red.shade900,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                )
                .toList(),
          ),
        ),
      ],
    );
  }
}
