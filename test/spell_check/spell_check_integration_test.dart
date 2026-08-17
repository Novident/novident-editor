import 'package:fake_async/fake_async.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:novident_editor/novident_editor.dart';

class _FakeChecker implements NovidentSpellChecker {
  _FakeChecker({Set<String>? dictionary})
      : dictionary = dictionary ?? {'hola', 'mundo'};

  final Set<String> dictionary;
  int checkCalls = 0;

  @override
  bool isValid(String word) => dictionary.contains(word.toLowerCase());

  @override
  List<SpellCheckIssue> check(String text) {
    checkCalls++;
    final issues = <SpellCheckIssue>[];
    final regex = RegExp("[A-Za-zÀ-ÿ']+");
    for (final match in regex.allMatches(text)) {
      final word = match.group(0)!;
      if (!isValid(word)) {
        issues.add(
          SpellCheckIssue(
            startOffset: match.start,
            endOffset: match.end,
            word: word,
          ),
        );
      }
    }
    return issues;
  }

  @override
  List<String> suggest(String word) => const [];

  @override
  void addWord(String word) => dictionary.add(word.toLowerCase());

  @override
  void forgetWord(String word) => dictionary.remove(word.toLowerCase());

  @override
  String? get language => 'es';
}

String markedText(Node node) => node.delta!
    .whereType<TextInsert>()
    .where(
      (insert) =>
          insert.attributes?[RichTextKeys.proofState] == proofStateError,
    )
    .map((insert) => insert.text)
    .join();

void main() {
  const debounce = Duration(milliseconds: 400);

  test('undo restores the node and re-analyzes it', () {
    fakeAsync((async) {
      final state = EditorState.blank();
      final node = state.document.first!;
      final checker = _FakeChecker();
      final service = SpellCheckService(
        document: state.document,
        checker: checker,
        debounce: debounce,
      )..attach();
      async.elapse(debounce); // initial pass (empty node)

      // 1. Type 'hola wrld' (sealed history item).
      state.apply(
        state.transaction..insertText(node, 0, 'hola wrld'),
        skipHistoryDebounce: true,
      );
      async.flushMicrotasks();
      async.elapse(debounce);
      expect(markedText(node), 'wrld');

      // 2. Type 'x' at the end (another sealed item).
      state.apply(
        state.transaction..insertText(node, 9, 'x'),
        skipHistoryDebounce: true,
      );
      async.flushMicrotasks();
      async.elapse(debounce);
      final callsBeforeUndo = checker.checkCalls;

      // 3. Undo → the node recovers the historical delta (old marks) and an
      // empty change is emitted → the service re-analyzes the whole node.
      state.undoManager.undo();
      async.flushMicrotasks();
      async.elapse(debounce);

      expect(node.delta!.toPlainText(), 'hola wrld');
      expect(markedText(node), 'wrld');
      expect(
        checker.checkCalls,
        callsBeforeUndo + 1,
        reason: 'undo must trigger a re-analysis',
      );
      service.dispose();
    });
  });

  test('redo re-analyzes the node', () {
    fakeAsync((async) {
      final state = EditorState.blank();
      final node = state.document.first!;
      final checker = _FakeChecker();
      final service = SpellCheckService(
        document: state.document,
        checker: checker,
        debounce: debounce,
      )..attach();
      async.elapse(debounce);

      state.apply(
        state.transaction..insertText(node, 0, 'hola wrld'),
        skipHistoryDebounce: true,
      );
      async.flushMicrotasks();
      async.elapse(debounce);
      expect(markedText(node), 'wrld');

      state.undoManager.undo();
      async.flushMicrotasks();
      async.elapse(debounce);
      final callsBeforeRedo = checker.checkCalls;

      state.undoManager.redo();
      async.flushMicrotasks();
      async.elapse(debounce);

      expect(node.delta!.toPlainText(), 'hola wrld');
      expect(markedText(node), 'wrld');
      expect(
        checker.checkCalls,
        callsBeforeRedo + 1,
        reason: 'redo must trigger a re-analysis',
      );
      service.dispose();
    });
  });

  test('pasted nodes are analyzed', () {
    fakeAsync((async) {
      final state = EditorState.blank();
      final checker = _FakeChecker();
      final service = SpellCheckService(
        document: state.document,
        checker: checker,
        debounce: debounce,
      )..attach();
      async.elapse(debounce);

      // Paste two paragraphs with text (single call keeps their order).
      final transaction = state.transaction
        ..insertNodes(const [
          0,
        ], [
          paragraphNode(delta: Delta()..insert('hola wrld')),
          paragraphNode(delta: Delta()..insert('otro err')),
        ]);
      state.apply(transaction);
      async.flushMicrotasks();
      async.elapse(debounce);

      final first = state.document.root.children[0];
      final second = state.document.root.children[1];
      expect(markedText(first), 'wrld');
      expect(markedText(second), 'otroerr');
      service.dispose();
    });
  });
}
