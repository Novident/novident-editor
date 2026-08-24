import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:novident_editor/novident_editor.dart';

import '../../test_helpers/mobile_toolbar_style_test_widget.dart';

/// Regression tests for the mobile color options widgets — collapsed-selection
/// highlight.
///
/// Captures the bug where a collapsed cursor inside already-colored text does
/// NOT highlight the color button (`allSatisfyInSelection` returns `false` for
/// collapsed selections).
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

  EditorState editorWithPlainText() {
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
    return EditorState(document: doc);
  }

  group('text color options', () {
    testWidgets('cursor inside colored text highlights the color button',
        (tester) async {
      final editorState = editorWithColoredText(
        RichTextKeys.textColor,
        Colors.red.toHex(),
      );
      addTearDown(() => editorState.dispose());

      unawaited(
        editorState.updateSelectionWithReason(
          Selection.single(path: [0], startOffset: 2),
        ),
      );

      await tester.pumpWidget(
        Material(
          child: MobileToolbarStyleTestWidget(
            child: TextColorOptionsWidgets(
              editorState,
              Selection.single(path: [0], startOffset: 2),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      final redButton = tester.widget<ColorButton>(
        find.byWidgetPredicate(
          (w) =>
              w is ColorButton &&
              w.colorOption.colorHex == Colors.red.toHex(),
        ),
      );
      expect(redButton.isSelected, isTrue);

      // The clear button should NOT be selected while a color is applied.
      final clearButton = tester.widget<ClearColorButton>(
        find.byType(ClearColorButton),
      );
      expect(clearButton.isSelected, isFalse);
    });

    testWidgets('cursor inside plain text does not highlight any color button',
        (tester) async {
      final editorState = editorWithPlainText();
      addTearDown(() => editorState.dispose());

      unawaited(
        editorState.updateSelectionWithReason(
          Selection.single(path: [0], startOffset: 2),
        ),
      );

      await tester.pumpWidget(
        Material(
          child: MobileToolbarStyleTestWidget(
            child: TextColorOptionsWidgets(
              editorState,
              Selection.single(path: [0], startOffset: 2),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      final redButton = tester.widget<ColorButton>(
        find.byWidgetPredicate(
          (w) =>
              w is ColorButton &&
              w.colorOption.colorHex == Colors.red.toHex(),
        ),
      );
      expect(redButton.isSelected, isFalse);
    });
  });

  group('background color options', () {
    testWidgets('cursor inside highlighted text highlights the color button',
        (tester) async {
      final editorState = editorWithColoredText(
        RichTextKeys.backgroundColor,
        Colors.red.withValues(alpha: 0.3).toHex(),
      );
      addTearDown(() => editorState.dispose());

      unawaited(
        editorState.updateSelectionWithReason(
          Selection.single(path: [0], startOffset: 2),
        ),
      );

      await tester.pumpWidget(
        Material(
          child: MobileToolbarStyleTestWidget(
            child: BackgroundColorOptionsWidgets(
              editorState,
              Selection.single(path: [0], startOffset: 2),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      final redButton = tester.widget<ColorButton>(
        find.byWidgetPredicate(
          (w) =>
              w is ColorButton &&
              w.colorOption.colorHex ==
                  Colors.red.withValues(alpha: 0.3).toHex(),
        ),
      );
      expect(redButton.isSelected, isTrue);
    });
  });
}
