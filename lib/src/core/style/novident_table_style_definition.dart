import 'package:flutter/material.dart';

import 'novident_style_definition.dart';

/// Style configuration for the table header row (row index 0).
///
/// Applied when [NovidentTableStyleDefinition.firstRowHeader] is `true`.
class NovidentTableHeaderStyle {
  const NovidentTableHeaderStyle({
    this.backgroundColor,
    this.bold = false,
    this.fontSize,
    this.alignment,
    this.height,
    this.bottomBorderColor,
    this.bottomBorderWidth,
    this.padding,
  });

  /// Background color for every cell in the first row.
  final Color? backgroundColor;

  /// Whether header text is bold.
  final bool bold;

  /// Font size override for header cells.
  final double? fontSize;

  /// Text alignment for header cells.
  final TextAlign? alignment;

  /// Explicit row height for the header row. Falls back to
  /// [NovidentTableStyleDefinition.rowDefaultHeight] when `null`.
  final double? height;

  /// Color of the border below the header row.
  final Color? bottomBorderColor;

  /// Thickness of the border below the header row.
  final double? bottomBorderWidth;

  /// Padding override for header cells.
  final EdgeInsets? padding;

  NovidentTableHeaderStyle merge(NovidentTableHeaderStyle? other) {
    if (other == null) return this;
    return NovidentTableHeaderStyle(
      backgroundColor: other.backgroundColor ?? backgroundColor,
      bold: other.bold || bold,
      fontSize: other.fontSize ?? fontSize,
      alignment: other.alignment ?? alignment,
      height: other.height ?? height,
      bottomBorderColor: other.bottomBorderColor ?? bottomBorderColor,
      bottomBorderWidth: other.bottomBorderWidth ?? bottomBorderWidth,
      padding: other.padding ?? padding,
    );
  }

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is NovidentTableHeaderStyle &&
          runtimeType == other.runtimeType &&
          backgroundColor == other.backgroundColor &&
          bold == other.bold &&
          fontSize == other.fontSize &&
          alignment == other.alignment &&
          height == other.height &&
          bottomBorderColor == other.bottomBorderColor &&
          bottomBorderWidth == other.bottomBorderWidth &&
          padding == other.padding;

