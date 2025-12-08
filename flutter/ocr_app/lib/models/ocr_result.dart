class OcrVertex {
  final int x;
  final int y;

  OcrVertex({required this.x, required this.y});

  factory OcrVertex.fromJson(Map<String, dynamic> json) {
    return OcrVertex(
      x: int.tryParse(json['x']?.toString() ?? '0') ?? 0,
      y: int.tryParse(json['y']?.toString() ?? '0') ?? 0,
    );
  }

  Map<String, dynamic> toJson() => {'x': x.toString(), 'y': y.toString()};
}

class OcrBoundingBox {
  final List<OcrVertex> vertices;

  OcrBoundingBox({required this.vertices});

  factory OcrBoundingBox.fromJson(Map<String, dynamic> json) {
    final verticesList = json['vertices'] as List<dynamic>? ?? [];
    return OcrBoundingBox(
      vertices: verticesList
          .map((v) => OcrVertex.fromJson(v as Map<String, dynamic>))
          .toList(),
    );
  }

  Map<String, dynamic> toJson() => {
    'vertices': vertices.map((v) => v.toJson()).toList(),
  };
}

class OcrWord {
  final OcrBoundingBox boundingBox;
  final String text;

  OcrWord({required this.boundingBox, required this.text});

  factory OcrWord.fromJson(Map<String, dynamic> json) {
    return OcrWord(
      boundingBox: OcrBoundingBox.fromJson(
        json['boundingBox'] as Map<String, dynamic>? ?? {},
      ),
      text: json['text'] as String? ?? '',
    );
  }

  Map<String, dynamic> toJson() => {
    'boundingBox': boundingBox.toJson(),
    'text': text,
  };
}

class OcrLine {
  final OcrBoundingBox boundingBox;
  final String text;
  final List<OcrWord> words;

  OcrLine({required this.boundingBox, required this.text, required this.words});

  factory OcrLine.fromJson(Map<String, dynamic> json) {
    final wordsList = json['words'] as List<dynamic>? ?? [];
    return OcrLine(
      boundingBox: OcrBoundingBox.fromJson(
        json['boundingBox'] as Map<String, dynamic>? ?? {},
      ),
      text: json['text'] as String? ?? '',
      words: wordsList
          .map((w) => OcrWord.fromJson(w as Map<String, dynamic>))
          .toList(),
    );
  }

  Map<String, dynamic> toJson() => {
    'boundingBox': boundingBox.toJson(),
    'text': text,
    'words': words.map((w) => w.toJson()).toList(),
  };
}

class OcrBlock {
  final OcrBoundingBox boundingBox;
  final List<OcrLine> lines;

  OcrBlock({required this.boundingBox, required this.lines});

  factory OcrBlock.fromJson(Map<String, dynamic> json) {
    final linesList = json['lines'] as List<dynamic>? ?? [];
    return OcrBlock(
      boundingBox: OcrBoundingBox.fromJson(
        json['boundingBox'] as Map<String, dynamic>? ?? {},
      ),
      lines: linesList
          .map((l) => OcrLine.fromJson(l as Map<String, dynamic>))
          .toList(),
    );
  }

  Map<String, dynamic> toJson() => {
    'boundingBox': boundingBox.toJson(),
    'lines': lines.map((l) => l.toJson()).toList(),
  };
}

class OcrTextAnnotation {
  final int width;
  final int height;
  final List<OcrBlock> blocks;

  OcrTextAnnotation({
    required this.width,
    required this.height,
    required this.blocks,
  });

  factory OcrTextAnnotation.fromJson(Map<String, dynamic> json) {
    final blocksList = json['blocks'] as List<dynamic>? ?? [];
    return OcrTextAnnotation(
      width: int.tryParse(json['width']?.toString() ?? '0') ?? 0,
      height: int.tryParse(json['height']?.toString() ?? '0') ?? 0,
      blocks: blocksList
          .map((b) => OcrBlock.fromJson(b as Map<String, dynamic>))
          .toList(),
    );
  }

  Map<String, dynamic> toJson() => {
    'width': width.toString(),
    'height': height.toString(),
    'blocks': blocks.map((b) => b.toJson()).toList(),
  };

  String get fullText {
    return blocks
        .expand((block) => block.lines)
        .map((line) => line.text)
        .join('\n');
  }

  List<OcrWord> get allWords {
    return blocks
        .expand((block) => block.lines)
        .expand((line) => line.words)
        .toList();
  }

  List<OcrLine> get allLines {
    return blocks.expand((block) => block.lines).toList();
  }
}

class OcrImageResult {
  final String filename;
  final OcrTextAnnotation? textAnnotation;
  final String? error;

  OcrImageResult({required this.filename, this.textAnnotation, this.error});

  factory OcrImageResult.fromJson(Map<String, dynamic> json) {
    OcrTextAnnotation? annotation;

    final text = json['text'];
    if (text != null && text is Map<String, dynamic>) {
      final result = text['result'] as Map<String, dynamic>?;
      if (result != null) {
        final textAnnotation =
            result['textAnnotation'] as Map<String, dynamic>?;
        if (textAnnotation != null) {
          annotation = OcrTextAnnotation.fromJson(textAnnotation);
        }
      }
    }

    final errorValue = json['error'];
    final errorStr = (errorValue is String && errorValue.isNotEmpty)
        ? errorValue
        : null;

    return OcrImageResult(
      filename: json['filename'] as String? ?? '',
      textAnnotation: annotation,
      error: errorStr,
    );
  }

  Map<String, dynamic> toJson() => {
    'filename': filename,
    if (textAnnotation != null)
      'text': {
        'result': {'textAnnotation': textAnnotation!.toJson()},
      },
    if (error != null) 'error': error,
  };

  bool get isSuccess => error == null && textAnnotation != null;
}

class OcrApiResponse {
  final List<OcrImageResult> results;
  final int totalImages;
  final int successful;
  final int failed;

  OcrApiResponse({
    required this.results,
    required this.totalImages,
    required this.successful,
    required this.failed,
  });

  factory OcrApiResponse.fromJson(Map<String, dynamic> json) {
    final resultsList = json['results'] as List<dynamic>? ?? [];
    return OcrApiResponse(
      results: resultsList
          .map((r) => OcrImageResult.fromJson(r as Map<String, dynamic>))
          .toList(),
      totalImages: json['total_images'] as int? ?? 0,
      successful: json['successful'] as int? ?? 0,
      failed: json['failed'] as int? ?? 0,
    );
  }
}
