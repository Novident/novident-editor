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
