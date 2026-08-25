import 'package:novident_editor_core/novident_editor_core.dart';
import 'package:novident_editor_document/novident_editor_document.dart';

import 'quill_rich_text_keys.dart';

/// Converts a novident inline attribute map (the `attributes` of a
/// [TextInsert]) into its Quill equivalent.
///
/// Novident and Quill name several formatting attributes differently
/// (`strikethrough` vs `strike`, `font_color` vs `color`, `href` vs `link`,
/// `font_family` vs `font`, …), and novident stores colors as `0x`-prefixed
/// hex strings while Quill expects `#RRGGBB`. Editor-internal attributes
/// (spell-check marks, find highlighting, auto-complete, …) are dropped.
///
/// Returns `null` when nothing survived the mapping, so callers can omit the
/// `attributes` key entirely (Quill treats a missing key and an empty map
/// identically).
Map<String, dynamic>? toQuillInlineAttributes(Attributes? novident) {
  if (novident == null || novident.isEmpty) {
    return null;
  }

  final quill = <String, dynamic>{};

  if (novident[RichTextKeys.bold] == true) {
    quill[QuillRichTextKeys.bold] = true;
  }
  if (novident[RichTextKeys.italic] == true) {
    quill[QuillRichTextKeys.italic] = true;
  }
  if (novident[RichTextKeys.underline] == true) {
    quill[QuillRichTextKeys.underline] = true;
  }
  if (novident[RichTextKeys.strikethrough] == true) {
    quill[QuillRichTextKeys.strikethrough] = true;
  }
  if (novident[RichTextKeys.code] == true) {
    quill[QuillRichTextKeys.code] = true;
  }

  final href = novident[RichTextKeys.href] as String?;
  if (href != null && href.isNotEmpty) {
    quill[QuillRichTextKeys.href] = href;
  }

  final fontFamily = novident[RichTextKeys.fontFamily] as String?;
  if (fontFamily != null && fontFamily.isNotEmpty) {
    quill[QuillRichTextKeys.fontFamily] = fontFamily;
  }

  final fontSize = novident[RichTextKeys.fontSize];
  if (fontSize != null) {
    // Quill's `size` attribute is a String; a number is tolerated but the
    // canonical form emitted by editors is its string representation.
    quill[QuillRichTextKeys.fontSize] = '$fontSize';
  }

  final textColor = toQuillColor(novident[RichTextKeys.textColor] as String?);
  if (textColor != null) {
    quill[QuillRichTextKeys.textColor] = textColor;
  }

  final background =
      toQuillColor(novident[RichTextKeys.backgroundColor] as String?);
  if (background != null) {
    quill[QuillRichTextKeys.backgroundColor] = background;
  }

  return quill.isEmpty ? null : quill;
}

/// Converts a novident hex color (`0xFFRRGGBB` / `0xAARRGGBB`, occasionally
/// `#RRGGBB`) into a Quill color string (`#RRGGBB` or `rgba(r,g,b,a)`).
///
/// Returns `null` for values that cannot be recognised as a color.
String? toQuillColor(String? color) {
  if (color == null || color.isEmpty) {
    return null;
  }

  final normalized = color.trim();

  // Already in Quill form: pass through.
  if (normalized.startsWith('#')) {
    return normalized;
  }

  // `rgb(...)` / `rgba(...)` are already Quill-compatible.
  if (normalized.startsWith('rgb')) {
    return normalized;
  }

  if (!normalized.startsWith('0x') && !normalized.startsWith('0X')) {
    return null;
  }

  final hex = normalized.substring(2);
  if (hex.length == 6) {
    return '#$hex';
  }

  if (hex.length == 8) {
    final alpha = int.tryParse(hex.substring(0, 2), radix: 16) ?? 255;
    final rgb = hex.substring(2);
    if (alpha == 255) {
      return '#$rgb';
    }
    final r = int.tryParse(rgb.substring(0, 2), radix: 16) ?? 0;
    final g = int.tryParse(rgb.substring(2, 4), radix: 16) ?? 0;
    final b = int.tryParse(rgb.substring(4, 6), radix: 16) ?? 0;
    return 'rgba($r, $g, $b, ${(alpha / 255).toStringAsFixed(3)})';
  }

  return null;
}

