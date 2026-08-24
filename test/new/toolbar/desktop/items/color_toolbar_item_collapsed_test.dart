import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:novident_editor/novident_editor.dart';

/// Regression tests for the desktop color toolbar items
/// (`buildTextColorItem`, `buildHighlightColorItem`) — collapsed-selection
/// highlight.
///
/// These capture the bug where a collapsed cursor inside already-colored text
/// does NOT highlight the color button (`allSatisfyInSelection` returns
/// `false` for collapsed selections).
void main() {
  setUpAll(() {
    TestWidgetsFlutterBinding.ensureInitialized();
  });

  EditorState editorWithColoredText(String attrKey, String colorHex) {
    final doc = Document.blank();
    final delta = Delta()..insert('Hello', attributes: {attrKey: colorHex});
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

  Future<SVGIconItemWidget> pumpColorItem(
    WidgetTester tester,
    EditorState editorState,
    ToolbarItem item,
  ) async {
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: Builder(
            builder: (context) {
              return item.builder!(
                context,
                editorState,
                Colors.blue,
                Colors.grey,
                null,
              );
            },
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();
    return tester.widget<SVGIconItemWidget>(
      find.byType(SVGIconItemWidget),
    );
  }

  group('text color item', () {
    testWidgets('cursor inside colored text highlights the button',
        (tester) async {
      final editorState = editorWithColoredText(
        RichTextKeys.textColor,
        '0xFF000000',
      );
      addTearDown(() => editorState.dispose());

      unawaited(editorState.updateSelectionWithReason(
        Selection.single(path: [0], startOffset: 2),
      ));

      final icon = await pumpColorItem(
        tester,
        editorState,
        buildTextColorItem(),
      );
      expect(icon.isHighlight, isTrue);
    });

    testWidgets('cursor inside plain text does not highlight the button',
        (tester) async {
      final doc = Document.blank();
      final delta = Delta()..insert('Hello');
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
      final editorState = EditorState(document: doc);
      addTearDown(() => editorState.dispose());

      unawaited(editorState.updateSelectionWithReason(
        Selection.single(path: [0], startOffset: 2),
      ));

      final icon = await pumpColorItem(
        tester,
        editorState,
        buildTextColorItem(),
      );
      expect(icon.isHighlight, isFalse);
    });
  });

  group('highlight color item', () {
    testWidgets('cursor inside highlighted text highlights the button',
        (tester) async {
      final editorState = editorWithColoredText(
        RichTextKeys.backgroundColor,
        '0xFFFFEB3B',
      );
      addTearDown(() => editorState.dispose());

      unawaited(editorState.updateSelectionWithReason(
        Selection.single(path: [0], startOffset: 2),
      ));

      final icon = await pumpColorItem(
        tester,
        editorState,
        buildHighlightColorItem(),
      );
      expect(icon.isHighlight, isTrue);
    });

    testWidgets('cursor inside plain text does not highlight the button',
        (tester) async {
      final doc = Document.blank();
      final delta = Delta()..insert('Hello');
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
      final editorState = EditorState(document: doc);
      addTearDown(() => editorState.dispose());

      unawaited(editorState.updateSelectionWithReason(
        Selection.single(path: [0], startOffset: 2),
      ));

      final icon = await pumpColorItem(
        tester,
        editorState,
        buildHighlightColorItem(),
      );
      expect(icon.isHighlight, isFalse);
    });
  });
}
