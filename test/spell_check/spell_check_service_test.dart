import 'package:fake_async/fake_async.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:novident_editor/novident_editor.dart';

class _CountingChecker implements NovidentSpellChecker {
  _CountingChecker({Set<String>? dictionary})
      : dictionary = dictionary ?? {'hola', 'mundo', 'novident'};

  final Set<String> dictionary;
  int checkCalls = 0;
  int isValidCalls = 0;

  /// The last text passed to [check] (for whole-node assertions).
  String? lastCheckedText;

  @override
  bool isValid(String word) {
    isValidCalls++;
    return dictionary.contains(word.toLowerCase());
  }

  @override
  List<SpellCheckIssue> check(String text) {
    checkCalls++;
    lastCheckedText = text;
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
  String? get language => 'es';
}

void main() {
  const debounce = Duration(milliseconds: 400);

  List<TextInsert> markedInserts(Node node) => node.delta!
      .whereType<TextInsert>()
      .where(
        (insert) =>
            insert.attributes?[RichTextKeys.proofState] == proofStateError,
      )
      .toList();

  String markedText(Node node) =>
      markedInserts(node).map((insert) => insert.text).join();

  void seedText(Node node, String text) {
    node.updateAttributes({'delta': (Delta()..insert(text)).toJson()});
  }

  DeltaChange change({
    int start = 0,
    int end = 0,
    int shift = 0,
    int order = 0,
  }) =>
      DeltaChange(
        delta: Delta(),
        start: start,
        end: end,
        shift: shift,
        previousShift: 0,
        order: order,
      );

  group('SpellCheckService', () {
    test('attach schedules the initial full pass after the debounce', () {
      fakeAsync((async) {
        final doc = Document.blank(withInitialText: true);
        final node = doc.first!;
        seedText(node, 'hola wrld');
        final checker = _CountingChecker();
        final service = SpellCheckService(
          document: doc,
          checker: checker,
          debounce: debounce,
        )..attach();

        expect(checker.checkCalls, 0);
        async.elapse(debounce);
        expect(checker.checkCalls, 1);
        expect(markedText(node), 'wrld');
        expect(node.delta!.toPlainText(), 'hola wrld');
        service.dispose();
      });
    });

    test('any change re-analyzes the whole node', () {
      fakeAsync((async) {
        final doc = Document.blank(withInitialText: true);
        final node = doc.first!;
        seedText(node, 'hola wrld');
        final checker = _CountingChecker();
        final service = SpellCheckService(
          document: doc,
          checker: checker,
          debounce: debounce,
        )..attach();
        async.elapse(debounce);
        expect(markedText(node), 'wrld');

        // A change anywhere in the node → the WHOLE node is re-checked.
        doc.emitChanges(node, [change(end: 1)]);
        async.elapse(debounce);
        expect(checker.lastCheckedText, 'hola wrld');
        expect(markedText(node), 'wrld');
        service.dispose();
      });
    });

    test('corrected word loses its mark', () {
      fakeAsync((async) {
        final doc = Document.blank(withInitialText: true);
        final node = doc.first!;
        seedText(node, 'hola wrld');
        final checker = _CountingChecker(
          dictionary: {
            'hola',
            'mundo',
            'novident',
            'world',
          },
        );
        final service = SpellCheckService(
          document: doc,
          checker: checker,
          debounce: debounce,
        )..attach();
        async.elapse(debounce);
        expect(markedText(node), 'wrld');

        // El usuario corrige 'wrld' → 'world' (rango 5..9).
        seedText(node, 'hola world');
        doc.emitChanges(node, [change(start: 5, end: 9)]);
        async.elapse(debounce);
        expect(markedText(node), isEmpty);
        expect(node.delta!.toPlainText(), 'hola world');
        service.dispose();
      });
    });

    test('empty change triggers a full pass', () {
      fakeAsync((async) {
        final doc = Document.blank(withInitialText: true);
        final node = doc.first!;
        seedText(node, 'hola wrld');
        final checker = _CountingChecker();
        final service = SpellCheckService(
          document: doc,
          checker: checker,
          debounce: debounce,
        )..attach();
        async.elapse(debounce);
        expect(markedText(node), 'wrld');
        final callsAfterInitial = checker.checkCalls;

        // An empty changes list (undo/redo, remote, replacements) still
        // re-analyzes the node entirely.
        doc.emitChanges(node, const []);
        async.elapse(debounce);
        expect(checker.checkCalls, callsAfterInitial + 1);
        expect(checker.lastCheckedText, 'hola wrld');
        expect(markedText(node), 'wrld');
        service.dispose();
      });
    });

    test('burst of changes accumulates ranges so the whole burst is checked',
        () {
      fakeAsync((async) {
        final doc = Document.blank(withInitialText: true);
        final node = doc.first!;
        final checker = _CountingChecker();
        final service = SpellCheckService(
          document: doc,
          checker: checker,
          debounce: debounce,
        )..attach();
        async.elapse(debounce); // initial pass over the empty node

        // Rapid typing: one change per word, never letting the timer fire.
        seedText(node, 'jsdajdsaj');
        doc.emitChanges(node, [change(shift: 9)]);
        async.elapse(const Duration(milliseconds: 100));
        seedText(node, 'jsdajdsaj jjajjs');
        doc.emitChanges(node, [change(start: 10, end: 10, shift: 6)]);
        async.elapse(const Duration(milliseconds: 100));
        async.elapse(debounce); // now the user pauses

        final marked = markedText(node);
        expect(
          marked.contains('jsdajdsaj'),
          true,
          reason: 'first word of the burst must be checked',
        );
        expect(
          marked.contains('jjajjs'),
          true,
          reason: 'last word of the burst must be checked',
        );
        service.dispose();
      });
    });

    test('first change on an unseen node triggers a full revision', () {
      fakeAsync((async) {
        final doc = Document.blank(withInitialText: true);
        final node = doc.first!;
        final checker = _CountingChecker();
        final service = SpellCheckService(
          document: doc,
          checker: checker,
          debounce: debounce,
        )..attach();
        async.elapse(debounce); // empty node: nothing to analyze

        // Content loaded late, without emitting (e.g. injected after attach).
        seedText(node, 'hola wrld otro err');
        // A small granular change arrives (e.g. a keystroke at the end).
        doc.emitChanges(node, [change(start: 15, end: 15, shift: 1)]);
        async.elapse(debounce);

        final marked = markedText(node);
        expect(
          marked.contains('wrld'),
          true,
          reason: 'pre-existing content must be fully analyzed',
        );
        expect(marked.contains('otro'), true);
        expect(marked.contains('err'), true);
        service.dispose();
      });
    });

    test('changes coalesce: one analysis per idle window', () {
      fakeAsync((async) {
        final doc = Document.blank(withInitialText: true);
        final node = doc.first!;
        seedText(node, 'hola wrld');
        final checker = _CountingChecker();
        final service = SpellCheckService(
          document: doc,
          checker: checker,
          debounce: debounce,
        )..attach();
        async.elapse(debounce);
        final callsAfterInitial = checker.checkCalls;

        doc.emitChanges(node, [change(end: 1)]);
        async.elapse(const Duration(milliseconds: 100));
        doc.emitChanges(node, [change(start: 1, end: 2)]);
        async.elapse(const Duration(milliseconds: 100));
        doc.emitChanges(node, [change(start: 2, end: 3)]);
        async.elapse(debounce);

        expect(checker.checkCalls, callsAfterInitial + 1);
        service.dispose();
      });
    });

    test('the service write never emits delta changes (no loop)', () {
      fakeAsync((async) {
        final doc = Document.blank(withInitialText: true);
        final node = doc.first!;
        seedText(node, 'hola wrld');
        final events = <DeltaChangeEvent>[];
        doc.listenDeltaChanges(events.add);

        final service = SpellCheckService(
          document: doc,
          checker: _CountingChecker(),
          debounce: debounce,
        )..attach();
        async.elapse(debounce);

        expect(
          events,
          isEmpty,
          reason: 'proofState injection must not re-emit changes',
        );
        service.dispose();
      });
    });

    test('onLanguageChanged re-analyzes every node', () {
      fakeAsync((async) {
        final doc = Document.blank(withInitialText: true);
        final node = doc.first!;
        seedText(node, 'hola wrld');
        final checker = _CountingChecker();
        final service = SpellCheckService(
          document: doc,
          checker: checker,
          debounce: debounce,
        )..attach();
        async.elapse(debounce);
        final callsAfterInitial = checker.checkCalls;

        service.onLanguageChanged();
        async.elapse(debounce);
        expect(checker.checkCalls, callsAfterInitial + 1);
        expect(markedText(node), 'wrld');
        service.dispose();
      });
    });

    test('dispose detaches the listener', () {
      fakeAsync((async) {
        final doc = Document.blank(withInitialText: true);
        final node = doc.first!;
        seedText(node, 'hola wrld');
        final checker = _CountingChecker();
        final service = SpellCheckService(
          document: doc,
          checker: checker,
          debounce: debounce,
        )..attach();
        async.elapse(debounce);
        final callsAfterInitial = checker.checkCalls;

        service.dispose();
        doc.emitChanges(node, [change(end: 2)]);
        async.elapse(debounce);
        expect(checker.checkCalls, callsAfterInitial);
      });
    });

    test('existing rich-text attributes survive the analysis', () {
      fakeAsync((async) {
        final doc = Document.blank(withInitialText: true);
        final node = doc.first!;
        node.updateAttributes({
          'delta': (Delta()
                ..insert('hola ', attributes: {RichTextKeys.bold: true})
                ..insert('wrld', attributes: {RichTextKeys.bold: true}))
              .toJson(),
        });
        final service = SpellCheckService(
          document: doc,
          checker: _CountingChecker(),
          debounce: debounce,
        )..attach();
        async.elapse(debounce);

        final inserts = node.delta!.whereType<TextInsert>().toList();
        for (final insert in inserts) {
          expect(
            insert.attributes?[RichTextKeys.bold],
            true,
            reason: 'bold must survive on "${insert.text}"',
          );
        }
        expect(markedText(node), 'wrld');
        service.dispose();
      });
    });
  });
}
