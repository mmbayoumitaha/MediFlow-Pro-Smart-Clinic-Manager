import 'package:flutter/material.dart';

/// Standardized spacing, sizing, and border radius values.
class AppSizes {
  AppSizes._();

  // ──────── Spacing ────────
  static const double xs = 4.0;
  static const double sm = 8.0;
  static const double md = 16.0;
  static const double lg = 24.0;
  static const double xl = 32.0;
  static const double xxl = 48.0;
  static const double xxxl = 64.0;

  // ──────── Border Radius ────────
  static const double radiusSm = 8.0;
  static const double radiusMd = 12.0;
  static const double radiusLg = 16.0;
  static const double radiusXl = 24.0;
  static const double radiusFull = 100.0;

  // ──────── Icon Sizes ────────
  static const double iconSm = 18.0;
  static const double iconMd = 24.0;
  static const double iconLg = 32.0;
  static const double iconXl = 48.0;

  // ──────── Avatar Sizes ────────
  static const double avatarSm = 36.0;
  static const double avatarMd = 48.0;
  static const double avatarLg = 64.0;
  static const double avatarXl = 96.0;

  // ──────── Button Heights ────────
  static const double buttonHeight = 52.0;
  static const double buttonHeightSm = 40.0;

  // ──────── Card ────────
  static const double cardElevation = 0.0;
  static const double cardPadding = 16.0;

  // ──────── App Bar ────────
  static const double appBarHeight = 64.0;

  // ──────── Breakpoints ────────
  static const double mobileBreakpoint = 600.0;
  static const double tabletBreakpoint = 900.0;
  static const double desktopBreakpoint = 1200.0;

  // ──────── Page Padding ────────
  static const EdgeInsets pagePadding = EdgeInsets.all(md);
  static const EdgeInsets pagePaddingHorizontal =
      EdgeInsets.symmetric(horizontal: md);
}
