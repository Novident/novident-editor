import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:novident_editor/novident_editor.dart';

void main() {
  group('NovidentStaticToolbar — showWhenNoSelection', () {
    setUpAll(() {
      TestWidgetsFlutterBinding.ensureInitialized();
    });

    EditorState createEditor() {
      final doc = Document.blank();
      final delta = Delta()..insert('Hello');
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

    testWidgets('shows items when selection is null and flag is true',
        (WidgetTester tester) async {
      final editorState = createEditor();
      addTearDown(() => editorState.dispose());

      expect(editorState.selection, isNull);

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: NovidentStaticToolbar(
              items: [_testItem('B')],
              editorState: editorState,
              showWhenNoSelection: true,
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.text('B'), findsOneWidget);
    });

    testWidgets('hides items when flag is false (default)',
        (WidgetTester tester) async {
      final editorState = createEditor();
      addTearDown(() => editorState.dispose());

      expect(editorState.selection, isNull);

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: NovidentStaticToolbar(
              items: [_testItem('X')],
              editorState: editorState,
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.text('X'), findsNothing);
    });

    testWidgets('shows items when editorState is null (flag on)',
        (WidgetTester tester) async {
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: NovidentStaticToolbar(
              items: [_testItem('Z')],
              editorState: null,
              showWhenNoSelection: true,
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.text('Z'), findsNothing);
    });
  });
}

ToolbarItem _testItem(String label) => ToolbarItem(
      id: 'test.$label',
      group: 1,
      isActive: showInTextTypeEvenWithoutSelection,
      builder: (ctx, state, hc, ic, tb) => Text(label),
    );
