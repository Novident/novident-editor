import 'dart:math';
import 'dart:ui';

import 'package:novident_editor/novident_editor.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';

typedef TextSpanDecoratorForAttribute = InlineSpan Function(
  BuildContext context,
  Node node,
  int index,
  TextInsert text,
  TextSpan before,
  TextSpan after,
);

typedef NovidentTextSpanDecorator = TextSpan Function(TextSpan textSpan);
typedef NovidentAutoCompleteTextProvider = String? Function(
  BuildContext context,
  Node node,
  TextSpan? textSpan,
);

typedef NovidentTextSpanOverlayBuilder = List<Widget> Function(
  BuildContext context,
  Node node,
  SelectableMixin delegate,
);

//TODO: rich text needs to allow more customization
class NovidentRichText extends StatefulWidget {
  const NovidentRichText({
    super.key,
    this.cursorHeight,
    this.cursorWidth = 2.0,
    this.lineHeight,
    this.textSpanDecorator,
    this.placeholderText = ' ',
    this.placeholderTextSpanDecorator,
    this.textDirection = TextDirection.ltr,
    this.textSpanDecoratorForCustomAttributes,
    this.textSpanOverlayBuilder,
    this.textAlign,
    this.cursorColor = const Color.fromARGB(255, 0, 0, 0),
    this.selectionColor = const Color.fromARGB(53, 111, 201, 231),
    this.autoCompleteTextProvider,
    this.useFirstLineIndent = true,
    required this.delegate,
    required this.node,
    required this.editorState,
  });

  /// The node of the rich text.
  final Node node;

  /// The editor state.
  final EditorState editorState;

  /// The height of the cursor.
  ///
  /// If this is null, the height of the cursor will be calculated automatically.
  final double? cursorHeight;

  /// The width of the cursor.
  final double cursorWidth;

  /// The height of each line.
  final double? lineHeight;

  /// customize the text span for rich text
  final NovidentTextSpanDecorator? textSpanDecorator;

  /// The placeholder text when the rich text is empty.
  final String placeholderText;

  /// customize the text span for placeholder text
  final NovidentTextSpanDecorator? placeholderTextSpanDecorator;

  final TextAlign? textAlign;

  // get the cursor rect, selection rects or block rect from the delegate
  final SelectableMixin delegate;

  // this span will be appended to the current text span, mostly, it is used for auto complete
  final NovidentAutoCompleteTextProvider? autoCompleteTextProvider;

  /// customize the text span for custom attributes
  ///
  /// You can use this to customize the text span for custom attributes
  ///   or override the existing one.
  final TextSpanDecoratorForAttribute? textSpanDecoratorForCustomAttributes;

  /// customize the text span overlay builder
  ///
  /// You can use this to customize the text span overlay, for example, a hover menu in linked text.
  final NovidentTextSpanOverlayBuilder? textSpanOverlayBuilder;

  final TextDirection textDirection;

  final Color cursorColor;
  final Color selectionColor;

  /// When true, prepends a [WidgetSpan] at the start of the text for a
  /// first-line indent effect.
  ///
  /// Set to `false` for blocks that use [NovidentRichText] but are not
  /// normal paragraphs (e.g. quote blocks, callouts) and should not have
  /// the indent applied.
  final bool useFirstLineIndent;

  @override
  State<NovidentRichText> createState() => _NovidentRichTextState();
}

