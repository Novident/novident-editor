import 'dart:math';
import 'dart:ui' as ui;

import 'package:novident_editor_document/novident_editor_document.dart';
import 'package:novident_editor_core/novident_editor_core.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart' hide RichText, TextPainter;
import 'package:novident_editor_rich_text/novident_editor_rich_text.dart';
import 'package:novident_editor_rich_text/src/utils/text_selection_from_node_selection.dart';
import 'package:novident_editor_selection/novident_editor_selection.dart';
import 'package:novident_editor_styles/novident_editor_styles.dart';

//TODO: rich text needs to allow more customization
class NovidentRichText extends StatefulWidget {
  const NovidentRichText({
    super.key,
    this.cursorHeight,
    this.cursorWidth = 2.0,
    this.textSpanDecorator,
    this.placeholderText = ' ',
    this.placeholderTextSpanDecorator,
    this.textDirection = TextDirection.ltr,
    this.textSpanDecoratorForCustomAttributes,
    this.textSpanOverlayBuilder,
    this.textAlign,
    this.cursorColor = const Color.fromARGB(255, 0, 0, 0),
    this.selectionColor = const Color.fromARGB(255, 111, 201, 231),
    this.autoCompleteTextProvider,
    this.useFirstLineIndent = true,
    required this.delegate,
    required this.node,
    required this.editorConfig,
  });

  /// The node of the rich text.
  final Node node;

  /// The editor configuration.
  final RichTextEditorConfig editorConfig;

  /// The height of the cursor.
  ///
  /// If this is null, the height of the cursor will be calculated automatically.
  final double? cursorHeight;

  /// The width of the cursor.
  final double cursorWidth;

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
  bool _hasSelection = false;
  (int, int)? _selectionRange;

  RenderParagraph? get _renderParagraph =>
      textKey.currentContext?.findRenderObject() as RenderParagraph?;

  @override
  RenderParagraph? getRenderParagraph() =>
      _renderParagraph ?? _placeholderRenderParagraph;

  RenderParagraph? get _placeholderRenderParagraph =>
      placeholderTextKey.currentContext?.findRenderObject() as RenderParagraph?;

  TextSpanDecoratorForAttribute? get textSpanDecoratorForAttribute =>
      widget.textSpanDecoratorForCustomAttributes ??
      widget.editorConfig.textSpanDecorator;

  NovidentAutoCompleteTextProvider? get autoCompleteTextProvider =>
      widget.autoCompleteTextProvider ??
      widget.editorConfig.autoCompleteTextProvider;

  bool get enableAutoComplete =>
      widget.editorConfig.enableAutoComplete &&
      autoCompleteTextProvider != null;

  TextStyleConfiguration get textStyleConfiguration =>
      widget.editorConfig.textStyleConfiguration;

  NovidentTextSpanOverlayBuilder? get textSpanOverlayBuilder =>
      widget.textSpanOverlayBuilder ??
      widget.editorConfig.textSpanOverlayBuilder;

  NovidentStyleDefinition? get defaultStyle =>
      NovidentEditorStyles.maybeOf(context)?.config.defaultStyle;

  @override
  void initState() {
    super.initState();
    confirmContextEnabled();
    widget.editorConfig.selectionNotifier.addListener(_onSelectionChanged);
    _syncSelectionState();
  }

