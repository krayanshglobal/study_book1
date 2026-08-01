import 'package:flutter/material.dart';

class AppColors {
  // === Primary Brand Palette (from React Tailwind config) ===
  static const Color navy = Color(0xFF0F1B4C);      // #0F1B4C — headings, primary text
  static const Color blue = Color(0xFF2563EB);       // #2563EB — accents, links, primary buttons
  static const Color violet = Color(0xFF7C3AED);     // #7C3AED — premium, secondary accent

  // === Slate scale ===
  static const Color slate50  = Color(0xFFF8FAFC);
  static const Color slate100 = Color(0xFFF1F5F9);
  static const Color slate200 = Color(0xFFE2E8F0);  // borders
  static const Color slate300 = Color(0xFFCBD5E1);
  static const Color slate400 = Color(0xFF94A3B8);
  static const Color slate500 = Color(0xFF64748B);  // muted text
  static const Color slate600 = Color(0xFF475569);
  static const Color slate700 = Color(0xFF334155);  // secondary text
  static const Color slate800 = Color(0xFF1E293B);
  static const Color slate900 = Color(0xFF0F172A);

  // === Semantic ===
  static const Color white = Color(0xFFFFFFFF);
  static const Color background = Color(0xFFFFFFFF);
  static const Color surface = Color(0xFFF8FAFC);
  static const Color border = slate200;
  static const Color textPrimary = navy;
  static const Color textSecondary = slate700;
  static const Color textMuted = slate500;
  static const Color error = Color(0xFFDC2626);
  static const Color success = Color(0xFF16A34A);
  static const Color warning = Color(0xFFD97706);

  // Gradients
  static const Gradient blueVioletGradient = LinearGradient(
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
    colors: [blue, violet],
  );
  static const Gradient navyPurpleGradient = LinearGradient(
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
    colors: [navy, Color(0xFF4C1D95)],
  );

  // === Backward-compatibility aliases ===
  static const Color primary = navy;
  static const Color accent = blue;
  static const Color purple = violet;
  static const Color card = white;
  static const Color inputBorder = slate200;
  static const Color textWhite = white;

  AppColors._();
}

