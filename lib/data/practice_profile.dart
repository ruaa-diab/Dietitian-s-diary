/// Details about the practice itself, shown on the shareable progress card.
///
/// Hard-coded for now; this is the natural place to hang a settings screen
/// once the dietitian can edit her own details.
abstract final class PracticeProfile {
  static const brandName = 'تَغذية';
  static const dietitianName = 'أ. رنين دياب';

  /// The given name on its own, for greeting her directly. Held
  /// explicitly rather than split off the full name, which carries an
  /// honorific and a surname around it.
  static const firstName = 'رنين';
  static const title = 'أخصائية تغذية';

  static String get byline => '$dietitianName · $title';
}
