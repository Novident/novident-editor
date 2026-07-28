import 'package:flutter/material.dart';

import 'novident_style_definition.dart';

/// Style configuration for a specific row range in a table (header, footer,
/// or any custom row set via [NovidentTableStyleDefinition.rowStyles]).
class NovidentTableRowStyle {
  const NovidentTableRowStyle({
    this.backgroundColor,
    this.bold = false,
    this.fontSize,
    this.alignment,
    this.textColor,
    this.height,
    this.topBorderColor,
    this.topBorderWidth,
    this.bottomBorderColor,
    this.bottomBorderWidth,
    this.padding,
  });

  /// Background color for every cell in this row.
  ///
  /// Overrides per-cell [TableCellBlockKeys.rowBackgroundColor] when set.
  final Color? backgroundColor;

  /// Whether text in this row is bold.
  final bool bold;

  /// Font size override for cells in this row.
  final double? fontSize;

  /// Text alignment for cells in this row.
  final TextAlign? alignment;

  /// Text color for cells in this row.
  final Color? textColor;

  /// Explicit row height. Falls back to
  /// [NovidentTableStyleDefinition.rowDefaultHeight] when `null`.
  final double? height;

  /// Color of the border above this row.
  final Color? topBorderColor;

  /// Thickness of the border above this row.
  final double? topBorderWidth;

  /// Color of the border below this row.
  final Color? bottomBorderColor;

  /// Thickness of the border below this row.
  final double? bottomBorderWidth;

  /// Padding override for cells in this row.
  final EdgeInsets? padding;

  NovidentTableRowStyle merge(NovidentTableRowStyle? other) {
    if (other == null) return this;
    return NovidentTableRowStyle(
      backgroundColor: other.backgroundColor ?? backgroundColor,
      bold: other.bold || bold,
      fontSize: other.fontSize ?? fontSize,
      alignment: other.alignment ?? alignment,
      textColor: other.textColor ?? textColor,
      height: other.height ?? height,
      topBorderColor: other.topBorderColor ?? topBorderColor,
      topBorderWidth: other.topBorderWidth ?? topBorderWidth,
      bottomBorderColor: other.bottomBorderColor ?? bottomBorderColor,
      bottomBorderWidth: other.bottomBorderWidth ?? bottomBorderWidth,
      padding: other.padding ?? padding,
    );
  }

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is NovidentTableRowStyle &&
          runtimeType == other.runtimeType &&
          backgroundColor == other.backgroundColor &&
          bold == other.bold &&
          fontSize == other.fontSize &&
          alignment == other.alignment &&
          textColor == other.textColor &&
          height == other.height &&
          topBorderColor == other.topBorderColor &&
          topBorderWidth == other.topBorderWidth &&
          bottomBorderColor == other.bottomBorderColor &&
          bottomBorderWidth == other.bottomBorderWidth &&
          padding == other.padding;

  @override
  int get hashCode => Object.hash(
        backgroundColor,
        bold,
        fontSize,
        alignment,
        textColor,
        height,
        topBorderColor,
        topBorderWidth,
        bottomBorderColor,
        bottomBorderWidth,
        padding,
      );
}

/// A reusable, named style definition for table blocks.
///
/// Extends [NovidentStyleDefinition] so table styles live in the same
/// [NovidentStyleRegistry] as paragraph styles. Every table inherits text
/// formatting properties (font, size, bold, spacing, etc.) from its style
/// just like a paragraph, plus table-specific layout properties.
///
/// Resolution priority (highest to lowest):
/// 1. Per-node attributes ([TableBlockKeys], [TableCellBlockKeys])
/// 2. Style referenced via `styleRef` node attribute
/// 3. Default style for the `'table'` block type (`defaultStylesByType['table']`)
/// 4. [kDefaultTableStyle] global fallback
/// 5. [TableDefaults] hardcoded constants
class NovidentTableStyleDefinition extends NovidentStyleDefinition {
  const NovidentTableStyleDefinition({
    required super.id,
    required super.name,
    super.basedOn,
    this.colDefaultWeight = 1.0,
    this.rowDefaultHeight = 40.0,
    this.colMinimumWidth = 40.0,
    this.borderWidth = 2.0,
    this.borderColor,
    this.borderHoverColor,
    this.innerBorderColor,
    this.outerBorderColor,
    this.borderLineStyle = BorderStyle.solid,
    this.borderRadius,
    this.noBorder = false,
    this.cellPadding,
    this.cellAlignment,
    this.cellVerticalAlignment,
    this.cellTextOverflow,
    this.cellVerticalPadding = 8.0,
    this.enableHorizontalScroll = true,
    this.tablePadding = const EdgeInsets.only(top: 10, left: 10, bottom: 4),
    this.showAddColumnButton = true,
    this.showAddRowButton = true,
    this.evenRowColor,
    this.oddRowColor,
    this.headerRowCount = 0,
    this.headerStyle,
    this.footerRowCount = 0,
    this.footerStyle,
    this.columnWeights,
    this.rowHeights,
    this.selectionHighlightColor,
    super.next,
    super.spacing,
    super.indent,
    super.borderStyle,
    super.keep,
    super.alignment,
    super.blockBackgroundColor,
    super.bold,
    super.italic,
    super.underline,
    super.overline,
    super.strikethrough,
    super.caps,
    super.smallCaps,
    super.decorationStyle,
    super.decorationColor,
    super.fontFamily,
    super.fontSize,
    super.textColor,
    super.textBackgroundColor,
    super.letterSpacing,
    super.fontVariations,
    super.fontBackground,
    super.fontForeground,
    super.wordSpacing,
    super.fontFeatures,
    super.fontShadows,
    super.allowGlobalFirstLineIndent,
  });