/// Builds the block-level attributes shared by every text block: `align`
/// and text `direction`.
///
/// Returns `null` when the node carries neither, so callers can omit the
/// `attributes` key entirely. Callers that need to add block-specific keys
/// (`header`, `list`, `blockquote`, `indent`, …) can do
/// `toQuillCommonBlockAttributes(node) ?? <String, dynamic>{}` first.
Map<String, dynamic>? toQuillCommonBlockAttributes(Node node) {
  final attributes = <String, dynamic>{};

  final align = node.attributes[blockComponentAlign] as String?;
  if (align != null && align.isNotEmpty) {
    attributes[QuillRichTextKeys.align] = align;
  }

  final direction = node.attributes[blockComponentTextDirection] as String?;
  if (direction == blockComponentTextDirectionLTR) {
    attributes[QuillRichTextKeys.direction] = 'ltr';
  } else if (direction == blockComponentTextDirectionRTL) {
    attributes[QuillRichTextKeys.direction] = 'rtl';
  }

  return attributes.isEmpty ? null : attributes;
}

/// Converts a Quill inline attribute map into its novident equivalent — the
/// inverse of [toQuillInlineAttributes].
///
/// Returns `null` when nothing survived the mapping.
Map<String, dynamic>? toNovidentInlineAttributes(Map<String, dynamic>? quill) {
  if (quill == null || quill.isEmpty) {
    return null;
  }

  final novident = <String, dynamic>{};

  if (quill[QuillRichTextKeys.bold] == true) {
    novident[RichTextKeys.bold] = true;
  }
  if (quill[QuillRichTextKeys.italic] == true) {
    novident[RichTextKeys.italic] = true;
  }
  if (quill[QuillRichTextKeys.underline] == true) {
    novident[RichTextKeys.underline] = true;
  }
  if (quill[QuillRichTextKeys.strikethrough] == true) {
    novident[RichTextKeys.strikethrough] = true;
  }
  if (quill[QuillRichTextKeys.code] == true) {
    novident[RichTextKeys.code] = true;
  }

  final href = quill[QuillRichTextKeys.href] as String?;
  if (href != null && href.isNotEmpty) {
    novident[RichTextKeys.href] = href;
  }

  final fontFamily = quill[QuillRichTextKeys.fontFamily] as String?;
  if (fontFamily != null && fontFamily.isNotEmpty) {
    novident[RichTextKeys.fontFamily] = fontFamily;
  }

  final fontSize = quill[QuillRichTextKeys.fontSize];
  if (fontSize != null) {
    final parsed = fontSize is num ? fontSize : num.tryParse('$fontSize');
    // Named sizes (`small`/`large`/`huge`) have no numeric equivalent; keep
    // the raw value so no information is silently lost.
    novident[RichTextKeys.fontSize] = parsed ?? fontSize;
  }

  final textColor = toNovidentColor(quill[QuillRichTextKeys.textColor] as String?);
  if (textColor != null) {
    novident[RichTextKeys.textColor] = textColor;
  }

  final background = toNovidentColor(quill[QuillRichTextKeys.backgroundColor] as String?);
  if (background != null) {
    novident[RichTextKeys.backgroundColor] = background;
  }

  return novident.isEmpty ? null : novident;
}

/// Converts a Quill color (`#RRGGBB`, `#AARRGGBB`, `rgb(…)`, `rgba(…)`) into
/// a novident hex color (`0xAARRGGBB`) — the inverse of [toQuillColor].
String? toNovidentColor(String? color) {
  if (color == null || color.isEmpty) {
    return null;
  }

  final normalized = color.trim().toLowerCase();

  if (normalized.startsWith('#')) {
    final hex = normalized.substring(1);
    if (hex.length == 6) {
      return '0xFF${hex.toUpperCase()}';
    }
    if (hex.length == 8) {
      return '0x${hex.toUpperCase()}';
    }
    return null;
  }

  if (normalized.startsWith('rgba')) {
    final match = _rgbaPattern.firstMatch(normalized);
    if (match != null) {
      final r = int.parse(match.group(1)!);
      final g = int.parse(match.group(2)!);
      final b = int.parse(match.group(3)!);
      final a = (double.parse(match.group(4)!) * 255).round().clamp(0, 255);
      return '0x${_hexByte(a)}${_hexByte(r)}${_hexByte(g)}${_hexByte(b)}';
    }
    return null;
  }

  if (normalized.startsWith('rgb')) {
    final match = _rgbPattern.firstMatch(normalized);
    if (match != null) {
      final r = int.parse(match.group(1)!);
      final g = int.parse(match.group(2)!);
      final b = int.parse(match.group(3)!);
      return '0xFF${_hexByte(r)}${_hexByte(g)}${_hexByte(b)}';
    }
    return null;
  }

  return null;
}

final _rgbPattern = RegExp(r'rgb\((\d+),\s*(\d+),\s*(\d+)\)');
final _rgbaPattern =
    RegExp(r'rgba\((\d+),\s*(\d+),\s*(\d+),\s*([\d.]+)\)');

String _hexByte(int value) =>
    value.toRadixString(16).padLeft(2, '0').toUpperCase();
