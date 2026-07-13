import 'package:flutter/material.dart';

/// Centralized color palette for TripTab.
///
/// All colors used across the app should reference these constants
/// to ensure visual consistency and easy theme-wide updates.
abstract class AppColors {
  // ── Primary teal family ──────────────────────────────────────────
  static const Color primary = Color(0xFF009688);
  static const Color primaryLight = Color(0xFF4DB6AC);
  static const Color primaryDark = Color(0xFF00796B);
  static const Color primaryVariant = Color(0xFF00BFA5);

  // ── Surface / background (dark theme) ────────────────────────────
  static const Color background = Color(0xFF0F1419);
  static const Color surface = Color(0xFF1A1F2E);
  static const Color surfaceVariant = Color(0xFF2D3446);
  static const Color cardBackground = Color(0xFF1E2433);

  // ── Surface / background (light theme) ───────────────────────────
  static const Color backgroundLight = Color(0xFFF5F7FA);
  static const Color surfaceLight = Color(0xFFFFFFFF);
  static const Color surfaceVariantLight = Color(0xFFE4E9F2);
  static const Color cardBackgroundLight = Color(0xFFFFFFFF);

  // ── Text ─────────────────────────────────────────────────────────
  static const Color textPrimary = Color(0xFFFFFFFF);
  static const Color textSecondary = Color(0xB3FFFFFF); // white70
  static const Color textTertiary = Color(0x61FFFFFF); // white38
  
  static const Color textPrimaryLight = Color(0xFF1A1F2E);
  static const Color textSecondaryLight = Color(0xFF4A5568);
  static const Color textTertiaryLight = Color(0xFF718096);
  
  static const Color textOnPrimary = Color(0xFFFFFFFF);

  // ── Accent ───────────────────────────────────────────────────────
  static const Color accent = Color(0xFF26C6DA); // cyan accent
  static const Color accentLight = Color(0xFF80DEEA);

  // ── Semantic ─────────────────────────────────────────────────────
  static const Color error = Color(0xFFEF5350);
  static const Color errorDark = Color(0xFFC62828);
  static const Color success = Color(0xFF66BB6A);
  static const Color successDark = Color(0xFF2E7D32);
  static const Color warning = Color(0xFFFFA726);

  // ── Dividers & borders ───────────────────────────────────────────
  static const Color divider = Color(0x1FFFFFFF); // white12
  static const Color border = Color(0x33FFFFFF); // white20
  static const Color dividerLight = Color(0x1A000000); // black10
  static const Color borderLight = Color(0x26000000); // black15

  // ── Status badges ────────────────────────────────────────────────
  static const Color statusDraft = Color(0xFF78909C);
  static const Color statusActive = Color(0xFF00BFA5);
  static const Color statusSettled = Color(0xFF66BB6A);

  // ── Bottom sheet (light surface for mockup) ──────────────────────
  static const Color sheetBackground = Color(0xFFF5F5F5);
  static const Color sheetSurface = Color(0xFFFFFFFF);
  static const Color sheetTextPrimary = Color(0xFF212121);
  static const Color sheetTextSecondary = Color(0xFF757575);
}

extension AppThemeContext on BuildContext {
  bool get _isLight => Theme.of(this).brightness == Brightness.light;

  Color get colorBackground => _isLight ? AppColors.backgroundLight : AppColors.background;
  Color get colorSurface => _isLight ? AppColors.surfaceLight : AppColors.surface;
  Color get colorSurfaceVariant => _isLight ? AppColors.surfaceVariantLight : AppColors.surfaceVariant;
  Color get colorCardBackground => _isLight ? AppColors.cardBackgroundLight : AppColors.cardBackground;

  Color get colorTextPrimary => _isLight ? AppColors.textPrimaryLight : AppColors.textPrimary;
  Color get colorTextSecondary => _isLight ? AppColors.textSecondaryLight : AppColors.textSecondary;
  Color get colorTextTertiary => _isLight ? AppColors.textTertiaryLight : AppColors.textTertiary;

  Color get colorDivider => _isLight ? AppColors.dividerLight : AppColors.divider;
  Color get colorBorder => _isLight ? AppColors.borderLight : AppColors.border;
}
