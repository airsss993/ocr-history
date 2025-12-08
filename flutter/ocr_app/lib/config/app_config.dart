class AppConfig {
  static const String _defaultBackendUrl = 'http://localhost:8100';

  static String get backendUrl {
    const url = String.fromEnvironment(
      'BACKEND_URL',
      defaultValue: _defaultBackendUrl,
    );
    return url;
  }

  static String get ocrYandexEndpoint => '$backendUrl/api/v1/ocr/yandex';
}
