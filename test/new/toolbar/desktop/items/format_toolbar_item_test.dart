import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:novident_editor/novident_editor.dart';

/// Regression tests for `markdownFormatItems` (bold/italic/underline/
/// strikethrough/code) — specifically the collapsed-selection highlight.
///
/// These tests capture the bug where a collapsed cursor placed inside
/// already-formatted text does NOT highlight the corresponding toolbar
/// button (`allSatisfyInSelection` returns `false` for collapsed selections).
///
/// Reference behavior (working today): `fontSize` and `fontFamily` items
/// detect the previous character's attribute even with a collapsed selection.
void main() {
  setUpAll(() {
    TestWidgetsFlutterBinding.ensureInitialized();
  });

  EditorState editorWithText(String text, {Map<String, dynamic>? attributes}) {
    final doc = Document.blank();
    final delta = Delta()..insert(text, attributes: attributes);
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

  Future<SVGIconItemWidget> pumpItem(
    WidgetTester tester,
    EditorState editorState,
    String itemId,
  ) async {
    final item = markdownFormatItems.firstWhere((e) => e.id == itemId);
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

  // itemId -> attribute key, matched against `_FormatToolbarItem.name`.
  const cases = {
    'editor.bold': 'bold',
    'editor.italic': 'italic',
    'editor.underline': 'underline',
    'editor.strikethrough': 'strikethrough',
    'editor.code': 'code',
  };

  group('collapsed selection', () {
    for (final entry in cases.entries) {
      testWidgets(
        'cursor inside ${entry.value} text highlights ${entry.key}',
        (tester) async {
          final editorState = editorWithText(
            'Hello',
            attributes: {entry.value: true},
          );
          addTearDown(() => editorState.dispose());

          // Collapsed cursor at offset 2, inside the formatted "Hello".
          unawaited(editorState.updateSelectionWithReason(
            Selection.single(path: [0], startOffset: 2),
          ));

          final icon = await pumpItem(tester, editorState, entry.key);
          expect(icon.isHighlight, isTrue);
        },
      );

      testWidgets(
        'cursor inside plain text does not highlight ${entry.key}',
        (tester) async {
          final editorState = editorWithText('Hello');
          addTearDown(() => editorState.dispose());

          unawaited(editorState.updateSelectionWithReason(
            Selection.single(path: [0], startOffset: 2),
          ));

          final icon = await pumpItem(tester, editorState, entry.key);
          expect(icon.isHighlight, isFalse);
        },
      );
    }
  });

  group('expanded selection (regression guard)', () {
    testWidgets('selection over bold text highlights bold', (tester) async {
      final editorState = editorWithText(
        'Hello',
        attributes: {RichTextKeys.bold: true},
      );
      addTearDown(() => editorState.dispose());

      unawaited(editorState.updateSelectionWithReason(
        Selection.single(path: [0], startOffset: 0, endOffset: 5),
      ));

      final icon = await pumpItem(tester, editorState, 'editor.bold');
      expect(icon.isHighlight, isTrue);
    });

    testWidgets('selection over plain text does not highlight bold',
        (tester) async {
      final editorState = editorWithText('Hello');
      addTearDown(() => editorState.dispose());

      unawaited(editorState.updateSelectionWithReason(
        Selection.single(path: [0], startOffset: 0, endOffset: 5),
      ));

      final icon = await pumpItem(tester, editorState, 'editor.bold');
      expect(icon.isHighlight, isFalse);
    });
  });
}
