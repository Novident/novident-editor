import 'package:flutter/material.dart';
import 'package:novident_editor_core/novident_editor_core.dart';

import 'package:novident_editor_document/novident_editor_document.dart';

/// Controls paragraph spacing: space before, after, hanging indent, and line height multiplier.
class NovidentStyleSpacing {
  const NovidentStyleSpacing({
    this.before,
    this.after,
    this.hanging,
    this.lineHeight = 1.0,
  });

  final double? before;
  final double? after;

  /// Hanging indent — the first line hangs to the left of the rest of the paragraph.
  final double? hanging;

  /// Line height multiplier (1.0 = single, 1.5 = one-and-a-half, 2.0 = double).
  final double lineHeight;

  NovidentStyleSpacing merge(NovidentStyleSpacing? other) {
    if (other == null) return this;
    return NovidentStyleSpacing(
      before: other.before ?? before,
      after: other.after ?? after,
      hanging: other.hanging ?? hanging,
      lineHeight:
          other.lineHeight != lineHeight ? other.lineHeight : lineHeight,
    );
  }
}

//TODO: @Cathood0 some properties of the styles are not being used
/// Controls paragraph indentation: left, right, and first-line indent.
class NovidentStyleIndent {
  const NovidentStyleIndent({
    this.left,
    this.right,
    this.firstLineIndent,
    this.shouldFilterLineIndent,
  });

  const NovidentStyleIndent.defaultLineFilter({
    this.left,
    this.right,
    this.firstLineIndent,
    this.shouldFilterLineIndent = _defaultFilter,
  });

  static bool _defaultFilter(Node node) {
    if (node.type == ParagraphBlockKeys.type) {
      final prev = node.previous;
      if (prev == null) return true;
      final attrs = prev.attributes;
      if ((attrs[blockComponentStyleRef] as String?)?.startsWith('heading-') ??
          false) {
        return true;
      }
    }
    if (node.type == HeadingBlockKeys.type) return true;
    return false;
  }

  final double? left;
  final double? right;

  /// First-line indent width. When set, the first line of the paragraph
  /// is indented by this amount via a [WidgetSpan] prepended to the text.
  final double? firstLineIndent;

  /// Returns [true] if we prefer to ignore the first line indent
  /// [false] to use it as expected
  final bool Function(Node)? shouldFilterLineIndent;

  NovidentStyleIndent merge(NovidentStyleIndent? other) {
    if (other == null) return this;
    return NovidentStyleIndent(
      left: other.left ?? left,
      right: other.right ?? right,
      firstLineIndent: other.firstLineIndent ?? firstLineIndent,
      shouldFilterLineIndent:
          other.shouldFilterLineIndent ?? shouldFilterLineIndent,
    );
  }
}

/// Paragraph border style.
class NovidentStyleBorder {
  const NovidentStyleBorder({
    this.border,
  });

  final Border? border;

  NovidentStyleBorder merge(NovidentStyleBorder? other) {
    if (other == null) return this;
    return NovidentStyleBorder(
      border: other.border ?? border,
    );
  }
}

/// Pagination control: keep with next paragraph, keep lines together.
class NovidentStyleKeep {
  const NovidentStyleKeep({
    this.keepNext = false,
  });

  final bool keepNext;

  NovidentStyleKeep merge(NovidentStyleKeep? other) {
    if (other == null) return this;
    return NovidentStyleKeep(
      keepNext: other.keepNext,
    );
  }
}

/// A reusable, named style definition — similar to Word paragraph/character styles.
///
/// Each style has a unique [id] and human-readable [name].
/// [basedOn] enables style inheritance: the referenced style's properties
/// are resolved first, then overridden by this style's explicit values.
/// [next] defines the style automatically applied when the user presses Enter
/// at the end of a paragraph using this style.
class NovidentStyleDefinition {
  const NovidentStyleDefinition({
    required this.id,
    required this.name,
    this.basedOn,
    this.next,
    this.spacing,
    this.indent,
    this.borderStyle,
    this.keep,
    this.alignment = TextAlign.left,
    this.blockBackgroundColor,
    this.bold = false,
    this.italic = false,
    this.underline = false,
    this.overline = false,
    this.strikethrough = false,
    this.caps = false,
    this.smallCaps = false,
    this.decorationStyle,
    this.decorationColor,
    this.fontFamily,
    this.fontSize = 12.0,
    this.textColor,
    this.textBackgroundColor,
    this.letterSpacing,
    this.fontVariations,
    this.fontBackground,
    this.fontForeground,
    this.wordSpacing,
    this.fontFeatures,
    this.fontShadows,
    this.allowGlobalFirstLineIndent = true,
  });