class _NovidentRichTextState extends State<NovidentRichText>
    with SelectableMixin {
  final textKey = GlobalKey();
  final placeholderTextKey = GlobalKey();

  /// Cached state for style resolution. Invalidated when the node's
  /// identity or its `styleRef` / parent table changes.
  String? _nodeId;
  String? _styleRef;
  String? _tableNodeId;
  String? _tableStyleRef;
  NovidentStyleDefinition? _cachedResolvedStyle;
  TextStyle? _cachedBaseTextStyle;
  bool? _cachedInsideTable;
  bool _styleInvalidated = true;

  RenderParagraph? get _renderParagraph =>
      textKey.currentContext?.findRenderObject() as RenderParagraph?;

  RenderParagraph? get _placeholderRenderParagraph =>
      placeholderTextKey.currentContext?.findRenderObject() as RenderParagraph?;

  TextSpanDecoratorForAttribute? get textSpanDecoratorForAttribute =>
      widget.textSpanDecoratorForCustomAttributes ??
      widget.editorState.editorStyle.textSpanDecorator;

  NovidentAutoCompleteTextProvider? get autoCompleteTextProvider =>
      widget.autoCompleteTextProvider ??
      widget.editorState.autoCompleteTextProvider;

  bool get enableAutoComplete =>
      widget.editorState.enableAutoComplete && autoCompleteTextProvider != null;

  TextStyleConfiguration get textStyleConfiguration =>
      widget.editorState.editorStyle.textStyleConfiguration;

  NovidentTextSpanOverlayBuilder? get textSpanOverlayBuilder =>
      widget.textSpanOverlayBuilder ??
      widget.editorState.editorStyle.textSpanOverlayBuilder;

  /// Resolves the effective style for this node.
  ///
  /// When inside a table cell, inherits text formatting properties
  /// (font size, bold, color, alignment, etc.) from the resolved
  /// [NovidentTableStyleDefinition] of the parent table as a fallback.
  /// The cell's own `styleRef` / node type default still takes priority.
  ///
  /// Result is cached until the node identity or `styleRef` changes.
  NovidentStyleDefinition? get resolvedStyle {
    final styleRef = widget.node.attributes['styleRef'] as String?;
    late final Node? cellParentNode;
    final tableNode = widget.node.findParent((Node n) {
      if (n.type == TableCellBlockKeys.type) {
        cellParentNode = n;
      }
      return n.type == TableBlockKeys.type;
    });
    final tableStyleRef = tableNode?.attributes['styleRef'] as String?;

    if (widget.node.id == _nodeId &&
        styleRef == _styleRef &&
        tableNode?.id == _tableNodeId &&
        tableStyleRef == _tableStyleRef) {
      return _cachedResolvedStyle;
    }

    _nodeId = widget.node.id;
    _styleRef = styleRef;
    _tableNodeId = tableNode?.id;
    _tableStyleRef = tableStyleRef;
    _styleInvalidated = true;

    final own =
        NovidentEditorStyles.maybeOf(context)?.resolveStyle(widget.node);

    if (tableNode != null) {
      final tableStyle =
          NovidentEditorStyles.maybeOf(context)?.resolveStyle(tableNode);
      if (tableStyle is NovidentTableStyleDefinition) {
        // Detect if this cell is part of the header row range.
        final cellRow =
            cellParentNode?.attributes[TableCellBlockKeys.rowPosition] as int?;
        final bool isHeader = cellParentNode != null &&
            cellRow != null &&
            tableStyle.headerRowCount > 0 &&
            cellRow < tableStyle.headerRowCount;
        if (own is NovidentTableStyleDefinition) {
          _cachedResolvedStyle = tableStyle.mergeTable(own, isHeader: isHeader);
        } else {
          _cachedResolvedStyle = tableStyle.merge(
            own ?? tableStyle,
            isHeader: isHeader,
          ) as NovidentTableStyleDefinition?;
        }
        return _cachedResolvedStyle;
      }
    }

    _cachedResolvedStyle = own ?? defaultStyle;
    return _cachedResolvedStyle;
  }

  NovidentStyleDefinition? get defaultStyle =>
      NovidentEditorStyles.maybeOf(context)?.config.defaultStyle;

  @override
  void initState() {
    super.initState();
    confirmContextEnabled();
  }

  @override
  Widget build(BuildContext context) {
    Widget child = Stack(
      children: [
        _buildPlaceholderText(context),
        _buildRichText(context),
        ..._buildRichTextOverlay(context),
      ],
    );

    if (enableAutoComplete) {
      final autoCompleteText = _buildAutoCompleteRichText();
      child = Stack(
        children: [
          autoCompleteText,
          child,
        ],
      );
    }

    return BlockSelectionContainer(
      delegate: widget.delegate,
      listenable: widget.editorState.selectionNotifier,
      remoteSelection: widget.editorState.remoteSelections,
      node: widget.node,
      cursorColor: widget.cursorColor,
      selectionColor: widget.selectionColor,
      child: MouseRegion(
        cursor: SystemMouseCursors.text,
        child: child,
      ),
    );
  }

  /// Text alignment resolved by the block component builder.
  TextAlign get _effectiveTextAlign =>
      widget.textAlign ?? resolvedStyle?.alignment ?? TextAlign.start;

  /// Number of WidgetSpans prepended for first-line indent.
  /// Every editor offset must be shifted by this amount when translating
  /// to/from [TextPosition] offsets in the [RenderParagraph].
  ///
  /// Returns 0 when:
  /// - [NovidentRichText.useFirstLineIndent] is false,
  /// - no valid indent width is resolved, or
  /// - the node is inside a table cell.
  /// Whether this node lives inside a table cell. Cached by node id.
  bool get _isInsideTable {
    if (_cachedInsideTable == null || widget.node.id != _nodeId) {
      _cachedInsideTable =
          widget.node.findParent((n) => n.type == TableBlockKeys.type) != null;
      _nodeId = widget.node.id;
    }
    return _cachedInsideTable!;
  }

  int get _widgetSpanCount {
    if (!widget.useFirstLineIndent ||
        _firstLineIndentWidth == null ||
        _firstLineIndentWidth! <= 0) {
      return 0;
    }
    if (_isInsideTable) return 0;
    return 1;
  }

  /// Resolved first-line indent width, or `null` if no indent should be
  /// applied.
  ///
  /// Resolution order:
  /// 1. Style's own [NovidentStyleIndent.firstLineIndent] if defined.
  /// 2. Global [EditorStyle.firstLineIndent] if the style's
  ///    [NovidentStyleDefinition.allowGlobalFirstLineIndent] is `true`.
  /// 3. `null` otherwise.
  double? get _firstLineIndentWidth {
    final style = resolvedStyle;
    if (style == null) return null;
    if (style.indent?.shouldFilterLineIndent?.call(widget.node) ?? false) {
      return null;
    }
    final styleIndent = style.indent?.firstLineIndent;
    if (styleIndent != null && styleIndent > 0) {
      return styleIndent;
    }

    if (style.allowGlobalFirstLineIndent) {
      final globalIndent = widget.editorState.editorStyle.firstLineIndent;
      if (globalIndent != null && globalIndent > 0) {
        return globalIndent;
      }
    }

    return null;
  }

  Widget _buildPlaceholderText(BuildContext context) {
    var textSpan = getPlaceholderTextSpan();
    if (widget.placeholderTextSpanDecorator != null) {
      textSpan = widget.placeholderTextSpanDecorator!(textSpan);
    }
    textSpan = adjustTextSpan(textSpan);
    final delta = widget.node.delta;
    if (delta != null && delta.isNotEmpty) {
      // Preserve WidgetSpans for indent layout, clear visible text.
      final preservedChildren = <InlineSpan>[
        for (final child in textSpan.children ?? <InlineSpan>[])
          if (child is WidgetSpan)
            child
          else if (child is TextSpan)
            child.copyWith(text: ''),
      ];
      textSpan = TextSpan(
        children: preservedChildren,
        style: textSpan.style,
      );
    }
    return RichText(
      key: placeholderTextKey,
      textAlign: _effectiveTextAlign,
      textHeightBehavior: TextHeightBehavior(
        applyHeightToFirstAscent:
            textStyleConfiguration.applyHeightToFirstAscent,
        applyHeightToLastDescent:
            textStyleConfiguration.applyHeightToLastDescent,
        leadingDistribution: textStyleConfiguration.leadingDistribution,
      ),
      text: textSpan,
      textDirection: textDirection(),
      textScaler: TextScaler.linear(
        widget.editorState.editorStyle.textScaleFactor,
      ),
      overflow: TextOverflow.ellipsis,
    );
  }

  Widget _buildRichText(BuildContext context) {
    final textInserts = widget.node.delta!.whereType<TextInsert>();
    TextSpan textSpan = getTextSpan(textInserts: textInserts);
    if (widget.textSpanDecorator != null) {
      textSpan = widget.textSpanDecorator!(textSpan);
    }
    textSpan = adjustTextSpan(textSpan);
    return RichText(
      key: textKey,
      textAlign: _effectiveTextAlign,
      strutStyle: resolvedStyle?.spacing != null &&
              resolvedStyle?.spacing?.hanging != null
          ? StrutStyle(
              leading: resolvedStyle!.spacing!.hanging!,
              leadingDistribution: TextLeadingDistribution.proportional,
            )
          : null,
      textHeightBehavior: TextHeightBehavior(
        applyHeightToFirstAscent:
            textStyleConfiguration.applyHeightToFirstAscent,
        applyHeightToLastDescent:
            textStyleConfiguration.applyHeightToLastDescent,
      ),
      text: textSpan,
      textDirection: textDirection(),
      textScaler:
          TextScaler.linear(widget.editorState.editorStyle.textScaleFactor),
    );
  }

  List<Widget> _buildRichTextOverlay(BuildContext context) {
    if (textKey.currentContext == null) return [];
    return textSpanOverlayBuilder?.call(
          context,
          widget.node,
          this,
        ) ??
        [];
  }

  void confirmContextEnabled() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted && textKey.currentContext == null) {
        confirmContextEnabled();
      } else if (mounted && textKey.currentContext != null) {
        setState(() {});
      }
    });
  }

  Widget _buildAutoCompleteRichText() {
    final textInserts = widget.node.delta!.whereType<TextInsert>();
    TextSpan textSpan = getTextSpan(textInserts: textInserts);
    if (widget.textSpanDecorator != null) {
      textSpan = widget.textSpanDecorator!(textSpan);
    }
    textSpan = adjustTextSpan(textSpan);
    return ValueListenableBuilder(
      valueListenable: widget.editorState.selectionNotifier,
      builder: (_, __, ___) {
        final autoCompleteText = autoCompleteTextProvider?.call(
          context,
          widget.node,
          textSpan,
        );
        if (autoCompleteText == null || autoCompleteText.isEmpty) {
          return const SizedBox.shrink();
        }
        textSpan = getTextSpan(
          textInserts: [
            ...textInserts.map(
              (e) => TextInsert(
                e.text,
                attributes: {
                  NovidentRichTextKeys.transparent: true,
                },
              ),
            ),
            TextInsert(
              autoCompleteText,
              attributes: {
                NovidentRichTextKeys.autoComplete: true,
              },
            ),
          ],
        );
        return RichText(
          textAlign: _effectiveTextAlign,
          textHeightBehavior: TextHeightBehavior(
            applyHeightToFirstAscent:
                textStyleConfiguration.applyHeightToFirstAscent,
            applyHeightToLastDescent:
                textStyleConfiguration.applyHeightToLastDescent,
            leadingDistribution: textStyleConfiguration.leadingDistribution,
          ),
          text: textSpan,
          textDirection: textDirection(),
          textScaler:
              TextScaler.linear(widget.editorState.editorStyle.textScaleFactor),
        );
      },
    );
  }

  // https://github.com/flutter/flutter/pull/143954
  // https://github.com/AppFlowy-IO/appflowy-editor/issues/819#issuecomment-2177833413
  // This is a workaround for the issue that
  //  the caret height of the text is not calculated correctly if the parent style is null.
  TextSpan adjustTextSpan(TextSpan textSpan) {
    if (textSpan.style == null && textSpan.children != null) {
      double height = 0.0;
      double fontSize = 0.0;
      textSpan.visitChildren((span) {
        final style = span.style;
        if (style != null) {
          if (style.height != null) {
            height = max(height, style.height!);
          }
          if (style.fontSize != null) {
            fontSize = max(fontSize, style.fontSize!);
          }
        }
        return true;
      });
      if (height == 0.0 || fontSize == 0.0) {
        return textSpan;
      }
      textSpan = textSpan.copyWith(
        style: textStyleConfiguration.text.copyWith(
          height: height,
          fontSize: fontSize,
        ),
      );
    }
    return textSpan;
  }

  TextSpan getPlaceholderTextSpan() {
    final children = <InlineSpan>[
      if (_widgetSpanCount > 0)
        WidgetSpan(child: SizedBox(width: _firstLineIndentWidth)),
      TextSpan(
        text: widget.placeholderText,
        style: textStyleConfiguration.text.copyWith(
          height: textStyleConfiguration.lineHeight,
        ),
      ),
    ];
    return TextSpan(children: children);
  }

  /// Resolved base [TextStyle] from the effective style.
  /// Cached until the resolved style or text configuration changes.
  TextStyle get _baseTextStyle {
    if (!_styleInvalidated && _cachedBaseTextStyle != null) {
      return _cachedBaseTextStyle!;
    }
    _styleInvalidated = false;
    _cachedBaseTextStyle = _buildBaseTextStyle();
    return _cachedBaseTextStyle!;
  }

  TextStyle _buildBaseTextStyle() {
    final resolved = resolvedStyle;
    TextStyle style = textStyleConfiguration.text.copyWith(
      height:
          resolved?.spacing?.lineHeight ?? textStyleConfiguration.lineHeight,
    );
    if (resolved == null) return style;

    final resolvedTextStyle = TextStyle(
      fontSize: resolved.fontSize,
      fontWeight: resolved.bold ? FontWeight.bold : null,
      fontStyle: resolved.italic ? FontStyle.italic : null,
      decoration: TextDecoration.combine([
        if (resolved.overline) TextDecoration.overline,
        if (resolved.underline) TextDecoration.underline,
        if (resolved.strikethrough) TextDecoration.lineThrough,
      ]),
      fontFamily: resolved.fontFamily,
      color: resolved.textColor,
      backgroundColor: resolved.textBackgroundColor,
      decorationStyle: resolved.decorationStyle,
      letterSpacing: resolved.letterSpacing,
      wordSpacing: resolved.wordSpacing,
      fontVariations: resolved.fontVariations,
      shadows: resolved.fontShadows,
      foreground: resolved.fontForeground,
      background: resolved.fontBackground,
      fontFeatures: resolved.fontFeatures,
      decorationColor: resolved.decorationColor,
    );
    return style.merge(resolvedTextStyle);
  }

  TextSpan getTextSpan({
    required Iterable<TextInsert> textInserts,
  }) {
    int offset = 0;
    List<InlineSpan> textSpans = [];
    if (_widgetSpanCount > 0) {
      textSpans.add(
        WidgetSpan(child: SizedBox(width: _firstLineIndentWidth)),
      );
    }

    for (final textInsert in textInserts) {
      TextStyle textStyle = _baseTextStyle;
      final Attributes? attributes = textInsert.attributes;
      if (attributes != null) {
        if (attributes.bold == true) {
          textStyle = textStyle.combine(textStyleConfiguration.bold);
        }
        if (attributes.italic == true) {
          textStyle = textStyle.combine(textStyleConfiguration.italic);
        }
        if (attributes.underline == true) {
          textStyle = textStyle.combine(textStyleConfiguration.underline);
        }
        if (attributes.strikethrough == true) {
          textStyle = textStyle.combine(textStyleConfiguration.strikethrough);
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
      }

      String displayText = textInsert.text;
      if (resolvedStyle?.caps == true) {
        displayText = displayText.toUpperCase();
        // by now we set small caps just as lowercase
      } else if (resolvedStyle?.smallCaps == true) {
        displayText = displayText.toLowerCase();
      }

      final textSpan = TextSpan(
        text: displayText,
        style: textStyle,
      );
      textSpans.add(
        textSpanDecoratorForAttribute != null
            ? textSpanDecoratorForAttribute!(
                context,
                widget.node,
                offset,
                textInsert,
                textSpan,
                widget.textSpanDecorator?.call(textSpan) ?? textSpan,
              )
            : textSpan,
      );
      offset += textInsert.length;
    }
    return TextSpan(
      children: textSpans,
    );
  }

  @override
  Position start() => Position(path: widget.node.path, offset: 0);

  @override
  Position end() => Position(
        path: widget.node.path,
        offset: widget.node.delta?.toPlainText().length ?? 0,
      );

  @override
  Rect getBlockRect({
    bool shiftWithBaseOffset = false,
  }) {
    throw UnimplementedError();
  }

  @override
  Rect? getCursorRectInPosition(
    Position position, {
    bool shiftWithBaseOffset = false,
  }) {
    // both paragraphs are queried below (the placeholder one drives the
    // caret of empty lines): bail out if either still needs layout.
    if (kDebugMode &&
        (_renderParagraph?.debugNeedsLayout == true ||
            _placeholderRenderParagraph?.debugNeedsLayout == true)) {
      return null;
    }

    final delta = widget.node.delta;
    if (position.offset < 0 ||
        (delta != null && position.offset > delta.length)) {
      return null;
    }

    final textPosition = TextPosition(
      offset: position.offset + _widgetSpanCount,
    );
    double? placeholderCursorHeight =
        _placeholderRenderParagraph?.getFullHeightForCaret(textPosition);
    Offset? placeholderCursorOffset =
        _placeholderRenderParagraph?.getOffsetForCaret(
              textPosition,
              Rect.zero,
            ) ??
            Offset.zero;
    if (textDirection() == TextDirection.rtl) {
      if (widget.placeholderText.trim().isNotEmpty) {
        placeholderCursorOffset = placeholderCursorOffset.translate(
          _placeholderRenderParagraph?.size.width ?? 0,
          0,
        );
      }
    }

    double? cursorHeight =
        _renderParagraph?.getFullHeightForCaret(textPosition);
    Offset? cursorOffset =
        _renderParagraph?.getOffsetForCaret(textPosition, Rect.zero) ??
            Offset.zero;

    if (placeholderCursorHeight != null) {
      cursorHeight = max(cursorHeight ?? 0, placeholderCursorHeight);
    }

    if (delta?.isEmpty == true) {
      cursorOffset = placeholderCursorOffset;
    }

    if (widget.cursorHeight != null && cursorHeight != null) {
      cursorOffset = Offset(
        cursorOffset.dx,
        cursorOffset.dy + (cursorHeight - widget.cursorHeight!) / 2,
      );
      cursorHeight = widget.cursorHeight;
    }
    final rect = Rect.fromLTWH(
      max(0, cursorOffset.dx - (widget.cursorWidth / 2.0)),
      cursorOffset.dy,
      widget.cursorWidth,
      cursorHeight ?? 16.0,
    );
    return rect;
  }

  @override
  Position getPositionInOffset(Offset start) {
    final offset = _renderParagraph?.globalToLocal(start) ?? Offset.zero;
    final rawOffset =
        _renderParagraph?.getPositionForOffset(offset).offset ?? -1;
    final baseOffset = (rawOffset - _widgetSpanCount).clamp(0, rawOffset);
    return Position(path: widget.node.path, offset: baseOffset);
  }

  /// Moves the caret one visual line up or down within this text node
  /// using the [RenderParagraph]'s local coordinate system. Because
  /// local coordinates are unaffected by scroll position, this method
  /// is completely scroll-independent and viewport-independent.
  ///
  /// Returns `null` when the caret is at the first/last visual line —
  /// the caller should navigate to the adjacent document node.
  @override
  Position? moveVerticallyInText(int currentOffset, bool upwards) {
    final rp = _renderParagraph;
    if (rp == null || !rp.hasSize) return null;

    final delta = widget.node.delta;
    if (delta == null) return null;

    final textLen = delta.length;
    if (currentOffset < 0 || currentOffset > textLen) return null;

    // 1. Get the CURRENT caret position in LOCAL coordinates.
    //    This is scroll-independent — local coords are relative to
    //    the RenderParagraph, not the viewport.
    final textPosition = TextPosition(
      offset: currentOffset + _widgetSpanCount,
    );
    final caretLocal = rp.getOffsetForCaret(textPosition, Rect.zero);

    // 2. Estimate line height from the glyph at the current position.
    //    Uses the strut-bounded height which accounts for font metrics.
    final lineHeight = rp.getFullHeightForCaret(textPosition);
    if (lineHeight <= 0) return null;

    // 3. Try to move one estimated line up/down, preserving the
    //    horizontal column (caretLocal.dx).
    Offset targetLocal = Offset(
      caretLocal.dx,
      caretLocal.dy + (upwards ? -lineHeight : lineHeight),
    );

    // Clamp Y to stay within the paragraph's content area so we
    // don't query beyond the rendered text.
    targetLocal = Offset(
      targetLocal.dx,
      targetLocal.dy.clamp(0.0, rp.size.height),
    );

    final textPos = rp.getPositionForOffset(targetLocal);
    final newOffset =
        (textPos.offset - _widgetSpanCount).clamp(0, textLen);

    // 4. If the offset changed, we successfully moved to another line.
    if (newOffset != currentOffset) {
      return Position(path: widget.node.path, offset: newOffset);
    }

    // 5. preferredLineHeight may have over/under-estimated for mixed
    //    fonts. Try a half-step in the same direction before giving up.
    final halfTarget = Offset(
      caretLocal.dx,
      caretLocal.dy + (upwards ? -lineHeight / 2 : lineHeight / 2),
    ).translate(0.0, 0.0);
    final clampedHalf = Offset(
      halfTarget.dx,
      halfTarget.dy.clamp(0.0, rp.size.height),
    );
    final halfPos = rp.getPositionForOffset(clampedHalf);
    final halfOffset =
        (halfPos.offset - _widgetSpanCount).clamp(0, textLen);

    if (halfOffset != currentOffset) {
      return Position(path: widget.node.path, offset: halfOffset);
    }

    // 6. Still the same offset → we're at the visual boundary.
    return null;
  }

  @override
  double? getCaretLocalDx(int offset) {
    final rp = _renderParagraph;
    if (rp == null) return null;
    final tp = TextPosition(offset: offset + _widgetSpanCount);
    return rp.getOffsetForCaret(tp, Rect.zero).dx;
  }

  @override
  Selection? getWordEdgeInOffset(Offset offset) {
    final localOffset = _renderParagraph?.globalToLocal(offset) ?? Offset.zero;
    final rawTextPosition =
        _renderParagraph?.getPositionForOffset(localOffset) ??
            const TextPosition(offset: 0);
    // Shift past the WidgetSpan so getWordBoundary operates on real text.
    final shiftedTextPosition = TextPosition(
      offset: rawTextPosition.offset
          .clamp(_widgetSpanCount, rawTextPosition.offset),
      affinity: rawTextPosition.affinity,
    );
    final textRange = _renderParagraph?.getWordBoundary(shiftedTextPosition) ??
        TextRange.empty;
    final wordEdgeOffset = shiftedTextPosition.offset <= textRange.start
        ? textRange.start
        : textRange.end;

    return Selection.collapsed(
      Position(
        path: widget.node.path,
        offset: wordEdgeOffset - _widgetSpanCount,
      ),
    );
  }

  @override
  Selection? getWordBoundaryInOffset(Offset offset) {
    final localOffset = _renderParagraph?.globalToLocal(offset) ?? Offset.zero;
    final rawTextPosition =
        _renderParagraph?.getPositionForOffset(localOffset) ??
            const TextPosition(offset: 0);
    // Shift past the WidgetSpan so getWordBoundary operates on real text.
    final shiftedTextPosition = TextPosition(
      offset: rawTextPosition.offset
          .clamp(_widgetSpanCount, rawTextPosition.offset),
      affinity: rawTextPosition.affinity,
    );
    final textRange = _renderParagraph?.getWordBoundary(shiftedTextPosition) ??
        TextRange.empty;
    final start = Position(
      path: widget.node.path,
      offset: textRange.start - _widgetSpanCount,
    );
    final end = Position(
      path: widget.node.path,
      offset: textRange.end - _widgetSpanCount,
    );
    return Selection(start: start, end: end);
  }

  @override
  Selection? getWordBoundaryInPosition(Position position) {
    final textPosition =
        TextPosition(offset: position.offset + _widgetSpanCount);
    final textRange =
        _renderParagraph?.getWordBoundary(textPosition) ?? TextRange.empty;
    final start = Position(
      path: widget.node.path,
      offset: textRange.start - _widgetSpanCount,
    );
    final end = Position(
      path: widget.node.path,
      offset: textRange.end - _widgetSpanCount,
    );
    return Selection(start: start, end: end);
  }

  @override
  List<Rect> getRectsInSelection(
    Selection selection, {
    bool shiftWithBaseOffset = false,
    RenderParagraph? paragraph,
  }) {
    paragraph ??= _renderParagraph;
    if (kDebugMode && paragraph?.debugNeedsLayout == true) {
      return [];
    }
    final textSelection = textSelectionFromEditorSelection(selection);
    if (textSelection == null) {
      return [];
    }
    final rects = paragraph
        ?.getBoxesForSelection(
          textSelection,
          boxHeightStyle: BoxHeightStyle.max,
        )
        .map((box) => box.toRect())
        .toList(growable: false);
    if (rects == null || rects.isEmpty) {
      /// If the rich text widget does not contain any text,
      /// there will be no selection boxes,
      /// so we need to return to the default selection.
      Offset position = Offset.zero;
      double height = paragraph?.size.height ?? 0.0;
      double width = 0;
      if (!selection.isCollapsed) {
        /// while selecting for an empty character, return a selection area
        /// with width of 2
        final textPosition = TextPosition(offset: textSelection.baseOffset);
        position = paragraph?.getOffsetForCaret(
              textPosition,
              Rect.zero,
            ) ??
            position;
        height = paragraph?.getFullHeightForCaret(textPosition) ?? height;
        width = 2;
      }
      return [
        Rect.fromLTWH(position.dx, position.dy, width, height),
      ];
    }
    return rects;
  }

  @override
  Selection getSelectionInRange(Offset start, Offset end) {
    final delta = widget.node.delta;
    if (delta == null) {
      return Selection.single(
        path: widget.node.path,
        startOffset: 0,
        endOffset: 0,
      );
    }
    final localStart = _renderParagraph?.globalToLocal(start) ?? Offset.zero;
    final localEnd = _renderParagraph?.globalToLocal(end) ?? Offset.zero;
    final rawBase =
        _renderParagraph?.getPositionForOffset(localStart).offset ?? -1;
    final rawExtent =
        _renderParagraph?.getPositionForOffset(localEnd).offset ?? -1;
    final baseOffset = (rawBase - _widgetSpanCount).clamp(0, rawBase);
    final extentOffset = (rawExtent - _widgetSpanCount).clamp(0, rawExtent);
    return Selection.single(
      path: widget.node.path,
      startOffset: baseOffset,
      endOffset: extentOffset,
    );
  }

  @override
  Offset localToGlobal(
    Offset offset, {
    bool shiftWithBaseOffset = false,
  }) {
    return _renderParagraph?.localToGlobal(offset) ?? Offset.zero;
  }

  @override
  TextDirection textDirection() {
    return widget.textDirection;
  }

  TextSelection? textSelectionFromEditorSelection(Selection? selection) {
    if (selection == null) {
      return null;
    }

    final normalized = selection.normalized;
    final path = widget.node.path;
    if (path < normalized.start.path || path > normalized.end.path) {
      return null;
    }

    final length = widget.node.delta?.length;
    if (length == null) {
      return null;
    }

    TextSelection? textSelection;

    if (normalized.isSingle) {
      if (path.equals(normalized.start.path)) {
        if (normalized.isCollapsed) {
          textSelection = TextSelection.collapsed(
            offset: normalized.startIndex + _widgetSpanCount,
          );
        } else {
          textSelection = TextSelection(
            baseOffset: normalized.startIndex + _widgetSpanCount,
            extentOffset: normalized.endIndex + _widgetSpanCount,
          );
        }
      }
    } else {
      if (path.equals(normalized.start.path)) {
        textSelection = TextSelection(
          baseOffset: normalized.startIndex + _widgetSpanCount,
          extentOffset: length + _widgetSpanCount,
        );
      } else if (path.equals(normalized.end.path)) {
        textSelection = TextSelection(
          baseOffset: _widgetSpanCount,
          extentOffset: normalized.endIndex + _widgetSpanCount,
        );
      } else {
        textSelection = TextSelection(
          baseOffset: _widgetSpanCount,
          extentOffset: length + _widgetSpanCount,
        );
      }
    }
    return textSelection;
  }
}

