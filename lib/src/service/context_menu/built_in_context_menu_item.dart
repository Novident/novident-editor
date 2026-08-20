import 'package:novident_editor/src/editor/l10n/novident_editor_l10n.dart';

import '../internal_key_event_handlers/copy_paste_handler.dart';
import 'context_menu.dart';

final standardContextMenuItems = [
  [
    // cut
    ContextMenuItem(
      getName: () => NovidentEditorL10n.current.cut,
      onPressed: (editorState) {
        handleCut(editorState);
      },
      // Only applicable with a real (non-collapsed) selection: otherwise
      // the whole block would be cut.
      isApplicable: (editorState) =>
          editorState.selection != null && !editorState.selection!.isCollapsed,
    ),
    // copy
    ContextMenuItem(
      getName: () => NovidentEditorL10n.current.copy,
      onPressed: (editorState) {
        handleCopy(editorState);
      },
      isApplicable: (editorState) =>
          editorState.selection != null && !editorState.selection!.isCollapsed,
    ),
    // Paste
    ContextMenuItem(
      getName: () => NovidentEditorL10n.current.paste,
      onPressed: (editorState) {
        handlePaste(editorState);
      },
    ),
  ],
];