  final double colDefaultWeight;
  final double rowDefaultHeight;
  final double colMinimumWidth;
  final double borderWidth;
  final Color? borderColor;
  final Color? borderHoverColor;

  /// Border color for internal cell dividers (between rows and columns).
  /// When `null`, [borderColor] is used for all borders.
  final Color? innerBorderColor;

  /// Border color for the outer perimeter of the table.
  /// When `null`, [borderColor] is used for all borders.
  final Color? outerBorderColor;

  /// Border line style (solid, dashed, dotted, etc.). Defaults to solid.
  final BorderStyle borderLineStyle;

  /// Corner radius for the table's outer border.
  final BorderRadius? borderRadius;

  /// When `true`, no borders are drawn anywhere on the table —
  /// [borderWidth], [borderColor], [borderStyle], etc. are all ignored.
  final bool noBorder;

  /// Padding inside every cell. Overrides the builder-level cell padding.
  final EdgeInsets? cellPadding;

  /// Default horizontal text alignment for cell content.
  final TextAlign? cellAlignment;

  /// Vertical alignment of cell content within the row.
  final CrossAxisAlignment? cellVerticalAlignment;

  /// How overflowing text in cells is handled.
  final TextOverflow? cellTextOverflow;

  final double cellVerticalPadding;
  final bool enableHorizontalScroll;
  final EdgeInsets tablePadding;
  final bool showAddColumnButton;
  final bool showAddRowButton;


  /// Background color for even-numbered rows (0-indexed: rows 0, 2, 4…).
  /// Overridden by per-cell background colors and [headerStyle] / [footerStyle].
  final Color? evenRowColor;

  /// Background color for odd-numbered rows (1, 3, 5…).
  final Color? oddRowColor;


  /// Number of rows at the top of the table treated as header.
  /// Rows `0` through `headerRowCount - 1` use [headerStyle].
  final int headerRowCount;

  /// Style applied to header rows (first [headerRowCount] rows).
  final NovidentTableRowStyle? headerStyle;

  /// Number of rows at the bottom of the table treated as footer.
  /// Rows `rowsLen - footerRowCount` through `rowsLen - 1` use [footerStyle].
  final int footerRowCount;

  /// Style applied to footer rows (last [footerRowCount] rows).
  final NovidentTableRowStyle? footerStyle;


  /// Default column weights keyed by column index.
  /// Columns not listed here use [colDefaultWeight].
  final Map<int, double>? columnWeights;

  /// Default row heights keyed by row index.
  /// Rows not listed here use [rowDefaultHeight].
  final Map<int, double>? rowHeights;


  /// Highlight color when cells are selected.
  final Color? selectionHighlightColor;


  /// Convenience: same as the default constructor but sets [next] to [id]
  /// so pressing Enter at the end of a styled table keeps the same style.
  const NovidentTableStyleDefinition.nextSame({
    required super.id,
    required super.name,
    super.basedOn,
    this.colDefaultWeight = 1.0,
    this.rowDefaultHeight = 40.0,
    this.colMinimumWidth = 40.0,
    this.borderWidth = 2.0,
    this.borderColor,
    this.borderHoverColor,
    this.innerBorderColor,
    this.outerBorderColor,
    this.borderLineStyle = BorderStyle.solid,
    this.borderRadius,
    this.noBorder = false,
    this.cellPadding,
    this.cellAlignment,
    this.cellVerticalAlignment,
    this.cellTextOverflow,
    this.cellVerticalPadding = 8.0,
    this.enableHorizontalScroll = true,
    this.tablePadding = const EdgeInsets.only(top: 10, left: 10, bottom: 4),
    this.showAddColumnButton = true,
    this.showAddRowButton = true,
    this.evenRowColor,
    this.oddRowColor,
    this.headerRowCount = 0,
    this.headerStyle,
    this.footerRowCount = 0,
    this.footerStyle,
    this.columnWeights,
    this.rowHeights,
    this.selectionHighlightColor,
    super.spacing,
    super.indent,
    super.borderStyle,
    super.keep,
    super.alignment,
    super.blockBackgroundColor,
    super.bold,
    super.italic,
    super.underline,
    super.overline,
    super.strikethrough,
    super.caps,
    super.smallCaps,
    super.decorationStyle,
    super.decorationColor,
    super.fontFamily,
    super.fontSize,
    super.textColor,
    super.textBackgroundColor,
    super.letterSpacing,
    super.fontVariations,
    super.fontBackground,
    super.fontForeground,
    super.wordSpacing,
    super.fontFeatures,
    super.fontShadows,
    super.allowGlobalFirstLineIndent,
  }) : super.nextSame();


