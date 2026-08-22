import 'package:flutter/material.dart';
import 'package:novident_editor/novident_editor.dart';

import 'zen_mode_scope.dart';

/// Layers the zen dimming on top of the effective span pipeline (spell check
/// or default) without coupling to it.
///
/// Overrides [resolveStyle] to neutralize the `textColor`/`backgroundColor`
/// attributes of dimmed blocks; every other phase delegates to [_delegate].
/// The dimming state is read from the [ZenModeScope] provided by the block's
/// [ZenModeBlock] wrapper.
class ZenSpanPipeline extends NovidentTextSpanPipeline {
  const ZenSpanPipeline(this._delegate);

  final NovidentTextSpanPipeline _delegate;

  @override
  TextStyle resolveStyle(
    Attributes? attributes,
    TextStyle base,
    TextStyleConfiguration textStyleConfiguration, {
    Node? node,
    BuildContext? context,
  }) {
    var style = _delegate.resolveStyle(
      attributes,
      base,
      textStyleConfiguration,
      node: node,
      context: context,
    );
    final scope = ZenModeScope.maybeOf(context);
    if (scope == null || !scope.dimmed || attributes == null) {
      return style;
    }
    final config = scope.configuration;

    // the transparent attribute is used internally (e.g. for auto-complete
    // ghost text), don't override it.
    final isTransparent = attributes[RichTextKeys.transparent] == true;

    if (config.ignoreTextColor &&
        !isTransparent &&
        attributes[RichTextKeys.textColor] != null) {
      final baseColor = base.color;
      if (baseColor != null && style.color != baseColor) {
        style = style.copyWith(
          color: _dimmedColor(baseColor, scope.unfocusedOpacity),
        );
      }
    }

    // the find & replace highlight (find_bg_color) is never neutralized,
    // otherwise search matches would become invisible.
    final hasFindHighlight =
        attributes[RichTextKeys.findBackgroundColor] != null;
    if (config.ignoreHighlightColor &&
        !hasFindHighlight &&
        attributes[RichTextKeys.backgroundColor] != null) {
      style = style.copyWith(backgroundColor: Colors.transparent);
    }

    return style;
  }

  @override
  String transformText(
    TextInsert insert,
    String displayText, {
    required bool caps,
    required bool smallCaps,
  }) {
    return _delegate.transformText(
      insert,
      displayText,
      caps: caps,
      smallCaps: smallCaps,
    );
  }

  @override
  List<InlineSpan> emitSpans(SpanEmitContext context) =>
      _delegate.emitSpans(context);

  @override
  List<InlineSpan> paintSelectionContrast(SelectionContrastContext context) =>
      _delegate.paintSelectionContrast(context);

  @override
  TextSpan buildPlaceholder(PlaceholderContext context) =>
      _delegate.buildPlaceholder(context);

  @override
  TextSpan adjustSpan(AdjustSpanContext context) =>
      _delegate.adjustSpan(context);

  static Color _dimmedColor(Color color, double opacity) =>
      color.withValues(alpha: opacity);
}