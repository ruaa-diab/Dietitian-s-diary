import 'package:flutter/widgets.dart';

import 'app_colors.dart';

/// The two font families from the spec.
///
/// [display] (Baloo Bhaijaan 2) carries screen titles, big numbers and
/// client names; [body] (IBM Plex Sans Arabic) carries everything else.
abstract final class AppFonts {
  static const display = 'Baloo Bhaijaan 2';
  static const body = 'IBM Plex Sans Arabic';
}

/// Text styles named after the role they play in the mockups, with the
/// pixel sizes the design canvas used at a 412×892 reference frame.
abstract final class AppText {
  static TextStyle _display(double size, FontWeight weight, {Color? color, double? height}) =>
      TextStyle(
        fontFamily: AppFonts.display,
        fontSize: size,
        fontWeight: weight,
        height: height,
        color: color ?? AppColors.textPrimary,
      );

  static TextStyle _body(double size, FontWeight weight, {Color? color, double? height}) =>
      TextStyle(
        fontFamily: AppFonts.body,
        fontSize: size,
        fontWeight: weight,
        height: height,
        color: color ?? AppColors.textPrimary,
      );

  // ── Display ──────────────────────────────────────────────────────────
  /// Big screen titles: اليوم / العميلات / الملخص.
  static TextStyle get screenTitle => _display(34, FontWeight.w800);

  /// Client name on the detail screen and the share card headline.
  static TextStyle get pageHeadline => _display(28, FontWeight.w700);
  static TextStyle get cardHeadline => _display(30, FontWeight.w800, height: 1.35);
  static TextStyle get shareName => _display(34, FontWeight.w800);

  /// Hero revenue figure on the dashboard.
  static TextStyle get heroAmount =>
      _display(46, FontWeight.w800, color: AppColors.card, height: 1);
  static TextStyle get bigWeight => _display(38, FontWeight.w800);
  static TextStyle get amountLarge => _display(30, FontWeight.w800, color: AppColors.clay);
  static TextStyle get amountMedium => _display(26, FontWeight.w800);
  static TextStyle get statNumber => _display(28, FontWeight.w800);
  static TextStyle get packagePrice => _display(24, FontWeight.w800);
  static TextStyle get amountSmall => _display(20, FontWeight.w800, color: AppColors.clay);
  static TextStyle get brandMark => _display(19, FontWeight.w700);
  static TextStyle get avatarInitialLarge => _display(32, FontWeight.w700);
  static TextStyle get packageIndex => _display(16, FontWeight.w700);

  // ── Body ─────────────────────────────────────────────────────────────
  static TextStyle get buttonLarge => _body(19, FontWeight.w600, color: AppColors.card);
  static TextStyle get button => _body(18, FontWeight.w600, color: AppColors.card);
  static TextStyle get buttonMedium => _body(17, FontWeight.w600);
  static TextStyle get buttonSmall => _body(15, FontWeight.w600);
  static TextStyle get textButton => _body(16, FontWeight.w600, color: AppColors.clayDark);

  static TextStyle get navTitle => _body(20, FontWeight.w600);
  static TextStyle get listName => _body(19, FontWeight.w600);
  static TextStyle get listNameSmall => _body(18, FontWeight.w600);
  static TextStyle get rowTitle => _body(17, FontWeight.w600);
  static TextStyle get rowTitleSmall => _body(16, FontWeight.w600);
  static TextStyle get sectionTitle => _body(17, FontWeight.w600);

  static TextStyle get bodyLarge => _body(17, FontWeight.w400, color: AppColors.textSecondary, height: 1.7);
  static TextStyle get meta => _body(15, FontWeight.w400, color: AppColors.textMuted);
  static TextStyle get metaSmall => _body(14, FontWeight.w400, color: AppColors.textMuted);
  static TextStyle get metaTiny => _body(13, FontWeight.w500, color: AppColors.textTertiary);
  static TextStyle get dateHeader => _body(15, FontWeight.w500, color: AppColors.textMuted);
  static TextStyle get fieldLabel => _body(15, FontWeight.w600, color: AppColors.textMuted);
  static TextStyle get placeholder => _body(17, FontWeight.w400, color: AppColors.textTertiary);
  static TextStyle get inputValueLabel => _body(16, FontWeight.w400, color: AppColors.textMuted);

  static TextStyle get chip => _body(15, FontWeight.w600);
  static TextStyle get chipIdle => _body(15, FontWeight.w500, color: AppColors.textSecondary);
  static TextStyle get pill => _body(14, FontWeight.w600);
  static TextStyle get pillMuted => _body(14, FontWeight.w500, color: AppColors.textSecondary);
  static TextStyle get pillSmall => _body(13, FontWeight.w600);
  static TextStyle get navLabelActive => _body(13, FontWeight.w600, color: AppColors.clayDark);
  static TextStyle get navLabelIdle => _body(13, FontWeight.w500, color: AppColors.textTertiary);
  static TextStyle get eyebrow =>
      _display(15, FontWeight.w700, color: AppColors.sage).copyWith(letterSpacing: 1.4);
}