  @override
  NovidentStyleDefinition merge(NovidentStyleDefinition other) {
    if (other is NovidentTableStyleDefinition) {
      return _mergeWithTable(other);
    }
    return _copyWithParent(other);
  }

  NovidentTableStyleDefinition mergeTable(NovidentStyleDefinition other) {
    if (other is NovidentTableStyleDefinition) {
      return _mergeWithTable(other);
    }
    return _copyWithParent(other);
  }

  NovidentTableStyleDefinition _copyWithParent(NovidentStyleDefinition parent) {
    return NovidentTableStyleDefinition(
      id: id,
      name: name,
      basedOn: basedOn,
      // Table props — keep ours
      colDefaultWeight: colDefaultWeight,
      rowDefaultHeight: rowDefaultHeight,
      colMinimumWidth: colMinimumWidth,
      borderWidth: borderWidth,
      borderColor: borderColor,
      borderHoverColor: borderHoverColor,
      innerBorderColor: innerBorderColor,
      outerBorderColor: outerBorderColor,
      borderLineStyle: borderLineStyle,
      borderRadius: borderRadius,
      noBorder: noBorder,
      cellPadding: cellPadding,
      cellAlignment: cellAlignment,
      cellVerticalAlignment: cellVerticalAlignment,
      cellTextOverflow: cellTextOverflow,
      cellVerticalPadding: cellVerticalPadding,
      enableHorizontalScroll: enableHorizontalScroll,
      tablePadding: tablePadding,
      showAddColumnButton: showAddColumnButton,
      showAddRowButton: showAddRowButton,
      evenRowColor: evenRowColor,
      oddRowColor: oddRowColor,
      headerRowCount: headerRowCount,
      headerStyle: headerStyle,
      footerRowCount: footerRowCount,
      footerStyle: footerStyle,
      columnWeights: columnWeights,
      rowHeights: rowHeights,
      selectionHighlightColor: selectionHighlightColor,
      // Text props — this (child/specific) > parent (base/fallback)
      next: next ?? parent.next,
      spacing: spacing ?? parent.spacing,
      indent: indent ?? parent.indent,
      keep: keep ?? parent.keep,
      alignment:
          alignment != TextAlign.left ? alignment : parent.alignment,
      blockBackgroundColor:
          blockBackgroundColor ?? parent.blockBackgroundColor,
      bold: bold || parent.bold,
      italic: italic || parent.italic,
      underline: underline || parent.underline,
      overline: overline || parent.overline,
      strikethrough: strikethrough || parent.strikethrough,
      caps: caps || parent.caps,
      smallCaps: smallCaps || parent.smallCaps,
      decorationStyle: decorationStyle ?? parent.decorationStyle,
      decorationColor: decorationColor ?? parent.decorationColor,
      fontFamily: fontFamily ?? parent.fontFamily,
      fontSize: fontSize != 12.0 ? fontSize : parent.fontSize,
      textColor: textColor ?? parent.textColor,
      textBackgroundColor:
          textBackgroundColor ?? parent.textBackgroundColor,
      letterSpacing: letterSpacing ?? parent.letterSpacing,
      fontVariations: fontVariations ?? parent.fontVariations,
      fontBackground: fontBackground ?? parent.fontBackground,
      fontForeground: fontForeground ?? parent.fontForeground,
      wordSpacing: wordSpacing ?? parent.wordSpacing,
      fontFeatures: fontFeatures ?? parent.fontFeatures,
      fontShadows: fontShadows ?? parent.fontShadows,
      allowGlobalFirstLineIndent:
          allowGlobalFirstLineIndent
              ? parent.allowGlobalFirstLineIndent
              : allowGlobalFirstLineIndent,
    );
  }