  @override
  void dispose() {
    super.dispose();
    widget.editorConfig.selectionNotifier.removeListener(_onSelectionChanged);
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
      listenable: widget.editorConfig.selectionNotifier,
      host: widget.editorConfig,
      renderer: widget.editorConfig.selectionRenderer,
      remoteSelection: widget.editorConfig.remoteSelections,
      node: widget.node,
      cursorColor: widget.cursorColor,
      selectionColor: widget.selectionColor,
      child: MouseRegion(
        cursor: SystemMouseCursors.text,
        child: child,
      ),
    );
  }

  void _onSelectionChanged() {
    if (!mounted) return;

    final selection = widget.editorConfig.selectionNotifier.value;
    final bool nowInSelection = selection != null &&
        !selection.isCollapsed &&
        widget.node.inSelection(selection);

    (int, int)? newRange;
    if (nowInSelection) {
      newRange = _rangeForSelection(selection);
    }

    if (_hasSelection != nowInSelection || _selectionRange != newRange) {
      _hasSelection = nowInSelection;
      _selectionRange = newRange;
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) setState(() {});
      });
    }
  }

  /// Computes `(selStart, selEnd)` for this node from a *normalized*
  /// selection. Returns `null` when the node is not in the selection.
  (int, int) _rangeForSelection(Selection selection) {
    final norm = selection.normalized;
    final nodePath = widget.node.path;
    final nodeLen = widget.node.delta?.length ?? 0;

    if (nodePath.equals(norm.start.path) && nodePath.equals(norm.end.path)) {
      return (norm.start.offset, norm.end.offset);
    }
    if (nodePath.equals(norm.start.path)) {
      return (norm.start.offset, nodeLen);
    }
    if (nodePath.equals(norm.end.path)) {
      return (0, norm.end.offset);
    }
    return (0, nodeLen);
  }

  /// Syncs [_hasSelection] and [_selectionRange] from the current selection
  /// value without scheduling a rebuild (called during [initState] before the
  /// first build).
  void _syncSelectionState() {
    final selection = widget.editorConfig.selectionNotifier.value;
    if (selection != null &&
        !selection.isCollapsed &&
        widget.node.inSelection(selection)) {
      _hasSelection = true;
      _selectionRange = _rangeForSelection(selection);
    } else {
      _hasSelection = false;
      _selectionRange = null;
    }
  }

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

    final registry = NovidentEditorStyles.maybeOf(
      context,
    );
    final own = registry?.resolveStyle(widget.node);

    if (tableNode != null) {
      final tableStyle = registry?.resolveStyle(
        tableNode,
      );
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

  @override
  int get textShift {
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
      final globalIndent = widget.editorConfig.firstLineIndentFallback;
      if (globalIndent != null && globalIndent > 0) {
        return globalIndent;
      }
    }

    return null;
  }

  Widget _buildPlaceholderText(BuildContext context) {
    final textInserts = widget.node.delta?.whereType<TextInsert>();
    if (textInserts != null && textInserts.isNotEmpty) {
      return const SizedBox.shrink();
    }
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
        widget.editorConfig.textScaleFactor,
      ),
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
        widget.editorConfig.textScaleFactor,
      ),
    );
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
    if (textInserts.isEmpty) {
      return const SizedBox.shrink();
    }
    TextSpan textSpan = getTextSpan(textInserts: textInserts);
    if (widget.textSpanDecorator != null) {
      textSpan = widget.textSpanDecorator!(textSpan);
    }
    textSpan = adjustTextSpan(textSpan);
    return ValueListenableBuilder(
      valueListenable: widget.editorConfig.selectionNotifier,
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
                  RichTextKeys.transparent: true,
                },
              ),
            ),
            TextInsert(
              autoCompleteText,
              attributes: {
                RichTextKeys.autoComplete: true,
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
          textScaler: TextScaler.linear(widget.editorConfig.textScaleFactor),
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
        // used to maintain legacy compatibility
        style: widget.node.type == HeadingBlockKeys.type
            ? TextStyle(
                height: height,
                fontSize: fontSize,
              )
            : _baseTextStyle,
      );
    }
    return textSpan;
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

  TextSpan getPlaceholderTextSpan() {
    final children = <InlineSpan>[
      if (textShift > 0)
        WidgetSpan(child: SizedBox(width: _firstLineIndentWidth)),
      TextSpan(
        text: widget.placeholderText,
        style: _baseTextStyle.copyWith(
            color: _baseTextStyle.color?.withAlpha(150)),
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
    TextStyle style = TextStyle(
      fontSize: kDefaultBaseStyle.fontSize,
      fontFamily: kDefaultBaseStyle.fontFamily,
      color: kDefaultBaseStyle.textColor,
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
      height: resolved.spacing?.lineHeight,
    );
    return style.merge(resolvedTextStyle);
  }

  TextSpan getTextSpan({
    required Iterable<TextInsert> textInserts,
  }) {
    int offset = 0;
    List<InlineSpan> textSpans = [];
    if (textShift > 0) {
      textSpans.add(
        WidgetSpan(child: SizedBox(width: _firstLineIndentWidth)),
      );
    }

    final selStart = _selectionRange?.$1 ?? 0;
    final selEnd = _selectionRange?.$2 ?? 0;

    for (final textInsert in textInserts) {
      TextStyle textStyle = _baseTextStyle;
      final Attributes? attributes = textInsert.attributes;
      if (attributes != null) {
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
      }

      String displayText = textInsert.text;
      if (resolvedStyle?.caps == true) {
        displayText = displayText.toUpperCase();
        // by now we set small caps just as lowercase
      } else if (resolvedStyle?.smallCaps == true) {
        displayText = displayText.toLowerCase();
      }

      final textLen = displayText.length;

      final inserted = paintContrastColorForSelection(
        context,
        widget.node,
        textInsert,
        offset,
        textLen,
        selStart,
        selEnd,
        textSpans,
        displayText,
        textSpanDecoratorForAttribute: textSpanDecoratorForAttribute,
        textSpanDecorator: widget.textSpanDecorator,
        hasSelection: _hasSelection,
        textStyle: textStyle,
        textStyleConfiguration: textStyleConfiguration,
        selectionColor: widget.selectionColor,
      );

      if (inserted) {
        offset += textLen;
        continue;
      }

      // Default: no selection intersection — emit the full span as-is.
      textSpans.add(emitSpan(
        textInsert,
        displayText,
        textStyle,
        offset,
        context,
        widget.node,
        textSpanDecoratorForAttribute,
        widget.textSpanDecorator,
      ));
      offset += textLen;
    }
    return TextSpan(
      children: textSpans,
    );
  }

  static InlineSpan emitSpan(
    TextInsert insert,
    String text,
    TextStyle style,
    int spanOffset,
    BuildContext context,
    Node node,
    TextSpanDecoratorForAttribute? textSpanDecoratorForAttribute,
    NovidentTextSpanDecorator? textSpanDecorator,
  ) {
    final span = TextSpan(text: text, style: style);
    if (textSpanDecoratorForAttribute != null) {
      return textSpanDecoratorForAttribute(
        context,
        node,
        spanOffset,
        insert,
        span,
        textSpanDecorator?.call(span) ?? span,
      );
    }
    return span;
  }

  static bool paintContrastColorForSelection(
    BuildContext context,
    Node node,
    TextInsert textInsert,
    int offset,
    int textLen,
    int selStart,
    int selEnd,
    List<InlineSpan> textSpans,
    String displayText, {
    TextSpanDecoratorForAttribute? textSpanDecoratorForAttribute,
    NovidentTextSpanDecorator? textSpanDecorator,
    required bool hasSelection,
    required TextStyle textStyle,
    required TextStyleConfiguration textStyleConfiguration,
    required Color selectionColor,
  }) {
    if (!hasSelection) {
      return false;
    }
    final blockBg = textStyle.backgroundColor ?? Colors.white;
    final decorationColor = textStyle.decorationColor ??
        textStyleConfiguration.href.decorationColor ??
        textStyleConfiguration.href.color;
    final effectiveBg = Color.alphaBlend(
      selectionColor,
      blockBg,
    );
    final effectiveDecorationColor = decorationColor == null
        ? null
        : Color.alphaBlend(
            selectionColor,
            decorationColor,
          );
    final contrastColor =
        effectiveBg.computeLuminance() > 0.5 ? Colors.black : Colors.white;
    final decorationContrastColor = effectiveDecorationColor == null
        ? null
        : effectiveDecorationColor.computeLuminance() > 0.5
            ? Colors.black
            : Colors.white;
    final int textStart = offset;
    final int textEnd = offset + textLen;
    final int intersectStart = max(textStart, selStart);
    final int intersectEnd = min(textEnd, selEnd);
    if (intersectStart < intersectEnd) {
      // Before selection — normal color.
      if (textStart < intersectStart) {
        final beforeLen = intersectStart - textStart;
        final beforeText = displayText.substring(0, beforeLen);
        textSpans.add(emitSpan(
          TextInsert(beforeText, attributes: textInsert.attributes),
          beforeText,
          textStyle,
          offset,
          context,
          node,
          textSpanDecoratorForAttribute,
          textSpanDecorator,
        ));
      }
      // Inside selection — contrast color.
      final selPieceStart = intersectStart - textStart;
      final selPieceEnd = intersectEnd - textStart;
      final selText = displayText.substring(selPieceStart, selPieceEnd);
      textSpans.add(emitSpan(
        TextInsert(selText, attributes: textInsert.attributes),
        selText,
        textStyle.copyWith(
          color: contrastColor,
          decorationColor: decorationContrastColor,
        ),
        offset + selPieceStart,
        context,
        node,
        textSpanDecoratorForAttribute,
        textSpanDecorator,
      ));
      // After selection — normal color.
      if (intersectEnd < textEnd) {
        final afterStart = intersectEnd - textStart;
        final afterText = displayText.substring(afterStart);
        textSpans.add(emitSpan(
          TextInsert(afterText, attributes: textInsert.attributes),
          afterText,
          textStyle,
          offset + afterStart,
          context,
          node,
          textSpanDecoratorForAttribute,
          textSpanDecorator,
        ));
      }
      return true;
    }
    return false;
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
      offset: position.offset + textShift,
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
        _renderParagraph?.getPositionForOffset(offset).offset ?? 0;
    final baseOffset = (rawOffset - textShift).clamp(
      0,
      widget.node.delta?.length ?? rawOffset,
    );
    return Position(path: widget.node.path, offset: baseOffset);
  }

  /// Moves the caret one visual line up or down within this text node
  /// using the [RenderParagraph]'s local coordinate system. Because
  /// local coordinates are unaffected by scroll position, this method
  /// is completely scroll-independent and viewport-independent.
  ///
  /// Returns `null` when the caret is at the first/last visual line —
  /// the caller should navigate to the adjacent document node.
  ///
  /// Uses [TextPainter.getLineBoundary] to identify line boundaries
  /// directly from the text layout, which is correct for mixed font
  /// sizes, first-line indents, and any paragraph geometry — unlike
  /// pixel-based estimation that breaks when fonts change across lines.
  @override
  Position? moveVerticallyInText(int currentOffset, bool upwards) {
    final rp = _renderParagraph;
    if (rp == null || !rp.hasSize) return null;

    final delta = widget.node.delta;
    if (delta == null) return null;

    final textLen = delta.length;
    if (currentOffset < 0 || currentOffset > textLen) return null;

    final tp = rp.textPainter;
    final tpOffset = currentOffset + textShift;
    if (tpOffset < 0) return null;

    // 1. Find the current line's text range.
    final currentLine = tp.getLineBoundary(TextPosition(offset: tpOffset));

    // 2. Get the adjacent line's text range.
    late final TextRange adjacentLine;
    if (upwards) {
      // Already on the first visual line?
      if (currentLine.start <= textShift) return null;
      adjacentLine =
          tp.getLineBoundary(TextPosition(offset: currentLine.start - 1));
    } else {
      // Already on the last visual line?
      if (currentLine.end >= textLen + textShift) return null;
      adjacentLine = tp.getLineBoundary(TextPosition(offset: currentLine.end));
    }

    // 3. Get the caret baseline of the adjacent line's first character.
    final adjacentCaret = tp.getOffsetForCaret(
      TextPosition(offset: adjacentLine.start),
      Rect.zero,
    );

    // 4. Preserve the current horizontal column.
    final currentCaret =
        tp.getOffsetForCaret(TextPosition(offset: tpOffset), Rect.zero);

    // 5. Find the text position at the same column on the adjacent line.
    final target = Offset(currentCaret.dx, adjacentCaret.dy);
    final newPos = tp.getPositionForOffset(target);
    final newOffset = (newPos.offset - textShift).clamp(0, textLen);

    if (newOffset != currentOffset) {
      return Position(path: widget.node.path, offset: newOffset);
    }

    return null;
  }

  @override
  double? getCaretLocalDx(int offset) {
    final rp = _renderParagraph;
    if (rp == null) return null;
    final tp = TextPosition(offset: offset + textShift);
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
      offset: rawTextPosition.offset.clamp(textShift, rawTextPosition.offset),
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
        offset: wordEdgeOffset - textShift,
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
      offset: rawTextPosition.offset.clamp(textShift, rawTextPosition.offset),
      affinity: rawTextPosition.affinity,
    );
    final textRange = _renderParagraph?.getWordBoundary(shiftedTextPosition) ??
        TextRange.empty;
    final start = Position(
      path: widget.node.path,
      offset: textRange.start - textShift,
    );
    final end = Position(
      path: widget.node.path,
      offset: textRange.end - textShift,
    );
    return Selection(start: start, end: end);
  }

  @override
  Selection? getWordBoundaryInPosition(Position position) {
    final textPosition = TextPosition(offset: position.offset + textShift);
    final textRange =
        _renderParagraph?.getWordBoundary(textPosition) ?? TextRange.empty;
    final start = Position(
      path: widget.node.path,
      offset: textRange.start - textShift,
    );
    final end = Position(
      path: widget.node.path,
      offset: textRange.end - textShift,
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
    final textSelection = textSelectionFromEditorSelection(
      widget.node,
      selection,
      textShift,
    );
    if (textSelection == null) {
      return [];
    }
    final rects = paragraph
        ?.getBoxesForSelection(
          textSelection,
          boxHeightStyle: ui.BoxHeightStyle.max,
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
    final baseOffset = (rawBase - textShift).clamp(0, rawBase);
    final extentOffset = (rawExtent - textShift).clamp(0, rawExtent);
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
}
