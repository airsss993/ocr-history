import 'package:flutter/material.dart';

import '../services/settings_service.dart';

class SettingsBottomSheet extends StatefulWidget {
  final OcrProvider initialProvider;
  final String? initialApiKey;
  final Function(OcrProvider provider, String? apiKey) onSave;

  const SettingsBottomSheet({
    super.key,
    required this.initialProvider,
    this.initialApiKey,
    required this.onSave,
  });

  static Future<void> show(
    BuildContext context, {
    required OcrProvider initialProvider,
    String? initialApiKey,
    required Function(OcrProvider provider, String? apiKey) onSave,
  }) {
    return showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      builder: (context) => SettingsBottomSheet(
        initialProvider: initialProvider,
        initialApiKey: initialApiKey,
        onSave: onSave,
      ),
    );
  }

  @override
  State<SettingsBottomSheet> createState() => _SettingsBottomSheetState();
}

class _SettingsBottomSheetState extends State<SettingsBottomSheet> {
  late OcrProvider _selectedProvider;
  late TextEditingController _apiKeyController;
  bool _obscureApiKey = true;

  @override
  void initState() {
    super.initState();
    _selectedProvider = widget.initialProvider;
    _apiKeyController = TextEditingController(text: widget.initialApiKey ?? '');
  }

  @override
  void dispose() {
    _apiKeyController.dispose();
    super.dispose();
  }

  void _save() {
    final apiKey = _apiKeyController.text.trim();
    widget.onSave(_selectedProvider, apiKey.isEmpty ? null : apiKey);
    Navigator.pop(context);
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: EdgeInsets.only(
        bottom: MediaQuery.of(context).viewInsets.bottom,
      ),
      child: Container(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                const Text(
                  'Настройки OCR',
                  style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
                ),
                IconButton(
                  icon: const Icon(Icons.close),
                  onPressed: () => Navigator.pop(context),
                ),
              ],
            ),
            const SizedBox(height: 24),
            const Text(
              'OCR провайдер',
              style: TextStyle(fontSize: 14, fontWeight: FontWeight.w500),
            ),
            const SizedBox(height: 8),
            SegmentedButton<OcrProvider>(
              segments: const [
                ButtonSegment(
                  value: OcrProvider.yandex,
                  label: Text('Yandex'),
                  icon: Icon(Icons.cloud_outlined),
                ),
                ButtonSegment(
                  value: OcrProvider.gemini,
                  label: Text('Gemini'),
                  icon: Icon(Icons.auto_awesome),
                ),
              ],
              selected: {_selectedProvider},
              onSelectionChanged: (selection) {
                setState(() {
                  _selectedProvider = selection.first;
                });
              },
            ),
            if (_selectedProvider == OcrProvider.gemini) ...[
              const SizedBox(height: 24),
              const Text(
                'Gemini API ключ',
                style: TextStyle(fontSize: 14, fontWeight: FontWeight.w500),
              ),
              const SizedBox(height: 8),
              TextField(
                controller: _apiKeyController,
                obscureText: _obscureApiKey,
                decoration: InputDecoration(
                  hintText: 'Введите API ключ',
                  border: const OutlineInputBorder(),
                  suffixIcon: IconButton(
                    icon: Icon(
                      _obscureApiKey ? Icons.visibility : Icons.visibility_off,
                    ),
                    onPressed: () {
                      setState(() {
                        _obscureApiKey = !_obscureApiKey;
                      });
                    },
                  ),
                ),
              ),
              const SizedBox(height: 8),
              Text(
                'Gemini LLM может работать медленнее из-за обработки',
                style: TextStyle(fontSize: 12, color: Colors.grey.shade600),
              ),
            ],
            const SizedBox(height: 24),
            ElevatedButton(onPressed: _save, child: const Text('Сохранить')),
            const SizedBox(height: 8),
          ],
        ),
      ),
    );
  }
}
