import 'package:novident_styles/src/style_definition.dart';
import 'package:novident_styles/src/style_registry.dart';
import 'package:novident_styles/src/default_styles.dart' show kDefaultBaseStyle;

class NovidentStylesConfig {
  const NovidentStylesConfig({
    required this.registry,
    this.defaultStyle = kDefaultBaseStyle,
    this.defaultStylesByType = const <String, NovidentStyleDefinition>{},
  });

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
