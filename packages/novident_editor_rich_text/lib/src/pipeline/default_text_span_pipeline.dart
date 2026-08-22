import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:novident_editor_core/novident_editor_core.dart';
import 'package:novident_editor_document/novident_editor_document.dart';

import '../mixins/editor_config.dart';
import '../utils/rich_text_attributes.dart';
import 'contexts.dart';
import 'text_span_pipeline.dart';

final Map<Color, double> _cachedResolvedLuminanceColor = {};

/// The legacy pipeline: reproduces the exact behavior `NovidentRichText`
/// had before the pipeline was introduced, including the legacy decorator
/// callbacks.
class DefaultNovidentTextSpanPipeline extends NovidentTextSpanPipeline {
  const DefaultNovidentTextSpanPipeline({
    this.textSpanDecorator,
    this.textSpanDecoratorForAttribute,
  });

  /// Legacy whole-span decorator (applied to every emitted span, as the
  /// `after` argument of the per-attribute decorator).
  final NovidentTextSpanDecorator? textSpanDecorator;

  /// Legacy per-attribute decorator.
  final TextSpanDecoratorForAttribute? textSpanDecoratorForAttribute;

  @override
  TextStyle resolveStyle(
    Attributes? attributes,
    TextStyle base,
    TextStyleConfiguration textStyleConfiguration, {
    Node? node,
    BuildContext? context,
  }) {
    var textStyle = base;
    if (attributes == null) {
      return textStyle;
    }

    if (attributes.bold == true) {
      textStyle =
          textStyle.combine(const TextStyle(fontWeight: FontWeight.bold));
    }
    if (attributes.italic == true) {
      textStyle =
          textStyle.combine(const TextStyle(fontStyle: FontStyle.italic));
    }
    if (attributes.underline == true) {
      textStyle = textStyle.combine(const TextStyle(
        decoration: TextDecoration.underline,
      ));
    }
    if (attributes.strikethrough == true) {
      textStyle = textStyle.combine(const TextStyle(
        decoration: TextDecoration.lineThrough,
      ));
    }
    if (attributes.href != null) {
      textStyle = textStyle.combine(textStyleConfiguration.href);
    }
    if (attributes.code == true) {
      textStyle = textStyle.combine(textStyleConfiguration.code);
    }
    if (attributes.backgroundColor != null) {
      textStyle = textStyle.combine(
        TextStyle(backgroundColor: attributes.backgroundColor),
      );
    }
    if (attributes.findBackgroundColor != null) {
      textStyle = textStyle.combine(
        TextStyle(backgroundColor: attributes.findBackgroundColor),
      );
    }
    if (attributes.color != null) {
      textStyle = textStyle.combine(
        TextStyle(color: attributes.color),
      );
    }
    if (attributes.fontFamily != null) {
      textStyle = textStyle.combine(
        TextStyle(fontFamily: attributes.fontFamily),
      );
    }
    if (attributes.fontSize != null) {
      textStyle = textStyle.combine(
        TextStyle(fontSize: attributes.fontSize),
      );
    }
    if (attributes.autoComplete == true) {
      textStyle = textStyle.combine(textStyleConfiguration.autoComplete);
    }
    if (attributes.transparent == true) {
      textStyle = textStyle.combine(
        const TextStyle(color: Colors.transparent),
      );
    }
    return textStyle;
  }

  @override
  String transformText(
    TextInsert insert,
    String displayText, {
    required bool caps,
    required bool smallCaps,
  }) {
    if (caps) {
      return displayText.toUpperCase();
      // by now we set small caps just as lowercase
    }
    if (smallCaps) {
      return displayText.toLowerCase();
    }
    return displayText;
  }

  @override
  List<InlineSpan> emitSpans(SpanEmitContext context) {
    final span = TextSpan(text: context.displayText, style: context.style);
    final decorator =
        context.textSpanDecoratorForAttribute ?? textSpanDecoratorForAttribute;
    if (decorator != null) {
      return [
        decorator(
          context.buildContext!,
          context.node,
          context.offset,
          context.insert,
          span,
          (context.textSpanDecorator ?? textSpanDecorator)?.call(span) ?? span,
        ),
      ];
    }
    return [span];
  }

