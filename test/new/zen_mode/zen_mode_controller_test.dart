import 'package:flutter_test/flutter_test.dart';
import 'package:novident_editor/novident_editor.dart';

import '../util/node_util.dart';

class _FakeChecker implements NovidentSpellChecker {
  const _FakeChecker();

  @override
  bool isValid(String word) => true;

  @override
  List<SpellCheckIssue> check(String text) => const [];

  @override
  List<String> suggest(String word) => const [];

  @override
  Future<List<String>> suggestAsync(String word) async => suggest(word);

  @override
  void addWord(String word) {}

  @override
  void forgetWord(String word) {}

  @override
  String? get language => 'es';
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('ZenModeController public API', () {
    test('attach registers the span pipeline wrapper', () {
      final state = EditorState(document: Document.blank());
      final controller = ZenModeController();
      controller.attach(editorState: state);
      expect(state.spanPipeline, isA<ZenSpanPipeline>());
      controller.detach();
      expect(state.spanPipeline, isNull);
    });

    test('detach restores the spell check pipeline', () {
      final state = EditorState(document: Document.blank());
      state.editorStyle = EditorStyle.desktop(
        spellChecker: const _FakeChecker(),
      );
      final controller = ZenModeController();
      controller.attach(editorState: state);
      expect(state.spanPipeline, isA<ZenSpanPipeline>());
      controller.detach();
      expect(state.spanPipeline, isA<SpellCheckSpanPipeline>());
    });

    test('toggle flips enabled', () {
      final controller = ZenModeController();
      expect(controller.enabled, isTrue);
      controller.toggle();
      expect(controller.enabled, isFalse);
      controller.toggle();
      expect(controller.enabled, isTrue);
    });

    test('focusedTopLevelRange updates on selection change', () async {
      final state = EditorState(document: Document.blank());
      state.document.root.addParagraphs(3);
      final controller = ZenModeController();
      controller.attach(editorState: state);

      await state.updateSelectionWithReason(
        Selection.collapsed(Position(path: [2])),
      );
      expect(controller.focusedTopLevelRange.value, (start: 2, end: 2));
      controller.detach();
    });

    test('selectAll clears the focused range', () async {
      final state = EditorState(document: Document.blank());
      state.document.root.addParagraphs(3);
      final controller = ZenModeController();
      controller.attach(editorState: state);

      await state.updateSelectionWithReason(
        Selection.collapsed(Position(path: [1])),
      );
      expect(controller.focusedTopLevelRange.value, (start: 1, end: 1));

      await state.updateSelectionWithReason(
        Selection(
          start: Position(path: [0]),
          end: Position(path: [2], offset: 1),
        ),
        reason: SelectionUpdateReason.selectAll,
      );
      expect(controller.focusedTopLevelRange.value, isNull);
      controller.detach();
    });

    test('dispose clears the pipeline wrapper', () {
      final state = EditorState(document: Document.blank());
      final controller = ZenModeController();
      controller.attach(editorState: state);
      controller.dispose();
      expect(state.spanPipeline, isNull);
    });
  });
}