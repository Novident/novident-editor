import 'package:novident_editor_core/novident_editor_core.dart';
import 'package:novident_editor_document/novident_editor_document.dart';

TextSelection? textSelectionFromEditorSelection(
  Node node,
  Selection? selection,
  int textShift,
) {
  if (selection == null) {
    return null;
  }

  final normalized = selection.normalized;
  final path = node.path;
  if (!node.inSelection(selection)) {
    return null;
  }

  final length = node.delta?.length;
  if (length == null) {
    return null;
  }

  TextSelection? textSelection;

  if (normalized.isSingle) {
    if (path.equals(normalized.start.path)) {
      if (normalized.isCollapsed) {
        textSelection = TextSelection.collapsed(
          offset: normalized.startIndex + textShift,
        );
      } else {
        textSelection = TextSelection(
          baseOffset: normalized.startIndex + textShift,
          extentOffset: normalized.endIndex + textShift,
        );
      }
    }
  } else {
    if (path.equals(normalized.start.path)) {
      textSelection = TextSelection(
        baseOffset: normalized.startIndex + textShift,
        extentOffset: length + textShift,
      );
    } else if (path.equals(normalized.end.path)) {
      textSelection = TextSelection(
        baseOffset: textShift > 0 ? 1 : 0,
        extentOffset: normalized.endIndex + textShift,
      );
    } else {
      textSelection = TextSelection(
        baseOffset: textShift > 0 ? 1 : 0,
        extentOffset: length + textShift,
      );
    }
  }
  return textSelection;
}
