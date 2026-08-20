import 'package:novident_editor_styles/novident_editor_styles.dart';

class NovidentStylesConfig {
  NovidentStylesConfig({
    required this.registry,
    NovidentStyleDefinition? defaultStyle,
    this.defaultStylesByType = const <String, NovidentStyleDefinition>{},
  }) : defaultStyle = defaultStyle ?? kDefaultBaseStyle;

  final NovidentStyleRegistry registry;
  final NovidentStyleDefinition defaultStyle;
  final Map<String, NovidentStyleDefinition> defaultStylesByType;

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is NovidentStylesConfig &&
          registry == other.registry &&
          defaultStyle == other.defaultStyle;

  @override
  int get hashCode => Object.hash(
        registry,
        defaultStyle,
        defaultStylesByType,
      );
}
