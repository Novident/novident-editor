import 'package:novident_editor/novident_editor.dart';
import 'package:flutter/services.dart';

Future<void> onNonTextUpdate(
  TextEditingDeltaNonTextUpdate nonTextUpdate,
  EditorState editorState,
) async {
  NovidentEditorLog.input.debug('onNonTextUpdate: $nonTextUpdate');

  // update the selection on Windows
  //
  // when typing characters with CJK IME on Windows, a non-text update is sent
  // with the selection range.
  final selection = editorState.selection;

  if (PlatformExtension.isWindows) {
    if (selection != null &&
        nonTextUpdate.composing == TextRange.empty &&
        nonTextUpdate.selection.isCollapsed) {
      editorState.selection = Selection.collapsed(
        Position(
          path: selection.start.path,
          offset: nonTextUpdate.selection.start,
        ),
      );
    }
  } else if (PlatformExtension.isLinux) {
    if (selection != null) {
      editorState.updateSelectionWithReason(
        Selection.collapsed(
          Position(
            path: selection.start.path,
            offset: nonTextUpdate.selection.start,
          ),
        ),
      );
    }
  } else if (PlatformExtension.isMacOS) {
    if (selection != null) {
      editorState.updateSelectionWithReason(
        Selection.collapsed(
          Position(
            path: selection.start.path,
            offset: nonTextUpdate.selection.start,
          ),
        ),
      );
    }
  } else if (PlatformExtension.isAndroid) {
    // on some Android keyboards (e.g. Gboard), they use non-text update to update the selection when moving cursor
    // by space bar.
    // for the another keyboards (e.g. system keyboard), they will trigger the
    // `onFloatingCursor` event instead.
    NovidentEditorLog.input.debug('[Android] onNonTextUpdate: $nonTextUpdate');
    if (selection != null) {
      final nonTextUpdateStart = nonTextUpdate.selection.start;
      final selectionStart = selection.start.offset;
      if (nonTextUpdateStart != selectionStart) {
        editorState.updateSelectionWithReason(
          Selection.collapsed(
            Position(
              path: selection.start.path,
              offset: nonTextUpdateStart,
            ),
          ),
          reason: SelectionUpdateReason.uiEvent,
        );
      }
    }
  } else if (PlatformExtension.isIOS) {
    // on iOS, the cursor movement will trigger the `onFloatingCursor` event.
    // so we don't need to handle the non-text update here.
    NovidentEditorLog.input.debug('[iOS] onNonTextUpdate: $nonTextUpdate');
  }
}