  @override
  int get hashCode => Object.hash(
        backgroundColor,
        bold,
        fontSize,
        alignment,
        height,
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
/// 2. Style referenced via `tableStyleRef` node attribute
/// 3. Default style for the `'table'` block type (`defaultStylesByType['table']`)
/// 4. [kDefaultTableStyle] global fallback
/// 5. [TableDefaults] hardcoded constants
class NovidentTableStyleDefinition extends NovidentStyleDefinition {
  const NovidentTableStyleDefinition({
    required super.id,
    required super.name,
    super.basedOn,
    // ── Table layout ───────────────────────────────────
    this.colDefaultWeight = 1.0,
    this.rowDefaultHeight = 40.0,
    this.colMinimumWidth = 40.0,
    this.borderWidth = 2.0,
    this.borderColor,
    this.borderHoverColor,
    this.cellVerticalPadding = 8.0,
    this.enableHorizontalScroll = true,
    this.tablePadding = const EdgeInsets.only(top: 10, left: 10, bottom: 4),
    this.showAddColumnButton = true,
    this.showAddRowButton = true,
    // ── Header ─────────────────────────────────────────
    this.firstRowHeader = false,
    this.headerStyle,
    // ── Inherited from NovidentStyleDefinition ─────────
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

  // ── Table layout ─────────────────────────────────────

  /// Default column weight for columns without an explicit
  /// [TableCellBlockKeys.colWeight] attribute.
  final double colDefaultWeight;

  /// Default row height in pixels.
  final double rowDefaultHeight;

  /// Minimum column width in pixels.
  final double colMinimumWidth;

  /// Border width in pixels between cells and around the table.
  final double borderWidth;

  /// Border color. Overridable per-table via [TableBlockKeys.borderColor].
  final Color? borderColor;

  /// Border color when hovering over a resizable border.
  final Color? borderHoverColor;

  /// Extra vertical space for row height synchronization.
  final double cellVerticalPadding;

  /// Whether the table gets its own internal horizontal scroll view.
  final bool enableHorizontalScroll;

  /// Padding around the table content.
  final EdgeInsets tablePadding;

  /// Whether the trailing "add column" button is shown.
  final bool showAddColumnButton;

  /// Whether the trailing "add row" button is shown.
  final bool showAddRowButton;

  // ── Merge ───────────────────────────────────────────

  /// Merges [other] on top of this style.
  ///
  /// Overrides [NovidentStyleDefinition.merge] to preserve table-specific
  /// properties when either style in the chain is a table style.
  @override
  NovidentStyleDefinition merge(NovidentStyleDefinition other) {
    if (other is NovidentTableStyleDefinition) {
      return _mergeWithTable(other);
    }
    // Plain paragraph style — inherit text props, keep table props.
    return _copyWithParent(other);
  }

  /// Public entry point for merging with explicit table-awareness.
  /// Use this when the caller knows [other] may be a table style and
  /// wants the full table merge (including the reverse case where `this`
  /// is a plain style and [other] is a table style).
  NovidentTableStyleDefinition mergeTable(NovidentStyleDefinition other) {
    if (other is NovidentTableStyleDefinition) {
      return _mergeWithTable(other);
    }
    return _copyWithParent(other);
  }

  // ── Header ───────────────────────────────────────────

  /// When `true`, the first row renders using [headerStyle].
  final bool firstRowHeader;

  /// Style applied to the first row when [firstRowHeader] is `true`.
  final NovidentTableHeaderStyle? headerStyle;

  // ── Convenience constructor ──────────────────────────

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
    this.cellVerticalPadding = 8.0,
    this.enableHorizontalScroll = true,
    this.tablePadding = const EdgeInsets.only(top: 10, left: 10, bottom: 4),
    this.showAddColumnButton = true,
    this.showAddRowButton = true,
    this.firstRowHeader = false,
    this.headerStyle,
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

  /// Merges [parent] text properties under this table style.
  /// [parent] (the more specific/child style) takes precedence.
  NovidentTableStyleDefinition _copyWithParent(NovidentStyleDefinition parent) {
    return NovidentTableStyleDefinition(
      id: id,
      name: name,
      basedOn: basedOn,
      // Table props — keep ours (only table styles have these)
      colDefaultWeight: colDefaultWeight,
      rowDefaultHeight: rowDefaultHeight,
      colMinimumWidth: colMinimumWidth,
      borderWidth: borderWidth,
      borderColor: borderColor,
      borderHoverColor: borderHoverColor,
      cellVerticalPadding: cellVerticalPadding,
      enableHorizontalScroll: enableHorizontalScroll,
      tablePadding: tablePadding,
      showAddColumnButton: showAddColumnButton,
      showAddRowButton: showAddRowButton,
      firstRowHeader: firstRowHeader,
      headerStyle: headerStyle,
      // Text props — parent (child/override) > this (accumulated/base)
      next: parent.next ?? next,
      spacing: parent.spacing ?? spacing,
      indent: parent.indent ?? indent,
      borderStyle: parent.borderStyle ?? borderStyle,
      keep: parent.keep ?? keep,
      alignment:
          parent.alignment != alignment ? parent.alignment : alignment,
      blockBackgroundColor:
          parent.blockBackgroundColor ?? blockBackgroundColor,
      bold: parent.bold || bold,
      italic: parent.italic || italic,
      underline: parent.underline || underline,
      overline: parent.overline || overline,
      strikethrough: parent.strikethrough || strikethrough,
      caps: parent.caps || caps,
      smallCaps: parent.smallCaps || smallCaps,
      decorationStyle: parent.decorationStyle ?? decorationStyle,
      decorationColor: parent.decorationColor ?? decorationColor,
      fontFamily: parent.fontFamily ?? fontFamily,
      fontSize: parent.fontSize != 12.0 ? parent.fontSize : fontSize,
      textColor: parent.textColor ?? textColor,
      textBackgroundColor:
          parent.textBackgroundColor ?? textBackgroundColor,
      letterSpacing: parent.letterSpacing ?? letterSpacing,
      fontVariations: parent.fontVariations ?? fontVariations,
      fontBackground: parent.fontBackground ?? fontBackground,
      fontForeground: parent.fontForeground ?? fontForeground,
      wordSpacing: parent.wordSpacing ?? wordSpacing,
      fontFeatures: parent.fontFeatures ?? fontFeatures,
      fontShadows: parent.fontShadows ?? fontShadows,
      allowGlobalFirstLineIndent:
          parent.allowGlobalFirstLineIndent != allowGlobalFirstLineIndent
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
      colDefaultWeight:
          other.colDefaultWeight != 1.0 ? other.colDefaultWeight : colDefaultWeight,
      rowDefaultHeight:
          other.rowDefaultHeight != 40.0 ? other.rowDefaultHeight : rowDefaultHeight,
      colMinimumWidth:
          other.colMinimumWidth != 40.0 ? other.colMinimumWidth : colMinimumWidth,
      borderWidth: other.borderWidth != 2.0 ? other.borderWidth : borderWidth,
      borderColor: other.borderColor ?? borderColor,
      borderHoverColor: other.borderHoverColor ?? borderHoverColor,
      cellVerticalPadding: other.cellVerticalPadding != 8.0
          ? other.cellVerticalPadding
          : cellVerticalPadding,
      enableHorizontalScroll:
          other.enableHorizontalScroll != enableHorizontalScroll
              ? other.enableHorizontalScroll
              : enableHorizontalScroll,
      tablePadding: other.tablePadding,
      showAddColumnButton: other.showAddColumnButton != showAddColumnButton
          ? other.showAddColumnButton
          : showAddColumnButton,
      showAddRowButton: other.showAddRowButton != showAddRowButton
          ? other.showAddRowButton
          : showAddRowButton,
      firstRowHeader: other.firstRowHeader || firstRowHeader,
      headerStyle: other.headerStyle != null
          ? headerStyle?.merge(other.headerStyle) ?? other.headerStyle
          : headerStyle,
      // Text props — other overrides
      next: other.next ?? next,
      spacing: other.spacing ?? spacing,
      indent: other.indent ?? indent,
      borderStyle: other.borderStyle ?? borderStyle,
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
