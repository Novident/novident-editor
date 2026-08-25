import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:novident_editor/novident_editor.dart';

import '../test_helpers/mobile_toolbar_style_test_widget.dart';

class _StubService implements MobileToolbarWidgetService {
  @override
  void closeItemMenu() {}
}

/// Regression tests for the mobile text decoration toolbar item (BIUS).
///
/// Captures the bug where a collapsed cursor placed inside already-formatted
/// text does NOT highlight the corresponding button. The mobile menu only
/// consults `toggledStyle` (empty unless the user just toggled), ignoring the
/// previous character's attributes — unlike `fontSize`/`fontFamily`.
void main() {
  setUpAll(() async {
    TestWidgetsFlutterBinding.ensureInitialized();
    await NovidentEditorLocalizations.load(const Locale('en'));
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

  Future<void> pumpDecorationMenu(
    WidgetTester tester,
    EditorState editorState,
  ) async {
    await tester.pumpWidget(
      Material(
        child: MobileToolbarStyleTestWidget(
          child: Builder(
            builder: (context) {
              final menu = textDecorationMobileToolbarItem.itemMenuBuilder!(
                context,
                editorState,
                _StubService(),
              );
              return menu ?? const SizedBox.shrink();
            },
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();
  }

  bool isSelected(WidgetTester tester, String label) {
    return tester
        .widget<MobileToolbarItemMenuBtn>(
          find.widgetWithText(MobileToolbarItemMenuBtn, label),
        )
        .isSelected;
  }

  group('collapsed selection', () {
    final attributes = <(String, String Function())>[
      (RichTextKeys.bold, () => NovidentEditorL10n.current.bold),
      (RichTextKeys.italic, () => NovidentEditorL10n.current.italic),
      (RichTextKeys.underline, () => NovidentEditorL10n.current.underline),
      (
        RichTextKeys.strikethrough,
        () => NovidentEditorL10n.current.strikethrough,
      ),
    ];

    for (final (key, labelFn) in attributes) {
      testWidgets('cursor inside $key text highlights the button',
          (tester) async {
        final editorState = editorWithText(
          'Hello',
          attributes: {key: true},
        );
        addTearDown(() => editorState.dispose());

        unawaited(
          editorState.updateSelectionWithReason(
            Selection.single(path: [0], startOffset: 2),
          ),
        );

        await pumpDecorationMenu(tester, editorState);

        expect(isSelected(tester, labelFn()), isTrue);
      });

      testWidgets('cursor inside plain text does not highlight the button',
          (tester) async {
        final editorState = editorWithText('Hello');
        addTearDown(() => editorState.dispose());

        unawaited(
          editorState.updateSelectionWithReason(
            Selection.single(path: [0], startOffset: 2),
          ),
        );

        await pumpDecorationMenu(tester, editorState);

        expect(isSelected(tester, labelFn()), isFalse);
      });
    }
  });

  group('expanded selection (regression guard)', () {
    testWidgets('selection over bold text highlights bold', (tester) async {
      final editorState = editorWithText(
        'Hello',
        attributes: {RichTextKeys.bold: true},
      );
      addTearDown(() => editorState.dispose());

      unawaited(
        editorState.updateSelectionWithReason(
          Selection.single(path: [0], startOffset: 0, endOffset: 5),
        ),
      );

      await pumpDecorationMenu(tester, editorState);

      expect(isSelected(tester, NovidentEditorL10n.current.bold), isTrue);
    });
  });
}