  @override
  List<InlineSpan> paintSelectionContrast(SelectionContrastContext context) {
    if (!context.hasSelection) {
      return context.spans;
    }
    final blockBg = context.textStyle.backgroundColor ?? Colors.white;
    final decorationColor = context.textStyle.decorationColor ??
        context.textStyleConfiguration.href.decorationColor ??
        context.textStyleConfiguration.href.color;
    final effectiveBg = Color.alphaBlend(
      context.selectionColor,
      blockBg,
    );
    final effectiveDecorationColor = decorationColor == null
        ? null
        : Color.alphaBlend(
            context.selectionColor,
            decorationColor,
          );
    final contrastColor = _contrastColor(effectiveBg);
    final decorationContrastColor = effectiveDecorationColor == null
        ? null
        : _contrastColor(effectiveDecorationColor);

    final result = <InlineSpan>[];
    var offset = context.insertOffset;
    for (final span in context.spans) {
      final spanLen = _spanLength(span);
      final spanStart = offset;
      final spanEnd = offset + spanLen;
      offset = spanEnd;

      final intersectStart = math.max(spanStart, context.selStart);
      final intersectEnd = math.min(spanEnd, context.selEnd);
      if (intersectStart >= intersectEnd) {
        result.add(span);
        continue;
      }
      // Only splittable plain text spans can be re-styled; everything else
      // (WidgetSpans, nested spans) is passed through untouched.
      if (span is! TextSpan ||
          span.text == null ||
          (span.children?.isNotEmpty ?? false)) {
        result.add(span);
        continue;
      }

      final text = span.text!;
      final style = span.style ?? context.textStyle;
      final contrastStyle = style.copyWith(
        color: contrastColor,
        decorationColor: decorationContrastColor,
      );

      // Before selection — normal color.
      if (spanStart < intersectStart) {
        final beforeLen = intersectStart - spanStart;
        result.add(
          TextSpan(text: text.substring(0, beforeLen), style: style),
        );
      }
      // Inside selection — contrast color.
      final selPieceStart = intersectStart - spanStart;
      final selPieceEnd = intersectEnd - spanStart;
      result.add(
        TextSpan(
          text: text.substring(selPieceStart, selPieceEnd),
          style: contrastStyle,
        ),
      );
      // After selection — normal color.
      if (intersectEnd < spanEnd) {
        final afterStart = intersectEnd - spanStart;
        result.add(
          TextSpan(text: text.substring(afterStart), style: style),
        );
      }
    }
    return result;
  }

  @override
  TextSpan buildPlaceholder(PlaceholderContext context) {
    final children = <InlineSpan>[
      if (context.textShift > 0)
        WidgetSpan(child: SizedBox(width: context.firstLineIndentWidth)),
      TextSpan(
        text: context.placeholderText,
        style: context.baseTextStyle.copyWith(
          color: context.baseTextStyle.color?.withAlpha(150),
        ),
      ),
    ];
    return TextSpan(children: children);
  }

  @override
  TextSpan adjustSpan(AdjustSpanContext context) {
    var textSpan = context.span;
    // https://github.com/flutter/flutter/pull/143954
    // https://github.com/AppFlowy-IO/appflowy-editor/issues/819#issuecomment-2177833413
    // This is a workaround for the issue that the caret height of the text
    // is not calculated correctly if the parent style is null.
    if (textSpan.style == null && textSpan.children != null) {
      double height = 0.0;
      double fontSize = 0.0;
      textSpan.visitChildren((span) {
        final style = span.style;
        if (style != null) {
          if (style.height != null) {
            height = math.max(height, style.height!);
          }
          if (style.fontSize != null) {
            fontSize = math.max(fontSize, style.fontSize!);
          }
        }
        return true;
      });
      if (height == 0.0 || fontSize == 0.0) {
        return textSpan;
      }
      textSpan = textSpan.copyWith(
        // used to maintain legacy compatibility
        style: context.node.type == HeadingBlockKeys.type
            ? TextStyle(
                height: height,
                fontSize: fontSize,
              )
            : context.baseTextStyle,
      );
    }
    return textSpan;
  }

  static Color _contrastColor(Color color) =>
      (_cachedResolvedLuminanceColor[color] ??= color.computeLuminance()) > 0.5
          ? Colors.black
          : Colors.white;

  /// UTF-16 length of a span for offset bookkeeping. [WidgetSpan]s (and
  /// any unknown span) count as 0: document offsets only measure text.
  static int _spanLength(InlineSpan span) {
    if (span is WidgetSpan) {
      return 0;
    }
    if (span is TextSpan) {
      var length = span.text?.length ?? 0;
      for (final child in span.children ?? const <InlineSpan>[]) {
        length += _spanLength(child);
      }
      return length;
    }
    return 0;
  }
}