  const NovidentStyleDefinition.nextSame({
    required this.id,
    required this.name,
    this.basedOn,
    this.spacing,
    this.indent,
    this.borderStyle,
    this.keep,
    this.alignment = TextAlign.left,
    this.blockBackgroundColor,
    this.bold = false,
    this.italic = false,
    this.underline = false,
    this.overline = false,
    this.strikethrough = false,
    this.caps = false,
    this.smallCaps = false,
    this.decorationStyle,
    this.decorationColor,
    this.fontFamily,
    this.fontSize = 12.0,
    this.textColor,
    this.textBackgroundColor,
    this.letterSpacing,
    this.fontVariations,
    this.fontShadows,
    this.fontFeatures,
    this.fontBackground,
    this.fontForeground,
    this.wordSpacing,
    this.allowGlobalFirstLineIndent = true,
  }) : next = id;

  final String id;
  final String name;

  /// Style ID to inherit from. Properties from the parent style are resolved first
  /// and overridden by any explicitly set values on this style.
  final String? basedOn;

  /// Style ID applied to the next paragraph after pressing Enter.
  final String? next;

  final NovidentStyleSpacing? spacing;
  final NovidentStyleIndent? indent;
  final NovidentStyleBorder? borderStyle;
  final NovidentStyleKeep? keep;
  final TextAlign alignment;
  final Color? blockBackgroundColor;

  final bool bold;
  final bool italic;
  final bool underline;
  final bool overline;
  final bool strikethrough;
  final bool caps;
  final bool smallCaps;
  final TextDecorationStyle? decorationStyle;
  final Color? decorationColor;
  final List<FontVariation>? fontVariations;
  final List<FontFeature>? fontFeatures;
  final List<Shadow>? fontShadows;
  final Paint? fontForeground;
  final Paint? fontBackground;
  final String? fontFamily;
  final double fontSize;
  final double? letterSpacing;
  final double? wordSpacing;
  final Color? textColor;
  final Color? textBackgroundColor;

  /// When true (default), the [EditorStyle.firstLineIndent] global value
  /// is used as a fallback if this style does not define its own
  /// [NovidentStyleIndent.firstLineIndent].
  ///
  /// When false, only this style's own [NovidentStyleIndent.firstLineIndent]
  /// is considered; no global fallback is applied.
  final bool allowGlobalFirstLineIndent;

  /// Merges [other] on top of this style. [other] values take precedence.
  /// Used during [basedOn] chain resolution.
  NovidentStyleDefinition merge(NovidentStyleDefinition other) {
    return NovidentStyleDefinition(
      id: other.id,
      name: other.name,
      basedOn: other.basedOn ?? basedOn,
      next: other.next ?? next,
      decorationStyle: other.decorationStyle ?? decorationStyle,
      decorationColor: other.decorationColor ?? decorationColor,
      fontVariations: other.fontVariations ?? fontVariations,
      fontShadows: other.fontShadows ?? fontShadows,
      fontFeatures: other.fontFeatures ?? fontFeatures,
      fontBackground: other.fontBackground ?? fontBackground,
      fontForeground: other.fontForeground ?? fontForeground,
      letterSpacing: other.letterSpacing ?? letterSpacing,
      wordSpacing: other.wordSpacing ?? wordSpacing,
      spacing: other.spacing != null
          ? spacing?.merge(other.spacing) ?? other.spacing
          : spacing,
      indent: other.indent != null
          ? indent?.merge(other.indent) ?? other.indent
          : indent,
      borderStyle: other.borderStyle != null
          ? borderStyle?.merge(other.borderStyle) ?? other.borderStyle
          : borderStyle,
      keep: other.keep != null ? keep?.merge(other.keep) ?? other.keep : keep,
      alignment: other.alignment != alignment ? other.alignment : alignment,
      blockBackgroundColor: other.blockBackgroundColor ?? blockBackgroundColor,
      bold: other.bold != bold ? other.bold : bold,
      italic: other.italic != italic ? other.italic : italic,
      underline: other.underline != underline ? other.underline : underline,
      overline: other.overline != overline ? other.overline : overline,
      strikethrough: other.strikethrough != strikethrough
          ? other.strikethrough
          : strikethrough,
      caps: other.caps != caps ? other.caps : caps,
      smallCaps: other.smallCaps != smallCaps ? other.smallCaps : smallCaps,
      fontFamily: other.fontFamily ?? fontFamily,
      fontSize: other.fontSize != fontSize ? other.fontSize : fontSize,
      textColor: other.textColor ?? textColor,
      textBackgroundColor: other.textBackgroundColor ?? textBackgroundColor,
      allowGlobalFirstLineIndent:
          other.allowGlobalFirstLineIndent != allowGlobalFirstLineIndent
              ? other.allowGlobalFirstLineIndent
              : allowGlobalFirstLineIndent,
    );
  }

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is NovidentStyleDefinition &&
          runtimeType == other.runtimeType &&
          id == other.id;

  @override
  int get hashCode => id.hashCode;
}
