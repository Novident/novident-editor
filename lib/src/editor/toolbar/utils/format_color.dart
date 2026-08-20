import 'package:novident_editor/novident_editor.dart';

void formatHighlightColor(
  EditorState editorState,
  Selection? selection,
  String? color, {
  bool withUpdateSelection = false,
}) {
  editorState.formatDelta(
    selection,
    {RichTextKeys.backgroundColor: color},
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
    {RichTextKeys.textColor: color},
    withUpdateSelection: withUpdateSelection,
  );
}
