import 'dart:async';

import 'package:novident_editor/novident_editor.dart';
import 'package:flutter/services.dart';

Future<void> onNonTextUpdate(
  TextEditingDeltaNonTextUpdate nonTextUpdate,
  EditorState editorState,
) async {
  assert(() {
    NovidentEditorLog.input.debug('onNonTextUpdate: $nonTextUpdate');
    return true;
  }());

  // update the selection on Windows
  //
  // when typing characters with CJK IME on Windows, a non-text update is sent
  // with the selection range.
  final selection = editorState.selection;
  if (selection == null || nonTextUpdate.composing != TextRange.empty) {
    return;
  }

  if (EditorPlatform.isAndroid) {
    // on some Android keyboards (e.g. Gboard), they use non-text update to update the selection when moving cursor
    // by space bar.
    // for the another keyboards (e.g. system keyboard), they will trigger the
    // `onFloatingCursor` event instead.
    assert(() {
      NovidentEditorLog.input
          .debug('[Android] onNonTextUpdate: $nonTextUpdate');
      return true;
    }());
    final nonTextUpdateStart = nonTextUpdate.selection.start;
    final nonTextUpdateEnd = nonTextUpdate.selection.end;
    final selectionStart = selection.start.offset;
    if (nonTextUpdate.selection.isCollapsed &&
        selection.isCollapsed &&
        nonTextUpdateStart != selectionStart) {
      unawaited(
        editorState.updateSelectionWithReason(
          Selection.collapsed(
            Position(
              path: selection.start.path,
              offset: nonTextUpdateStart,
            ),
          ),
          reason: SelectionUpdateReason.uiEvent,
        ),
      );
    } else if (!nonTextUpdate.selection.isCollapsed) {
      unawaited(
        editorState.updateSelectionWithReason(
          Selection(
            start: Position(
              path: selection.start.path,
              offset: nonTextUpdateStart,
            ),
            end: Position(
              path: selection.end.path,
              offset: nonTextUpdateEnd,
            ),
          ),
          reason: SelectionUpdateReason.uiEvent,
        ),
      );
    }
  } else if (EditorPlatform.isIOS) {
    // on iOS, the cursor movement will trigger the `onFloatingCursor` event.
    // so we don't need to handle the non-text update here.
    assert(() {
      NovidentEditorLog.input.debug('[iOS] onNonTextUpdate: $nonTextUpdate');
      return true;
    }());
    return;
  }

  if (EditorPlatform.isWindows) {
    if (nonTextUpdate.composing == TextRange.empty &&
        nonTextUpdate.selection.isCollapsed) {
      editorState.selection = Selection.collapsed(
        Position(
          path: selection.start.path,
          offset: nonTextUpdate.selection.start,
        ),
      );
    }
  } else if (EditorPlatform.isLinux) {
    unawaited(
      editorState.updateSelectionWithReason(
        Selection.collapsed(
          Position(
            path: selection.start.path,
            offset: nonTextUpdate.selection.start,
          ),
        ),
      ),
    );
  } else if (PlatformExtension.isMacOS) {
    unawaited(
      editorState.updateSelectionWithReason(
        Selection.collapsed(
          Position(
            path: selection.start.path,
            offset: nonTextUpdate.selection.start,
          ),
        ),
      ),
    );
  }
}
