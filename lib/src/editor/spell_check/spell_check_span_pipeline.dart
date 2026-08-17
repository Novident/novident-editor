import 'package:flutter/material.dart';
import 'package:novident_editor_document/novident_editor_document.dart';
import 'package:novident_editor_rich_text/novident_editor_rich_text.dart';
import 'package:novident_spell_check_interface/novident_spell_check_interface.dart';

/// Pipeline that renders the spell-check mark stored in the delta.
///
/// It never runs a spell-check engine: it only interprets the `proofState`
/// attribute that the spell-check service writes into the delta
/// (see `SpellCheckService`). Text inserts marked with `proofState: 'error'`
/// are styled with [misspelledStyle]; everything else follows the default
/// pipeline behavior, legacy decorators included.
///
/// The default style only adds the classic wavy red underline — the
/// original text color and other attributes are preserved.
class SpellCheckSpanPipeline extends DefaultNovidentTextSpanPipeline {
  const SpellCheckSpanPipeline({
    this.misspelledStyle = defaultMisspelledStyle,
    super.textSpanDecorator,
    super.textSpanDecoratorForAttribute,
  });

  /// Classic red wavy underline style.
  static const TextStyle defaultMisspelledStyle = TextStyle(
    decoration: TextDecoration.underline,
    decorationColor: Colors.red,
    decorationStyle: TextDecorationStyle.wavy,
  );

  /// Style merged over the marked spans. Only the non-null properties of
  /// this style are applied, so text color/weight are preserved unless the
  /// caller opts into overriding them.
  final TextStyle misspelledStyle;

  @override
  List<InlineSpan> emitSpans(SpanEmitContext context) {
    final marked =
        context.insert.attributes?[RichTextKeys.proofState] == proofStateError;
    if (!marked) {
      return super.emitSpans(context);
    }
    final spans = super.emitSpans(context);
    return [
      for (final span in spans)
        if (span is TextSpan && span.text != null)
          TextSpan(
            text: span.text,
            style: (span.style ?? context.style).merge(misspelledStyle),
            children: span.children,
          )
        else
          span,
    ];
  }
}
