/// Single source of truth for the product identity.
///
/// Anything user-visible that is not translatable lives here, so a rename or a
/// rebrand is one edit rather than a search across the codebase. The shop name
/// itself is read from `settings.site_name` at runtime so ops can change it
/// without shipping a release; [name] is the fallback.
class Brand {
  const Brand._();

  static const name = 'Chanpenh';
  static const nameKm = 'សេឡា';

  /// Drawn in the header mark and the launcher icon.
  static const monogram = 'SE';

  static const taglineKm = 'ទិញភ្លាមៗ ទទួលភ្លាមៗ';
  static const taglineEn = 'Buy now, delivered now';

  /// Matches the bundle identifiers in `android/` and `ios/`.
  static const androidApplicationId = 'kh.chanpenh.store';
  static const iosBundleId = 'kh.chanpenh.store';

  /// Deep-link scheme, used once push notifications and ABA return-deeplinks
  /// are wired up.
  static const urlScheme = 'chanpenh';

  static String displayName(String locale) => locale == 'km' ? nameKm : name;
}
