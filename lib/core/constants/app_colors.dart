import 'package:flutter/material.dart';

/// MediFlow Pro — Premium Medical Color Palette
/// Designed for a professional healthcare SaaS look.
class AppColors {
  AppColors._();

  // ──────── Primary (Teal Medical) ────────
  static const Color primary = Color(0xFF0D9488);
  static const Color primaryLight = Color(0xFF5EEAD4);
  static const Color primaryDark = Color(0xFF0F766E);
  static const Color primaryContainer = Color(0xFFCCFBF1);

  // ──────── Secondary (Deep Indigo) ────────
  static const Color secondary = Color(0xFF6366F1);
  static const Color secondaryLight = Color(0xFFA5B4FC);
  static const Color secondaryDark = Color(0xFF4338CA);
  static const Color secondaryContainer = Color(0xFFE0E7FF);

  // ──────── Accent (Amber Warm) ────────
  static const Color accent = Color(0xFFF59E0B);
  static const Color accentLight = Color(0xFFFCD34D);
  static const Color accentDark = Color(0xFFD97706);

  // ──────── Semantic Colors ────────
  static const Color success = Color(0xFF10B981);
  static const Color successLight = Color(0xFFD1FAE5);
  static const Color warning = Color(0xFFF59E0B);
  static const Color warningLight = Color(0xFFFEF3C7);
  static const Color error = Color(0xFFEF4444);
  static const Color errorLight = Color(0xFFFEE2E2);
  static const Color info = Color(0xFF3B82F6);
  static const Color infoLight = Color(0xFFDBEAFE);

  // ──────── Neutral (Slate Scale) ────────
  static const Color slate50 = Color(0xFFF8FAFC);
  static const Color slate100 = Color(0xFFF1F5F9);
  static const Color slate200 = Color(0xFFE2E8F0);
  static const Color slate300 = Color(0xFFCBD5E1);
  static const Color slate400 = Color(0xFF94A3B8);
  static const Color slate500 = Color(0xFF64748B);
  static const Color slate600 = Color(0xFF475569);
  static const Color slate700 = Color(0xFF334155);
  static const Color slate800 = Color(0xFF1E293B);
  static const Color slate900 = Color(0xFF0F172A);

  // ──────── Light Theme ────────
  static const Color lightBackground = Color(0xFFF8FAFC);
  static const Color lightSurface = Colors.white;
  static const Color lightCard = Colors.white;
  static const Color lightText = Color(0xFF0F172A);
  static const Color lightTextSecondary = Color(0xFF64748B);
  static const Color lightDivider = Color(0xFFE2E8F0);

  // ──────── Dark Theme ────────
  static const Color darkBackground = Color(0xFF0F172A);
  static const Color darkSurface = Color(0xFF1E293B);
  static const Color darkCard = Color(0xFF1E293B);
  static const Color darkText = Color(0xFFF1F5F9);
  static const Color darkTextSecondary = Color(0xFF94A3B8);
  static const Color darkDivider = Color(0xFF334155);

  // ──────── Gradients ────────
  static const LinearGradient primaryGradient = LinearGradient(
    colors: [Color(0xFF0D9488), Color(0xFF06B6D4)],
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
  );

  static const LinearGradient secondaryGradient = LinearGradient(
    colors: [Color(0xFF6366F1), Color(0xFF8B5CF6)],
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
  );

  static const LinearGradient accentGradient = LinearGradient(
    colors: [Color(0xFFF59E0B), Color(0xFFF97316)],
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
  );

  static const LinearGradient darkOverlay = LinearGradient(
    colors: [Color(0x00000000), Color(0xBB000000)],
    begin: Alignment.topCenter,
    end: Alignment.bottomCenter,
  );
}
