import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:novident_editor/novident_editor.dart';

/// Regression tests for the toolbar wiring around `toggledStyleNotifier`.
///
/// `toggleAttribute` with a collapsed selection only mutates `toggledStyle`
/// (it does not change the selection). The toolbars currently only listen to
/// `selectionNotifier`, so the format buttons never re-highlight after a
/// collapsed toggle. These tests capture that end-to-end behavior.
void main() {
  setUpAll(() {
    TestWidgetsFlutterBinding.ensureInitialized();
  });

  EditorState editorWithText(String text) {
    final doc = Document.blank();
    final delta = Delta()..insert(text);
    doc.insert(
      [
        0,
      ],
      [
        Node(
          type: 'paragraph',
          attributes: {
            blockComponentDelta: delta.toJson(),
          },
        ),
      ],
    );
    return EditorState(document: doc);
  }

  SVGIconItemWidget boldIcon(WidgetTester tester) {
    return tester.widget<SVGIconItemWidget>(
      find.byWidgetPredicate(
        (w) => w is SVGIconItemWidget && w.iconName == 'toolbar/bold',
      ),
    );
  }

  Future<void> pumpToolbar(
    WidgetTester tester,
    EditorState editorState,
  ) async {
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: NovidentStaticToolbar(
            items: markdownFormatItems,
            editorState: editorState,
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();
  }

  testWidgets(
    'toggling bold with a collapsed cursor highlights the bold button',
    (tester) async {
      final editorState = editorWithText('Hello');
      addTearDown(() => editorState.dispose());

      unawaited(editorState.updateSelectionWithReason(
        Selection.single(path: [0], startOffset: 2),
      ));

      await pumpToolbar(tester, editorState);

      // Initially not highlighted.
      expect(boldIcon(tester).isHighlight, isFalse);

      // Toggle bold with the (still collapsed) cursor.
      await editorState.toggleAttribute(RichTextKeys.bold);
      await tester.pumpAndSettle();

      // The button should now reflect the pending toggled style.
      expect(boldIcon(tester).isHighlight, isTrue);

      // Toggle again → back to inactive.
      await editorState.toggleAttribute(RichTextKeys.bold);
      await tester.pumpAndSettle();

      expect(boldIcon(tester).isHighlight, isFalse);
    },
  );
}
