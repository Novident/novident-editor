import 'package:novident_editor_styles/src/providers/standard_fonts_by_os_provider.dart';

/// Provides the list of available font families and a guaranteed
/// non-null default.
///
/// [NovidentFontProvider.fallback] returns a small universal set that is
/// safe on every platform. Apps that want system-specific fonts (e.g. via
/// the `system_fonts` package on desktop) can pass a custom list through
/// [NovidentFontProvider.fromList].
class NovidentFontProvider {
  const NovidentFontProvider._({
    required this.availableFonts,
    required this.defaultFontFamily,
  });

  /// Universal fallback — safe on every platform (Android, iOS, desktop).
  ///
  /// The default is `'Roboto'` because the Flutter engine bundles it on
  /// Android and it is widely available elsewhere.
  factory NovidentFontProvider.fallback() {
    return NovidentFontProvider._(
      availableFonts: getDefaultFonts(),
      defaultFontFamily: getDefaultFont(),
    );
  }

  /// Builds a provider from a custom font list.
  ///
  /// [defaultFamily] overrides the first font in the list as the default.
  /// When omitted the first entry of [fonts] is used.
  factory NovidentFontProvider.fromList(
    List<String> fonts, {
    String? defaultFamily,
  }) {
    assert(fonts.isNotEmpty, 'At least one font must be provided.');
    return NovidentFontProvider._(
      availableFonts: Set.unmodifiable(fonts),
      defaultFontFamily: defaultFamily ?? fonts.first,
    );
  }

  /// All font families the user can choose from.
  final Set<String> availableFonts;

  /// The font family applied when nothing else is specified.
  ///
  /// This is guaranteed to be non-null — Novident Editor never leaves the
  /// font family decision to the platform.
  final String defaultFontFamily;
}
