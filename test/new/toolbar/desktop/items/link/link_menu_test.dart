import 'package:novident_editor/novident_editor.dart';
import 'package:novident_editor/src/editor/toolbar/desktop/items/link/link_menu.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import '../../../../infra/testable_editor.dart';
import '../../../../util/editor_text_finders.dart';

void main() async {
  setUpAll(() {
    TestWidgetsFlutterBinding.ensureInitialized();
  });

  group('link_menu.dart', () {
    testWidgets('test empty link menu actions', (tester) async {
      const link = 'appflowy.io';
      var submittedText = '';
      final linkMenu = LinkMenu(
        onOpenLink: () {},
        onCopyLink: () {},
        onRemoveLink: () {},
        onSubmitted: (text) {
          submittedText = text;
        },
        onDismiss: () {},
      );
      final editor = tester.editor;
      await editor.startTesting();
      await tester.pumpWidget(
        MaterialApp(
          home: Material(
            child: linkMenu,
          ),
        ),
      );
      await tester.pumpAndSettle();
      expect(find.byType(TextButton), findsNothing);
      expect(find.byType(TextField), findsOneWidget);

      await tester.tap(find.byType(TextField));
      await tester.enterText(find.byType(TextField), link);
      await tester.pumpAndSettle();
      await tester.testTextInput.receiveAction(TextInputAction.done);
      await tester.pumpAndSettle(const Duration(milliseconds: 500));

      expect(submittedText, link);
    });

    testWidgets('test tap linked text', (tester) async {
      const link = 'appflowy.io';

      final editor = tester.editor;
      // create a link [appflowy.io](appflowy.io)
      editor.addParagraph(
        builder: (index) => Delta()
          ..insert(
            link,
            attributes: {
              RichTextKeys.href: link,
            },
          ),
      );
      await editor.startTesting();

      final finder = findEditorRichText(link);
      expect(finder, findsOneWidget);

      // tap the link
      await tester.tap(finder);
      tester.binding.scheduleWarmUpFrame();
      await tester.pumpAndSettle(const Duration(seconds: 1));
      final linkMenu = find.byType(LinkMenu);
      expect(linkMenu, findsOneWidget);
      // The editor keeps rendering the link, and the menu shows it again
      // inside its text field.
      expect(findEditorRichText(link), findsOneWidget);
      final menuField = find.descendant(
        of: linkMenu,
        matching: find.byType(TextFormField),
      );
      expect(menuField, findsOneWidget);
      expect(
        tester.widget<TextFormField>(menuField).controller?.text,
        link,
      );

      await editor.dispose();
    });

    testWidgets('test tap linked text when editor not editable',
        (tester) async {
      const link = 'appflowy.io';

      final editor = tester.editor;
      //create a link [appflowy.io](appflowy.io)
      editor.addParagraph(
        builder: (index) => Delta()..insert(link, attributes: {"href": link}),
      );
      await editor.startTesting(editable: false);
      await tester.pumpAndSettle();

      final finder = findEditorRichText(link);
      expect(finder, findsOneWidget);

      await tester.tap(finder);
      await tester.pumpAndSettle();

      final linkMenu = find.byType(LinkMenu);
      expect(linkMenu, findsNothing);

      expect(findEditorRichText(link), findsOneWidget);

      await editor.dispose();
    });

    testWidgets('test dismiss link menu by pressing ESC', (tester) async {
      var dismissed = false;

      final linkMenu = LinkMenu(
        onOpenLink: () {},
        onCopyLink: () {},
        onRemoveLink: () {},
        onSubmitted: (text) {},
        onDismiss: () {
          dismissed = true;
        },
      );

      await tester.pumpWidget(
        MaterialApp(
          home: Material(
            child: linkMenu,
          ),
        ),
      );

      expect(find.byType(TextButton), findsNothing);
      expect(find.byType(TextField), findsOneWidget);

      // Simulate keyboard press event for the Escape key
      await tester.sendKeyEvent(LogicalKeyboardKey.escape);
      await tester.pumpAndSettle();

      expect(dismissed, true);
    });
  });
}
