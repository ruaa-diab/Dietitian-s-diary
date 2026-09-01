import 'package:flutter/material.dart';

/// Palette lifted verbatim from the design spec.
///
/// Names keep the Arabic design vocabulary where the spec used it
/// (طيني clay, مريمي sage, عسلي honey) so the mockups and the code
/// talk about the same colours.
abstract final class AppColors {
  /// App background — warm cream/tan.
  static const canvas = Color(0xFFEFE4DA);

  /// Screen background inside the device frame — the lighter cream.
  static const surface = Color(0xFFFBF6F1);
  static const card = Color(0xFFFFFFFF);

  /// طيني — primary accent, used for primary buttons and key CTAs.
  static const clay = Color(0xFFC2685E);

  /// Pressed/hover state for [clay]; also headings and links.
  static const clayDark = Color(0xFF9E4A44);
  static const clayTint = Color(0xFFF6E3DE);
  static const clayPale = Color(0xFFF3CFC9);

  /// مريمي — positive / attended / success states, weight-loss progress.
  static const sage = Color(0xFF5F7D5A);
  static const sageDark = Color(0xFF4E6B4A);
  static const sageMid = Color(0xFF83A47D);
  static const sageText = Color(0xFF3F5A3B);
  static const sageBg = Color(0xFFE3EBDD);
  static const sageBgAlt = Color(0xFFEDF2E9);
  static const sageDot = Color(0xFFC9D8C3);
  static const sageTrack = Color(0xFFDCE6D5);

  /// عسلي — highlight bar for the current month, confetti.
  static const honey = Color(0xFFE9A93C);
  static const honeyBg = Color(0xFFFBF3E4);
  static const honeyText = Color(0xFF9A6B18);

  static const textPrimary = Color(0xFF362B2C);
  static const textSecondary = Color(0xFF7A6A6D);
  static const textMuted = Color(0xFF8A7679);

  /// Inactive nav icons, placeholders, chart date labels.
  static const textTertiary = Color(0xFFA79396);

  static const border = Color(0xFFE3D6CC);
  static const borderSoft = Color(0xFFEFE4DA);
  static const divider = Color(0xFFF4EDE7);
  static const gridLine = Color(0xFFF1E7E0);
  static const radioIdle = Color(0xFFDCCCC4);

  /// Unpaid balance chips and cards.
  static const dueBg = Color(0xFFFDF2F0);
  static const dueText = clay;
  static const dueTextStrong = clayDark;

  /// "0 remaining", expired package states.
  static const neutralChipBg = divider;
  static const neutralChipText = textMuted;

  static const shareCardBg = Color(0xFFFDF7F0);
  static const scrim = Color(0x59362B2C); // rgba(54,43,44,0.35)

  /// Avatar tints, rotated per client. Kept inside the clay/tan family so
  /// an avatar never reads as a status colour the way sage or honey would.
  static const avatarTints = <(Color background, Color foreground)>[
    (clayTint, clayDark),
    (honeyBg, honeyText),
    (canvas, textMuted),
    (divider, textSecondary),
  ];
}
