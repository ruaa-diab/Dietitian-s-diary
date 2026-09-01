import 'package:flutter/material.dart';

import 'app_colors.dart';
import 'app_text_styles.dart';

/// Material 3 theme wired to the design palette.
///
/// Most of the UI paints its own colours (the mockups are far more
/// specific than a seeded scheme), so this mainly exists to keep the
/// Material defaults — ripples, dialogs, text selection — on-palette.
abstract final class AppTheme {
  static ThemeData light() {
    const scheme = ColorScheme.light(
      primary: AppColors.clay,
      onPrimary: AppColors.card,
      primaryContainer: AppColors.clayTint,
      onPrimaryContainer: AppColors.clayDark,
      secondary: AppColors.sage,
      onSecondary: AppColors.card,
      secondaryContainer: AppColors.sageBg,
      onSecondaryContainer: AppColors.sageText,
      tertiary: AppColors.honey,
      onTertiary: AppColors.textPrimary,
      tertiaryContainer: AppColors.honeyBg,
      onTertiaryContainer: AppColors.honeyText,
      error: AppColors.clayDark,
      onError: AppColors.card,
      errorContainer: AppColors.dueBg,
      onErrorContainer: AppColors.clayDark,
      surface: AppColors.surface,
      onSurface: AppColors.textPrimary,
      surfaceContainerHighest: AppColors.canvas,
      onSurfaceVariant: AppColors.textSecondary,
      outline: AppColors.border,
      outlineVariant: AppColors.divider,
    );

    return ThemeData(
      useMaterial3: true,
      colorScheme: scheme,
      scaffoldBackgroundColor: AppColors.surface,
      canvasColor: AppColors.surface,
      fontFamily: AppFonts.body,
      splashFactory: InkSparkle.splashFactory,
      textSelectionTheme: const TextSelectionThemeData(
        cursorColor: AppColors.clay,
        selectionColor: AppColors.clayTint,
        selectionHandleColor: AppColors.clay,
      ),
      dividerTheme: const DividerThemeData(
        color: AppColors.divider,
        thickness: 1,
        space: 1,
      ),
      dialogTheme: const DialogThemeData(
        backgroundColor: AppColors.card,
        surfaceTintColor: Colors.transparent,
      ),
      bottomSheetTheme: const BottomSheetThemeData(
        backgroundColor: AppColors.card,
        surfaceTintColor: Colors.transparent,
      ),
      snackBarTheme: SnackBarThemeData(
        backgroundColor: AppColors.textPrimary,
        contentTextStyle: AppText.rowTitleSmall.copyWith(color: AppColors.card),
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      ),
      textTheme: Typography.blackMountainView.apply(
        fontFamily: AppFonts.body,
        bodyColor: AppColors.textPrimary,
        displayColor: AppColors.textPrimary,
      ),
    );
  }
}
