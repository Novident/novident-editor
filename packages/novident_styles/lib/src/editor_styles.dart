import 'package:novident_styles/src/style_registry.dart';
import 'package:novident_styles/src/styles_config.dart';
import 'package:novident_styles/src/style_definition.dart';
import 'package:novident_editor_document/novident_editor_document.dart';
import 'package:flutter/widgets.dart';

/// Attribute key used to reference a style by ID on a node.
const _blockComponentStyleRef = 'styleRef';

class NovidentEditorStyles extends InheritedWidget {
  const NovidentEditorStyles({
    super.key,
    required this.config,
    required super.child,
  });

  final NovidentStylesConfig config;

  NovidentStyleDefinition resolveStyle(Node node) {
    final styleRef = node.attributes[_blockComponentStyleRef] as String?;
    if (styleRef != null && styleRef.isNotEmpty) {
      final resolved = config.registry.resolve(
        styleRef,
        baseStyle: config.defaultStyle,
        forType: node.type,
        byTypes: config.defaultStylesByType,
      );
      if (resolved != null) return resolved;
    }

    final typeDefault = config.defaultStylesByType[node.type];
    if (typeDefault != null) return typeDefault;

    assert(
      config.defaultStyle.fontFamily != null,
      'NovidentStylesConfig.defaultStyle must have a non-null fontFamily.',
    );
    assert(
      config.defaultStyle.fontSize > 0,
      'NovidentStylesConfig.defaultStyle must have a '
      'fontSize major than zero. Found "${config.defaultStyle.fontSize}"',
    );
    return config.defaultStyle;
  }

  static NovidentEditorStyles? maybeOf(BuildContext context) {
    return context.dependOnInheritedWidgetOfExactType<NovidentEditorStyles>();
  }

  static NovidentEditorStyles of(BuildContext context) {
    final styles = maybeOf(context);
    assert(styles != null, 'No NovidentEditorStyles found in context');
    return styles!;
  }

  @override
  bool updateShouldNotify(NovidentEditorStyles oldWidget) {
    return config != oldWidget.config;
  }
}
