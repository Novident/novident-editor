import 'package:flutter_test/flutter_test.dart';
import 'package:novident_editor/novident_editor.dart';

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
  group('EditorState span pipeline wrapper', () {
    test('spanPipeline is null without a checker and no wrapper', () {
      final state = EditorState(document: Document.blank());
      expect(state.spanPipeline, isNull);
    });

    test('setSpanPipelineWrapper composes over the default pipeline', () {
      final state = EditorState(document: Document.blank());
      state.setSpanPipelineWrapper(
        (effective) => ZenSpanPipeline(effective),
      );
      final pipeline = state.spanPipeline;
      expect(pipeline, isA<ZenSpanPipeline>());
    });

    test('clearSpanPipelineWrapper restores the effective pipeline', () {
      final state = EditorState(document: Document.blank());
      state.setSpanPipelineWrapper(
        (effective) => ZenSpanPipeline(effective),
      );
      state.clearSpanPipelineWrapper();
      expect(state.spanPipeline, isNull);
    });

    test('wrapper composes over the spell check pipeline', () {
      final state = EditorState(document: Document.blank());
      state.editorStyle = EditorStyle.desktop(
        spellChecker: const _FakeChecker(),
      );
      expect(state.spanPipeline, isA<SpellCheckSpanPipeline>());

      state.setSpanPipelineWrapper(
        (effective) => ZenSpanPipeline(effective),
      );
      final pipeline = state.spanPipeline;
      expect(pipeline, isA<ZenSpanPipeline>());

      state.clearSpanPipelineWrapper();
      expect(state.spanPipeline, isA<SpellCheckSpanPipeline>());
    });
  });
}
