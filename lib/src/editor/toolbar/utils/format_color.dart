import 'package:novident_editor/novident_editor.dart';

void formatHighlightColor(
  EditorState editorState,
  Selection? selection,
  String? color, {
  bool withUpdateSelection = false,
}) {
  editorState.formatDelta(
    selection,
    {NovidentRichTextKeys.backgroundColor: color},
    withUpdateSelection: withUpdateSelection,
  );
}

void formatFontColor(
  EditorState editorState,
  Selection? selection,
  String? color, {
  bool withUpdateSelection = false,
}) {
  editorState.formatDelta(
    selection,
    {NovidentRichTextKeys.textColor: color},
    withUpdateSelection: withUpdateSelection,
  );
}