extension NovidentRichTextAttributes on Attributes {
  bool get bold => this[NovidentRichTextKeys.bold] == true;

  bool get italic => this[NovidentRichTextKeys.italic] == true;

  bool get underline => this[NovidentRichTextKeys.underline] == true;

  bool get code => this[NovidentRichTextKeys.code] == true;

  bool get strikethrough {
    return (containsKey(NovidentRichTextKeys.strikethrough) &&
        this[NovidentRichTextKeys.strikethrough] == true);
  }

  Color? get color {
    final textColor = this[NovidentRichTextKeys.textColor] as String?;
    return textColor?.tryToColor();
  }

  Color? get backgroundColor {
    final highlightColor =
        this[NovidentRichTextKeys.backgroundColor] as String?;
    return highlightColor?.tryToColor();
  }

  Color? get findBackgroundColor {
    final findBackgroundColor =
        this[NovidentRichTextKeys.findBackgroundColor] as String?;
    return findBackgroundColor?.tryToColor();
  }

  String? get href {
    if (this[NovidentRichTextKeys.href] is String) {
      return this[NovidentRichTextKeys.href];
    }
    return null;
  }

  String? get fontFamily {
    if (this[NovidentRichTextKeys.fontFamily] is String) {
      return this[NovidentRichTextKeys.fontFamily];
    }
    return null;
  }

  double? get fontSize {
    if (this[NovidentRichTextKeys.fontSize] is double) {
      return this[NovidentRichTextKeys.fontSize];
    }
    return null;
  }

  bool get autoComplete => this[NovidentRichTextKeys.autoComplete] == true;

  bool get transparent => this[NovidentRichTextKeys.transparent] == true;
}
