import 'package:example/spell_check/hunspell_spell_checker.dart';
import 'package:fake_async/fake_async.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:novident_editor/novident_editor.dart';

const String kUserText =
    'The first thing Elara noticed was d askds akjdas jkdas jkdasjk ds kjdas '
    'jkasd jkadsj kdasjk daskjdsa jkdasj kdask jdaskj dsk jsad jkdas jkads '
    'jk das jkdas jkasdjk asdkj adsthe silence. Not the comfortable hush of '
    "a sleeping house, but a silence so complete it felt like a held breath.\n"
    'She sat up. Theds dsa jksdadsask jds akjads jk kasd jkasdjk afk '
    'kjdasjkasd candle by her bed had burned down to a stub of wax, and the '
    'window she was certain she had latched the night before now stood open, '
    'its curtains perfectly still despite the cold air pouring in. ';

void dumpMarked(Node node) {
  // ignore: avoid_print
  print('--- marked inserts ---');
  final delta = node.delta;
  if (delta == null) {
    // ignore: avoid_print
    print('(no delta)');
    return;
  }
  // ignore: avoid_print
  print('plain: "${delta.toPlainText().substring(0, delta.length)}..."');
  for (final op in delta) {
    if (op is TextInsert &&
        op.attributes?[RichTextKeys.proofState] == proofStateError) {
      // ignore: avoid_print
      print('MARKED(${op.length}): "${op.text}"');
    }
  }
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  test('BUG2: full-text analysis marking (user text)', () async {
    final checker = await HunspellSpellChecker.load();

    // Debug: inspect the issues the fixed library produces.
    final probe = checker.check('The first thing Elara noticed was d');
    // ignore: avoid_print
    print('--- issues for probe ---');
    for (final issue in probe) {
      // ignore: avoid_print
      print('ISSUE(${issue.startOffset}..${issue.endOffset}): '
          '"${issue.word}"');
    }

    fakeAsync((async) {
      final doc = Document.blank();
      final node = Node(type: 'paragraph');
      node.updateAttributes({
        'delta': (Delta()..insert(kUserText)).toJson(),
      });
      doc.root.insert(node);

      final service = SpellCheckService(
        document: doc,
        checker: checker,
        debounce: const Duration(milliseconds: 400),
      )..attach();
      async.elapse(const Duration(milliseconds: 500));
      dumpMarked(node);

      // Regression asserts: 'Elara' must be marked exactly, and no mark
      // may include text from the previous word ('thing').
      final delta = node.delta!;
      final marked = delta
          .whereType<TextInsert>()
          .where((insert) =>
              insert.attributes?[RichTextKeys.proofState] == proofStateError)
          .toList();
      expect(marked.any((insert) => insert.text == 'Elara'), true);
      expect(
        marked.any((insert) => insert.text.contains('thing')),
        false,
        reason: 'marks must not bleed into the previous word',
      );
      service.dispose();
    });
  });

  test('BUG1: rapid typing burst only checks the last word', () async {
    final checker = await HunspellSpellChecker.load();

    fakeAsync((async) {
      final doc = Document.blank(withInitialText: true);
      final node = doc.first!;
      final service = SpellCheckService(
        document: doc,
        checker: checker,
        debounce: const Duration(milliseconds: 400),
      )..attach();
      async.elapse(const Duration(milliseconds: 500));

      // Burst: simulate a transaction per keystroke without letting the
      // idle timer fire (each event restarts the debounce).
      var text = '';
      final typed = 'jsdajdsaj jjajjs';
      for (final char in typed.split('')) {
        text += char;
        seedText(node, text);
        doc.emitChanges(node, [
          DeltaChange(
            delta: Delta(),
            start: text.length - 1,
            end: text.length - 1,
            shift: 1,
            previousShift: 0,
            order: 0,
          ),
        ]);
        async.elapse(const Duration(milliseconds: 50));
      }
      // Now the user pauses.
      async.elapse(const Duration(milliseconds: 500));
      dumpMarked(node);

      // Regression asserts: both words of the burst must be marked.
      final delta = node.delta!;
      final marked = delta
          .whereType<TextInsert>()
          .where((insert) =>
              insert.attributes?[RichTextKeys.proofState] == proofStateError)
          .map((insert) => insert.text)
          .join();
      expect(marked.contains('jsdajdsaj'), true,
          reason: 'first word of the burst must be checked');
      expect(marked.contains('jjajjs'), true,
          reason: 'last word of the burst must be checked');
      service.dispose();
    });
  });
}

void seedText(Node node, String text) {
  node.updateAttributes({'delta': (Delta()..insert(text)).toJson()});
}
