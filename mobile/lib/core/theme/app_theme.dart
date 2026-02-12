import 'package:flutter/material.dart';

class AppTheme {
  static const _primaryColor = Color(0xFF1890FF);

  static ThemeData get light => ThemeData(
    colorScheme: ColorScheme.fromSeed(
      seedColor: _primaryColor,
      brightness: Brightness.light,
    ),
    useMaterial3: true,
  );

  static ThemeData get dark => ThemeData(
    colorScheme: ColorScheme.fromSeed(
      seedColor: _primaryColor,
      brightness: Brightness.dark,
    ),
    useMaterial3: true,
  );

  // Reader themes
  static const readerThemes = {
    'white': ReaderTheme(background: Color(0xFFFFFFFF), text: Color(0xFF333333)),
    'yellow': ReaderTheme(background: Color(0xFFF5F0E0), text: Color(0xFF4A4A4A)),
    'green': ReaderTheme(background: Color(0xFFE0F0E0), text: Color(0xFF3A4A3A)),
    'dark': ReaderTheme(background: Color(0xFF2C2C2C), text: Color(0xFFC0C0C0)),
    'black': ReaderTheme(background: Color(0xFF000000), text: Color(0xFF808080)),
  };
}

class ReaderTheme {
  final Color background;
  final Color text;

  const ReaderTheme({required this.background, required this.text});
}
