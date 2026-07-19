import 'package:novident_editor/novident_editor.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../../../new/infra/testable_editor.dart';

void main() {
  testWidgets('textDecorationMobileToolbarItem', (WidgetTester tester) async {
    const text = 'Welcome to Novident 😁';
    final editor = tester.editor..addParagraphs(3, initialText: text);
    await editor.startTesting(
      inMobile: true,
      withFloatingToolbar: true,
    );

    var selection = Selection.single(
      path: [1],
      startOffset: 2,
      endOffset: text.length - 2,
    );

    await editor.updateSelection(selection);

    // Tap text decoration toolbar item
    await tester.tap(find.byType(IconButton).first);
    await tester.pumpAndSettle(const Duration(milliseconds: 500));

    // Show its menu and it has 4 buttons
    expect(find.byType(MobileToolbarItemMenu), findsOneWidget);
    expect(
      find.text(NovidentEditorL10n.current.bold),
      findsOneWidget,
    );
    expect(
      find.text(NovidentEditorL10n.current.italic),
      findsOneWidget,
    );
    expect(
      find.text(NovidentEditorL10n.current.underline),
      findsOneWidget,
    );
    expect(
      find.text(NovidentEditorL10n.current.strikethrough),
      findsOneWidget,
    );

    // Test bold button
    await tester.tap(
      find.widgetWithText(
        MobileToolbarItemMenuBtn,
        NovidentEditorL10n.current.bold,
      ),
    );
    await tester.pumpAndSettle(const Duration(milliseconds: 500));
    final node = editor.editorState.getNodeAtPath([1]);
    expect(
      node?.allSatisfyInSelection(selection, (delta) {
        return delta.whereType<TextInsert>().every(
              (element) =>
                  element.attributes?[NovidentRichTextKeys.bold] == true,
            );
      }),
      true,
    );

    // Test Italic button
    await tester.tap(
      find.widgetWithText(
        MobileToolbarItemMenuBtn,
        NovidentEditorL10n.current.italic,
      ),
    );
    await tester.pumpAndSettle(const Duration(milliseconds: 500));
    expect(
      node?.allSatisfyInSelection(selection, (delta) {
        return delta.whereType<TextInsert>().every(
              (element) =>
                  element.attributes?[NovidentRichTextKeys.italic] == true,
            );
      }),
      true,
    );

    // Test Underline button
    await tester.tap(
      find.widgetWithText(
        MobileToolbarItemMenuBtn,
        NovidentEditorL10n.current.underline,
      ),
    );
    await tester.pumpAndSettle(const Duration(milliseconds: 500));
    expect(
      node?.allSatisfyInSelection(selection, (delta) {
        return delta.whereType<TextInsert>().every(
              (element) =>
                  element.attributes?[NovidentRichTextKeys.underline] == true,
            );
      }),
      true,
    );

    // Test Strikethrough button
    await tester.tap(
      find.widgetWithText(
        MobileToolbarItemMenuBtn,
        NovidentEditorL10n.current.strikethrough,
      ),
    );
    await tester.pumpAndSettle(const Duration(milliseconds: 500));
    expect(
      node?.allSatisfyInSelection(selection, (delta) {
        return delta.whereType<TextInsert>().every(
              (element) =>
                  element.attributes?[NovidentRichTextKeys.strikethrough] ==
                  true,
            );
      }),
      true,
    );
  });
}
