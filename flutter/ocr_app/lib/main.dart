import 'package:flutter/material.dart';

import 'screens/photo_picker_screen.dart';

void main() {
  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'OCR Hist',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        scaffoldBackgroundColor: Colors.white,
        colorScheme: ColorScheme.fromSeed(
          seedColor: Colors.blue,
          primary: Colors.blue,
        ),
        elevatedButtonTheme: ElevatedButtonThemeData(
          style: ElevatedButton.styleFrom(
            backgroundColor: Colors.blue,
            foregroundColor: Colors.white,
            textStyle: const TextStyle(
              fontFamily: 'Roboto',
              fontWeight: FontWeight.w300,
              fontSize: 16,
            ),
            padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
          ),
        ),
        textTheme: const TextTheme(
          bodyLarge: TextStyle(
            fontFamily: 'Roboto',
            fontWeight: FontWeight.w100,
          ),
          bodyMedium: TextStyle(
            fontFamily: 'Roboto',
            fontWeight: FontWeight.w100,
          ),
          titleLarge: TextStyle(
            fontFamily: 'Roboto',
            fontWeight: FontWeight.w100,
          ),
        ),
      ),
      home: const PhotoPickerScreen(),
    );
  }
}
