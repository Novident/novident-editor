import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:novident_editor/novident_editor.dart';

/// Verifies that `NovidentEditor.fontProvider` is correctly injected into
/// `EditorState.fontProvider` and that the fallback works when omitted.
void main() {
  group('Font provider injection', () {
    setUpAll(() {
      TestWidgetsFlutterBinding.ensureInitialized();
    });

    testWidgets('EditorState.fontProvider is set from NovidentEditor',
        (WidgetTester tester) async {
      final editorState = EditorState.blank();
      addTearDown(() => editorState.dispose());

      final provider = NovidentFontProvider.fromList(['TestFont']);

      await tester.pumpWidget(
        MaterialApp(
          localizationsDelegates: const [
            NovidentEditorLocalizations.delegate,
          ],
          supportedLocales:
              NovidentEditorLocalizations.delegate.supportedLocales,
          home: Scaffold(
            body: NovidentEditor(
              editorState: editorState,
              fontProvider: provider,
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(editorState.fontProvider, isNotNull);
      expect(editorState.fontProvider!.defaultFontFamily, 'TestFont');
      expect(editorState.fontProvider!.availableFonts, ['TestFont']);
    });

    testWidgets('falls back to NovidentFontProvider.fallback() when omitted',
        (WidgetTester tester) async {
      final editorState = EditorState.blank();
      addTearDown(() => editorState.dispose());

      await tester.pumpWidget(
        MaterialApp(
          localizationsDelegates: const [
            NovidentEditorLocalizations.delegate,
          ],
          supportedLocales:
              NovidentEditorLocalizations.delegate.supportedLocales,
          home: Scaffold(
            body: NovidentEditor(
              editorState: editorState,
              // fontProvider omitted → fallback
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(editorState.fontProvider, isNotNull);
      expect(editorState.fontProvider!.defaultFontFamily, getDefaultFont());
      expect(editorState.fontProvider!.availableFonts.length, greaterThan(3));
    });

    testWidgets('buildFontFamilyItem uses injected provider',
        (WidgetTester tester) async {
      final editorState = EditorState.blank();
      addTearDown(() => editorState.dispose());

      // Set fontProvider directly on editorState (simulates NovidentEditor
      // injection without needing the full editor widget tree).
      editorState.fontProvider =
          NovidentFontProvider.fromList(['CustomA', 'CustomB']);

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: NovidentStaticToolbar(
              items: [buildFontFamilyItem()],
              editorState: editorState,
              showWhenNoSelection: true,
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      // The font item reads from editorState.fontProvider → shows 'CustomA'.
      expect(find.text('CustomA'), findsOneWidget);
    });
  });
}
