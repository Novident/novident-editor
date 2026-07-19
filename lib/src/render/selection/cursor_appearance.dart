import 'dart:ui';

import 'package:novident_editor/novident_editor.dart';

/// Builds an optional [CursorAppearance] for the caret about to be painted.
///
/// * [node] is the block that owns the caret.
/// * [selection] is the current editor selection (non normalized — its end
///   is the moving head).
/// * [caretPosition] is the position the caret is painted at: the collapsed
///   position, or the selection head when
///   [CursorAppearance.paintOnExpandedSelection] applies.
///
/// Return null to keep the default painting.
typedef CursorAppearanceBuilder = CursorAppearance? Function(
  Node node,
  Selection selection,
  Position caretPosition,
);

/// Overrides how the caret is painted by the selection areas.
///
/// Assign a [CursorAppearanceBuilder] to
/// `EditorState.cursorAppearanceBuilder` to customize the caret at paint
/// time — for example, a vim-like block cursor widens the caret rect and
/// disables blinking without touching the editor style.
class CursorAppearance {
  const CursorAppearance({
    this.rectBuilder,
    this.style,
    this.shouldBlink,
    this.color,
    this.position,
    this.paintOnExpandedSelection = false,
  });

  /// Adjusts the caret rect before painting (local coordinates of the
  /// block). E.g. widen it to cover the character under the caret.
  final Rect Function(Rect rect)? rectBuilder;

  /// Overrides the caret style of the block's selectable.
  final CursorStyle? style;

  /// Overrides whether the caret blinks.
  final bool? shouldBlink;

  /// Overrides the caret color (including its opacity).
  final Color? color;

  /// Overrides the position the expanded-selection caret rect is measured
  /// at. It must live in the same block as the selection head, otherwise
  /// it is ignored.
  ///
  /// Useful to keep vim's visual-mode block on the last *selected*
  /// character: the internal selection is end-exclusive, so the painted
  /// head sits at `end - 1` while the selection itself stays untouched.
  final Position? position;

  /// When true, the caret is also painted at the moving head of an
  /// expanded selection (`selection.end`), e.g. to show where a vim visual
  /// selection is being extended from.
  final bool paintOnExpandedSelection;
}
