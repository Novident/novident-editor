import 'package:flutter/cupertino.dart';
import 'package:novident_editor/src/document/document.dart';
import 'package:novident_editor/src/document/selection/document_selection.dart';

class EditorContext {
  final Document document;

  EditorContext({
    required this.document,
  });

  final ValueNotifier<DocumentSelection> _selection = ValueNotifier(
    DocumentSelection.invalid(),
  );
}
