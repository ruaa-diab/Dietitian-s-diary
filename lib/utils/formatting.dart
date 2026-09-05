/// Number, currency and date formatting for the Arabic UI.
///
/// The mockups render every figure in Arabic-Indic digits (٠١٢٣…), so
/// that is the default. Digit localization was flagged as an open product
/// decision in the spec: flip [AppNumerals.useArabicIndic] to `false` and
/// the whole app falls back to Western digits — nothing else needs to
/// change, because every user-facing number goes through this file.
library;

abstract final class AppNumerals {
  static bool useArabicIndic = true;

  static const _arabicIndic = ['٠', '١', '٢', '٣', '٤', '٥', '٦', '٧', '٨', '٩'];

  /// U+066B ARABIC DECIMAL SEPARATOR, as used in the design (٧٣٫٨).
  static const _arabicDecimal = '٫';

  /// U+2212 MINUS SIGN — the design uses the typographic minus, not a hyphen.
  static const minus = '−';
  static const percent = '٪';
  static const shekel = '₪';

  /// Converts the ASCII digits (and `.`) in [input] to the active numeral
  /// system. Non-digit characters pass through untouched.
  static String localize(String input) {
    if (!useArabicIndic) return input;
    final out = StringBuffer();
    for (final unit in input.codeUnits) {
      if (unit >= 0x30 && unit <= 0x39) {
        out.write(_arabicIndic[unit - 0x30]);
      } else if (unit == 0x2E) {
        out.write(_arabicDecimal);
      } else {
        out.write(String.fromCharCode(unit));
      }
    }
    return out.toString();
  }
}

/// Formats an integer, e.g. `24` → `٢٤`.
String fmtInt(num value) => AppNumerals.localize(value.round().toString());

/// Formats a number with [decimals] places, trimming a trailing `.0`
/// only when [decimals] is 0. e.g. `73.8` → `٧٣٫٨`.
String fmtDecimal(num value, {int decimals = 1}) =>
    AppNumerals.localize(value.toStringAsFixed(decimals));

/// A signed delta with the typographic minus/plus, e.g. `-4.2` → `−٤٫٢`.
///
/// A whole number loses its decimal, so a `-6` goal reads `−٦` rather
/// than `−٦٫٠` — the design writes goals without one.
String fmtSigned(num value, {int decimals = 1}) {
  final sign = value < 0 ? AppNumerals.minus : '+';
  final places = value == value.roundToDouble() ? 0 : decimals;
  return '$sign${fmtDecimal(value.abs(), decimals: places)}';
}

/// A signed whole-number percentage, e.g. `18` → `+١٨٪`.
String fmtSignedPercent(num value) {
  final sign = value < 0 ? AppNumerals.minus : '+';
  return '$sign${fmtInt(value.abs())}${AppNumerals.percent}';
}

/// Currency with the shekel symbol after the number, per the spec.
String fmtCurrency(num value) {
  final amount = value == value.roundToDouble()
      ? fmtInt(value)
      : fmtDecimal(value, decimals: 2);
  return '$amount ${AppNumerals.shekel}';
}

/// A bare price with no symbol, for rows that place ₪ themselves.
String fmtPrice(num value) =>
    value == value.roundToDouble() ? fmtInt(value) : fmtDecimal(value, decimals: 2);

abstract final class ArabicDates {
  static const months = [
    'يناير', 'فبراير', 'مارس', 'أبريل', 'مايو', 'يونيو',
    'يوليو', 'أغسطس', 'سبتمبر', 'أكتوبر', 'نوفمبر', 'ديسمبر',
  ];

  /// Indexed by `DateTime.weekday` (1 = Monday … 7 = Sunday).
  static const _weekdays = [
    'الاثنين', 'الثلاثاء', 'الأربعاء', 'الخميس', 'الجمعة', 'السبت', 'الأحد',
  ];

  static String monthName(int month) => months[month - 1];

  static String weekday(DateTime date) => _weekdays[date.weekday - 1];

  /// `١ سبتمبر`
  static String dayMonth(DateTime date) =>
      '${fmtInt(date.day)} ${monthName(date.month)}';

  /// `الثلاثاء ١ سبتمبر`
  static String weekdayDayMonth(DateTime date) =>
      '${weekday(date)} ${dayMonth(date)}';

  /// `سبتمبر ٢٠٢٦`
  static String monthYear(DateTime date) =>
      '${monthName(date.month)} ${fmtInt(date.year)}';

  /// `١٠:٣٠ ص` — 12-hour clock with Arabic ص/م markers.
  static String time(DateTime date) {
    final hour12 = date.hour % 12 == 0 ? 12 : date.hour % 12;
    final marker = date.hour < 12 ? 'ص' : 'م';
    final minutes = date.minute.toString().padLeft(2, '0');
    return '${AppNumerals.localize('$hour12:$minutes')} $marker';
  }

  /// A date range as shown in the package history: `١٢ أغسطس — جارية`.
  static String range(DateTime start, DateTime? end) =>
      '${dayMonth(start)} — ${end == null ? 'جارية' : dayMonth(end)}';

  /// `٢١ يوماً` — Arabic pluralisation for a day count.
  static String days(int count) {
    if (count == 1) return 'يوم واحد';
    if (count == 2) return 'يومان';
    if (count >= 3 && count <= 10) return '${fmtInt(count)} أيام';
    return '${fmtInt(count)} يوماً';
  }

  /// `٤ زيارات` — Arabic pluralisation for a visit count.
  static String visits(int count) {
    if (count == 1) return 'زيارة واحدة';
    if (count == 2) return 'زيارتان';
    if (count >= 3 && count <= 10) return '${fmtInt(count)} زيارات';
    return '${fmtInt(count)} زيارة';
  }

  /// `باقتان` — Arabic pluralisation for a package count.
  static String packages(int count) {
    if (count == 1) return 'باقة واحدة';
    if (count == 2) return 'باقتين';
    if (count >= 3 && count <= 10) return '${fmtInt(count)} باقات';
    return '${fmtInt(count)} باقة';
  }

  /// Whole days between two dates, ignoring the time of day.
  static int daysBetween(DateTime from, DateTime to) {
    final a = DateTime(from.year, from.month, from.day);
    final b = DateTime(to.year, to.month, to.day);
    return b.difference(a).inDays;
  }

  static bool isSameDay(DateTime a, DateTime b) =>
      a.year == b.year && a.month == b.month && a.day == b.day;
}

/// `0541234567` → `٠٥٤ ١٢٣ ٤٥٦٧`. Phone numbers are stored as plain
/// Western digits and only localized for display.
String fmtPhone(String raw) {
  final digits = raw.replaceAll(RegExp(r'\D'), '');
  final buffer = StringBuffer();
  for (var i = 0; i < digits.length; i++) {
    if (i == 3 || i == 6) buffer.write(' ');
    buffer.write(digits[i]);
  }
  return AppNumerals.localize(buffer.toString());
}
