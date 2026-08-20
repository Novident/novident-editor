import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:novident_editor/novident_editor.dart';

void main() {
  group('buildFontFamilyItem', () {
    setUpAll(() {
      TestWidgetsFlutterBinding.ensureInitialized();
    });

    EditorState editorWithText(String text) {
      final doc = Document.blank();
      final delta = Delta()..insert(text);
      doc.insert([
        0,
      ], [
        Node(
          type: 'paragraph',
          attributes: {
            blockComponentDelta: delta.toJson(),
          },
        ),
      ]);
      return EditorState(document: doc);
    }

    testWidgets('shows provider default when no selection and no explicit font',
        (WidgetTester tester) async {
      final editorState = editorWithText('Hello');
      addTearDown(() => editorState.dispose());

      // No selection → no delta, no style resolution.
      expect(editorState.selection, isNull);

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: Builder(
              builder: (context) {
                final item = buildFontFamilyItem(
                  fontFamilies: {'Arial', 'Georgia'},
                );
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

      // The provider fallback default is the platform default font — the
      // actual effective font that kDefaultBaseStyle resolves to.
      expect(find.text(getDefaultFont()), findsOneWidget);
    });

    testWidgets(
        'shows effective font from selection when text has inline delta',
        (WidgetTester tester) async {
      final editorState = editorWithText('Hello');
      addTearDown(() => editorState.dispose());

      // Apply Georgia via inline delta + set selection.
      editorState.updateSelectionWithReason(
        Selection.single(path: [0], startOffset: 0, endOffset: 2),
      );
      editorState.formatDelta(editorState.selection!, {
        RichTextKeys.fontFamily: 'Georgia',
      });

      // Re-select to refresh.
      editorState.updateSelectionWithReason(
        Selection.single(path: [0], startOffset: 0, endOffset: 2),
      );

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: Builder(
              builder: (context) {
                final item = buildFontFamilyItem(
                  fontFamilies: {'Arial', 'Georgia', 'Verdana'},
                );
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

      // The effective font is Georgia (from delta), not the provider default.
      expect(find.text('Georgia'), findsOneWidget);
    });

    testWidgets('dropdown opens and shows font list',
        (WidgetTester tester) async {
      final editorState = editorWithText('Hello');
      addTearDown(() => editorState.dispose());

      unawaited(
        editorState.updateSelectionWithReason(
          Selection.single(path: [0], startOffset: 0, endOffset: 2),
        ),
      );

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: Builder(
              builder: (context) {
                final item = buildFontFamilyItem(
                  fontFamilies: {'Arial', 'Georgia'},
                );
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

      // Button shows the provider default (platform default font) since no
      // delta applied.
      await tester.tap(find.text(getDefaultFont()));
      await tester.pumpAndSettle();

      // Dropdown items appear.
      expect(find.text('Georgia'), findsOneWidget);
      expect(find.text('Arial'), findsOneWidget);
    });
  });
}
