import 'package:flutter/material.dart';
import 'package:novident_editor_core/novident_editor_core.dart';
import 'package:novident_editor_document/novident_editor_document.dart';

import '../mixins/editor_config.dart';

/// Data passed to phase 3 (`emitSpans`) of the text-span pipeline.
///
/// Immutable; does not expose the widget state. [buildContext] is null when
/// emitting spans outside a widget build (e.g. pure unit tests) — legacy
/// decorators that require a context must not be passed in that case.
class SpanEmitContext {
  const SpanEmitContext({
    this.buildContext,
    required this.node,
    required this.insert,
    required this.displayText,
    required this.style,
    required this.offset,
    required this.textStyleConfiguration,
    this.textSpanDecoratorForAttribute,
    this.textSpanDecorator,
  });

  final BuildContext? buildContext;

  /// The node being rendered.
  final Node node;

  /// The original [TextInsert] this emission belongs to.
  final TextInsert insert;

  /// Text after phase 2 (`transformText`). Its length must equal
  /// `insert.text.length` in UTF-16 code units (caps/smallCaps preserve it).
  final String displayText;

  /// Style after phase 1 (`resolveStyle`).
  final TextStyle style;

  /// Offset of this insert within the node's delta (UTF-16 code units).
  final int offset;

  final TextStyleConfiguration textStyleConfiguration;

  /// Legacy per-attribute decorator, resolved by the widget.
  final TextSpanDecoratorForAttribute? textSpanDecoratorForAttribute;

  /// Legacy whole-span decorator, resolved by the widget.
  final NovidentTextSpanDecorator? textSpanDecorator;
}

/// Data passed to phase 4 (`paintSelectionContrast`) of the pipeline.
class SelectionContrastContext {
  const SelectionContrastContext({
    required this.node,
    required this.insert,
    required this.spans,
    required this.insertOffset,
    required this.selStart,
    required this.selEnd,
    required this.textStyle,
    required this.textStyleConfiguration,
    required this.selectionColor,
    required this.hasSelection,
  });

  final Node node;
  final TextInsert insert;

  /// Spans produced by phase 3 for this insert, in order. Their lengths
  /// (UTF-16) must sum to `displayText.length`; [WidgetSpan]s count as 0.
  final List<InlineSpan> spans;

  /// Offset of this insert within the node's delta (UTF-16 code units).
  final int insertOffset;

  /// Selection range within the node (already normalized to this node),
  /// only meaningful when [hasSelection] is true.
  final int selStart;
  final int selEnd;

  /// Style resolved by phase 1, used to compute the contrast colors.
  final TextStyle textStyle;

  final TextStyleConfiguration textStyleConfiguration;
  final Color selectionColor;
  final bool hasSelection;
}

/// Data passed to phase 5 (`buildPlaceholder`) of the pipeline.
class PlaceholderContext {
  const PlaceholderContext({
    required this.node,
    required this.placeholderText,
    required this.baseTextStyle,
    this.textShift = 0,
    this.firstLineIndentWidth,
  });

  final Node node;
  final String placeholderText;
  final TextStyle baseTextStyle;

  /// 1 when the first-line indent WidgetSpan must be prepended, else 0.
  final int textShift;

  /// Width of the indent WidgetSpan (only used when [textShift] > 0).
  final double? firstLineIndentWidth;
}

/// Data passed to phase 6 (`adjustSpan`) of the pipeline.
class AdjustSpanContext {
  const AdjustSpanContext({
    required this.node,
    required this.span,
    required this.baseTextStyle,
  });

  final Node node;

  /// The root span produced by the previous phases.
  final TextSpan span;

  final TextStyle baseTextStyle;
}
