import 'package:flutter/widgets.dart';
import 'package:novident_editor/novident_editor.dart';

/// Resolves the effective [NovidentStyleDefinition] for [node], preferring
/// the [NovidentEditorStyles] InheritedWidget when present in the tree,
/// otherwise falling back to [editorState.editorStyles].
///
/// Shared by the style, font-family, and font-size toolbar items.
NovidentStyleDefinition resolveEffectiveToolbarStyle(
  BuildContext context,
  EditorState editorState,
  Node node,
) {
  final inherited = NovidentEditorStyles.maybeOf(context);
  if (inherited != null) return inherited.resolveStyle(node);

  final config = editorState.editorStyles;
  if (config == null) return kDefaultBaseStyle;

  final styleRef = node.attributes[blockComponentStyleRef] as String?;
  if (styleRef != null && styleRef.isNotEmpty) {
    final resolved = config.registry.resolve(styleRef);
    if (resolved != null) return resolved;
  }

  final typeDefault = config.defaultStylesByType[node.type];
  if (typeDefault != null) return typeDefault;

  return config.defaultStyle;
}
