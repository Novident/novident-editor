import 'package:flutter/material.dart';
import 'package:novident_editor_core/novident_editor_core.dart';
import 'package:novident_editor_document/novident_editor_document.dart';
import 'package:novident_editor_selection/novident_editor_selection.dart';

/// Configuration provided by the editor host for rich text rendering.
///
/// [NovidentRichText] depends on this interface instead of [EditorState]
/// so it can be used standalone (e.g. as a read-only node viewer)
/// without importing the full editor.
abstract class RichTextEditorConfig implements BlockSelectionHost {
  /// Global text scale factor applied to all text.
  double get textScaleFactor;

  /// Global first-line indent fallback when the style doesn't define one.
  double? get firstLineIndentFallback;

  /// Custom text span decorator for built-in or custom attributes.
  TextSpanDecoratorForAttribute? get textSpanDecorator;

  /// Builder for text span overlays (e.g. hover menu on links).
  NovidentTextSpanOverlayBuilder? get textSpanOverlayBuilder;

  /// Base text style configuration.
  TextStyleConfiguration get textStyleConfiguration;

  /// Whether auto-complete is enabled.
  bool get enableAutoComplete;

  /// Provider for auto-complete text.
  NovidentAutoCompleteTextProvider? get autoCompleteTextProvider;

  /// Custom selection/cursor renderer. When null, [DefaultSelectionRenderer] is used.
  @override
  SelectionRenderer? get selectionRenderer;
}

/// Decorates an [InlineSpan] for a custom attribute.
typedef TextSpanDecoratorForAttribute = InlineSpan Function(
  BuildContext context,
  Node node,
  int index,
  TextInsert text,
  TextSpan before,
  TextSpan after,
);

/// Decorates a [TextSpan] for the entire rich text block.
typedef NovidentTextSpanDecorator = TextSpan Function(TextSpan textSpan);

/// Provides auto-complete text for the current cursor position.
typedef NovidentAutoCompleteTextProvider = String? Function(
  BuildContext context,
  Node node,
  TextSpan? textSpan,
);

/// Builds overlay widgets on top of text spans.
typedef NovidentTextSpanOverlayBuilder = List<Widget> Function(
  BuildContext context,
  Node node,
  SelectableMixin delegate,
);
