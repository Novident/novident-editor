import 'package:novident_editor/novident_editor.dart';
import 'package:flutter/foundation.dart' show ValueListenable;
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

/// Builds a [TextSpanDecoratorForAttribute] that visually neutralizes the
/// text color (`font_color`) and highlight color (`bg_color`) attributes
/// while zen mode is enabled.
///
/// The attributes are **not** removed from the document — the spans are only
/// rendered without them. Disabling zen mode restores the original colors.
///
/// The returned decorator delegates to [inner] (defaults to
/// [defaultTextSpanDecoratorForAttribute], which keeps the built-in link
/// behavior) after neutralizing the colors.
TextSpanDecoratorForAttribute zenModeTextSpanDecorator({
  required ValueListenable<ZenModeConfiguration> configuration,
  TextSpanDecoratorForAttribute? inner = defaultTextSpanDecoratorForAttribute,
}) {
  return (
    BuildContext context,
    Node node,
    int index,
    TextInsert text,
    TextSpan before,
    TextSpan after,
  ) {
    final config = configuration.value;
    final attributes = text.attributes;
    if (!config.enabled || attributes == null) {
      return inner?.call(context, node, index, text, before, after) ?? before;
    }
    final neutralizedBefore =
        _neutralizeColors(context, attributes, before, config);
    final neutralizedAfter =
        _neutralizeColors(context, attributes, after, config);
    return inner?.call(
          context,
          node,
          index,
          text,
          neutralizedBefore,
          neutralizedAfter,
        ) ??
        neutralizedBefore;
  };
}

TextSpan _neutralizeColors(
  BuildContext context,
  Attributes attributes,
  TextSpan span,
  ZenModeConfiguration config,
) {
  var style = span.style;
  if (style == null) {
    return span;
  }

  var changed = false;

  // the transparent attribute is used internally (e.g. for auto-complete
  // ghost text), don't override it.
  final isTransparent = attributes[NovidentRichTextKeys.transparent] == true;

  if (config.ignoreTextColor &&
      !isTransparent &&
      attributes[NovidentRichTextKeys.textColor] != null) {
    final editorState = context.read<EditorState>();
    final baseColor =
        editorState.editorStyle.textStyleConfiguration.text.color ??
            DefaultTextStyle.of(context).style.color;
    if (baseColor != null && style.color != baseColor) {
      style = style.copyWith(color: baseColor);
      changed = true;
    }
  }

  // the find & replace highlight (find_bg_color) is never neutralized,
  // otherwise search matches would become invisible.
  final hasFindHighlight =
      attributes[NovidentRichTextKeys.findBackgroundColor] != null;
  if (config.ignoreHighlightColor &&
      !hasFindHighlight &&
      attributes[NovidentRichTextKeys.backgroundColor] != null) {
    style = style.copyWith(backgroundColor: Colors.transparent);
    changed = true;
  }

  if (!changed) {
    return span;
  }

  return TextSpan(
    text: span.text,
    children: span.children,
    style: style,
    recognizer: span.recognizer,
    mouseCursor: span.mouseCursor,
    onEnter: span.onEnter,
    onExit: span.onExit,
    semanticsLabel: span.semanticsLabel,
    locale: span.locale,
    spellOut: span.spellOut,
  );
}