  NovidentTableStyleDefinition _mergeWithTable(
      NovidentTableStyleDefinition other) {
    return NovidentTableStyleDefinition(
      id: other.id,
      name: other.name,
      basedOn: other.basedOn ?? basedOn,
      // Table props — other overrides
      colDefaultWeight: other.colDefaultWeight != 1.0
          ? other.colDefaultWeight
          : colDefaultWeight,
      rowDefaultHeight: other.rowDefaultHeight != 40.0
          ? other.rowDefaultHeight
          : rowDefaultHeight,
      colMinimumWidth: other.colMinimumWidth != 40.0
          ? other.colMinimumWidth
          : colMinimumWidth,
      borderWidth:
          other.borderWidth != 2.0 ? other.borderWidth : borderWidth,
      borderColor: other.borderColor ?? borderColor,
      borderHoverColor: other.borderHoverColor ?? borderHoverColor,
      innerBorderColor: other.innerBorderColor ?? innerBorderColor,
      outerBorderColor: other.outerBorderColor ?? outerBorderColor,
      borderLineStyle: other.borderLineStyle != BorderStyle.solid
          ? other.borderLineStyle
          : borderLineStyle,
      borderRadius: other.borderRadius ?? borderRadius,
      noBorder: other.noBorder || noBorder,
      cellPadding: other.cellPadding ?? cellPadding,
      cellAlignment: other.cellAlignment ?? cellAlignment,
      cellVerticalAlignment:
          other.cellVerticalAlignment ?? cellVerticalAlignment,
      cellTextOverflow: other.cellTextOverflow ?? cellTextOverflow,
      cellVerticalPadding: other.cellVerticalPadding != 8.0
          ? other.cellVerticalPadding
          : cellVerticalPadding,
      enableHorizontalScroll:
          other.enableHorizontalScroll != enableHorizontalScroll
              ? other.enableHorizontalScroll
              : enableHorizontalScroll,
      tablePadding: other.tablePadding != tablePadding
          ? other.tablePadding
          : tablePadding,
      showAddColumnButton:
          other.showAddColumnButton != showAddColumnButton
              ? other.showAddColumnButton
              : showAddColumnButton,
      showAddRowButton: other.showAddRowButton != showAddRowButton
          ? other.showAddRowButton
          : showAddRowButton,
      evenRowColor: other.evenRowColor ?? evenRowColor,
      oddRowColor: other.oddRowColor ?? oddRowColor,
      headerRowCount: other.headerRowCount > 0
          ? other.headerRowCount
          : headerRowCount,
      headerStyle: other.headerStyle != null
          ? headerStyle?.merge(other.headerStyle) ?? other.headerStyle
          : headerStyle,
      footerRowCount: other.footerRowCount > 0
          ? other.footerRowCount
          : footerRowCount,
      footerStyle: other.footerStyle != null
          ? footerStyle?.merge(other.footerStyle) ?? other.footerStyle
          : footerStyle,
      columnWeights: other.columnWeights ?? columnWeights,
      rowHeights: other.rowHeights ?? rowHeights,
      selectionHighlightColor:
          other.selectionHighlightColor ?? selectionHighlightColor,
      // Text props — other overrides
      next: other.next ?? next,
      spacing: other.spacing ?? spacing,
      indent: other.indent ?? indent,
      keep: other.keep ?? keep,
      alignment: other.alignment != alignment ? other.alignment : alignment,
      blockBackgroundColor:
          other.blockBackgroundColor ?? blockBackgroundColor,
      bold: other.bold || bold,
      italic: other.italic || italic,
      underline: other.underline || underline,
      overline: other.overline || overline,
      strikethrough: other.strikethrough || strikethrough,
      caps: other.caps || caps,
      smallCaps: other.smallCaps || smallCaps,
      decorationStyle: other.decorationStyle ?? decorationStyle,
      decorationColor: other.decorationColor ?? decorationColor,
      fontFamily: other.fontFamily ?? fontFamily,
      fontSize: other.fontSize != 12.0 ? other.fontSize : fontSize,
      textColor: other.textColor ?? textColor,
      textBackgroundColor:
          other.textBackgroundColor ?? textBackgroundColor,
      letterSpacing: other.letterSpacing ?? letterSpacing,
      fontVariations: other.fontVariations ?? fontVariations,
      fontBackground: other.fontBackground ?? fontBackground,
      fontForeground: other.fontForeground ?? fontForeground,
      wordSpacing: other.wordSpacing ?? wordSpacing,
      fontFeatures: other.fontFeatures ?? fontFeatures,
      fontShadows: other.fontShadows ?? fontShadows,
      allowGlobalFirstLineIndent:
          other.allowGlobalFirstLineIndent != allowGlobalFirstLineIndent
              ? other.allowGlobalFirstLineIndent
              : allowGlobalFirstLineIndent,
    );
  }

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is NovidentTableStyleDefinition &&
          runtimeType == other.runtimeType &&
          id == other.id;

  @override
  int get hashCode => id.hashCode;
}
