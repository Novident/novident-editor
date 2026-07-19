import 'package:novident_editor/novident_editor.dart';
import 'package:novident_editor/src/editor/editor_component/service/ime/delta_input_impl.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('onPerformAction', () {
    // Pro-performa test
    test('call', () async {
      final editorState = EditorState(document: Document.blank());
      await onPerformAction(TextInputAction.continueAction, editorState);
    });
  });
}
