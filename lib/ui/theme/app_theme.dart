import 'package:flutter/material.dart';

class AppTheme {
  // 🎨 Colores principales
  static const Color gradTop = Color(0xFF2458D6);   // azul
  static const Color gradBottom = Color(0xFF0A9A76); // verde

  // 🎨 Marco translúcido
  static const double radiusFrame = 28.0;
  static final BoxShadow shadowFrame = BoxShadow(
    color: Colors.black.withOpacity(0.18),
    blurRadius: 20,
    offset: const Offset(0, 10),
  );

  // 🎨 Tema de la app (si lo usas en MaterialApp)
  static ThemeData get materialTheme {
    return ThemeData(
      fontFamily: 'Roboto',
      primaryColor: gradTop,
      scaffoldBackgroundColor: Colors.transparent,
      colorScheme: ColorScheme.fromSwatch().copyWith(
        primary: gradTop,
        secondary: gradBottom,
      ),
    );
  }
}