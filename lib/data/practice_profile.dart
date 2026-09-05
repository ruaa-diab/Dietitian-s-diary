import 'package:flutter/widgets.dart';

/// Details about the practice itself: the brand, and the defaults for the
/// dietitian's own name.
///
/// Her name is editable from حسابي and, once she changes it, lives in
/// Firestore with the rest of her data — read [AppStore.dietitianName]
/// rather than the constant here anywhere a store is in reach. The
/// constants are what a brand-new account starts out showing.
abstract final class PracticeProfile {
  static const brandName = 'تَغذية';
  static const dietitianName = 'أ. رنين دياب';

  /// The given name on its own, for greeting her directly. Held
  /// explicitly rather than split off the full name, which carries an
  /// honorific and a surname around it.
  static const firstName = 'رنين';
  static const title = 'أخصائية تغذية';

  static String get byline => '$dietitianName · $title';

  /// The given name out of a full name she typed herself — "أ. رنين دياب"
  /// gives "رنين". A single-letter token followed by a dot is an
  /// honorific (أ. for أستاذة, د. for دكتورة), never a name, so it is
  /// skipped rather than greeted.
  static String firstNameOf(String fullName) {
    final parts = fullName.trim().split(RegExp(r'\s+')).where((p) => p.isNotEmpty);
    for (final part in parts) {
      if (part.replaceAll('.', '').characters.length > 1) return part;
    }
    return parts.isEmpty ? fullName.trim() : parts.first;
  }
}
