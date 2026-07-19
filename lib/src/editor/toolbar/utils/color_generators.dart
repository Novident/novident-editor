import 'package:novident_editor/novident_editor.dart';
import 'package:flutter/material.dart';

/// Default text color options when no option is provided
/// - support
///   - desktop
///   - web
///   - mobile
///
List<ColorOption> generateTextColorOptions() {
  return [
    ColorOption(
      colorHex: Colors.grey.toHex(),
      name: NovidentEditorL10n.current.fontColorGray,
    ),
    ColorOption(
      colorHex: Colors.brown.toHex(),
      name: NovidentEditorL10n.current.fontColorBrown,
    ),
    ColorOption(
      colorHex: Colors.yellow.toHex(),
      name: NovidentEditorL10n.current.fontColorYellow,
    ),
    ColorOption(
      colorHex: Colors.green.toHex(),
      name: NovidentEditorL10n.current.fontColorGreen,
    ),
    ColorOption(
      colorHex: Colors.blue.toHex(),
      name: NovidentEditorL10n.current.fontColorBlue,
    ),
    ColorOption(
      colorHex: Colors.purple.toHex(),
      name: NovidentEditorL10n.current.fontColorPurple,
    ),
    ColorOption(
      colorHex: Colors.pink.toHex(),
      name: NovidentEditorL10n.current.fontColorPink,
    ),
    ColorOption(
      colorHex: Colors.red.toHex(),
      name: NovidentEditorL10n.current.fontColorRed,
    ),
  ];
}

/// Default background color options when no option is provided
/// - support
///   - desktop
///   - web
///   - mobile
///
List<ColorOption> generateHighlightColorOptions() {
  return [
    ColorOption(
      colorHex: Colors.grey.withValues(alpha: 0.3).toHex(),
      name: NovidentEditorL10n.current.backgroundColorGray,
    ),
    ColorOption(
      colorHex: Colors.brown.withValues(alpha: 0.3).toHex(),
      name: NovidentEditorL10n.current.backgroundColorBrown,
    ),
    ColorOption(
      colorHex: Colors.yellow.withValues(alpha: 0.3).toHex(),
      name: NovidentEditorL10n.current.backgroundColorYellow,
    ),
    ColorOption(
      colorHex: Colors.green.withValues(alpha: 0.3).toHex(),
      name: NovidentEditorL10n.current.backgroundColorGreen,
    ),
    ColorOption(
      colorHex: Colors.blue.withValues(alpha: 0.3).toHex(),
      name: NovidentEditorL10n.current.backgroundColorBlue,
    ),
    ColorOption(
      colorHex: Colors.purple.withValues(alpha: 0.3).toHex(),
      name: NovidentEditorL10n.current.backgroundColorPurple,
    ),
    ColorOption(
      colorHex: Colors.pink.withValues(alpha: 0.3).toHex(),
      name: NovidentEditorL10n.current.backgroundColorPink,
    ),
    ColorOption(
      colorHex: Colors.red.withValues(alpha: 0.3).toHex(),
      name: NovidentEditorL10n.current.backgroundColorRed,
    ),
  ];
}
