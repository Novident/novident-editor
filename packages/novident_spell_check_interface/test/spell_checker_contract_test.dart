import 'package:flutter_test/flutter_test.dart';
import 'package:novident_spell_check_interface/novident_spell_check_interface.dart';

import 'helpers/fake_spell_checker.dart';

/// Implementation that only provides the synchronous contract, to prove the
/// [NovidentSpellChecker.suggestAsync] default delegates to [suggest].
class _SyncOnlyChecker extends NovidentSpellChecker {
  @override
  bool isValid(String word) => false;

  @override
  List<SpellCheckIssue> check(String text) => const [];

  @override
  List<String> suggest(String word) => const ['world'];

  @override
  String? get language => 'en';
}

void main() {
  group('SpellCheckIssue', () {
    test('length is the UTF-16 distance between offsets', () {
      const issue = SpellCheckIssue(startOffset: 2, endOffset: 5, word: 'abc');
      expect(issue.length, 3);
      expect(issue.isEmpty, false);
    });

    test('zero-length issues are considered empty', () {
      const issue = SpellCheckIssue(startOffset: 2, endOffset: 2, word: '');
      expect(issue.isEmpty, true);
    });

    test('equality and hashCode', () {
      const a = SpellCheckIssue(startOffset: 0, endOffset: 3, word: 'wrd');
      const b = SpellCheckIssue(startOffset: 0, endOffset: 3, word: 'wrd');
      const c = SpellCheckIssue(startOffset: 1, endOffset: 3, word: 'wrd');
      expect(a, b);
      expect(a.hashCode, b.hashCode);
      expect(a == c, false);
    });
  });

  group('NovidentSpellChecker contract (FakeSpellChecker)', () {
    test('isValid is case-insensitive', () {
      final checker = FakeSpellChecker();
      expect(checker.isValid('hello'), true);
      expect(checker.isValid('Hello'), true);
      expect(checker.isValid('HELLO'), true);
      expect(checker.isValid('wrld'), false);
    });

    test('check returns issues with correct UTF-16 offsets', () {
      final checker = FakeSpellChecker();
      final issues = checker.check('hello wrld hello');
      expect(issues, hasLength(1));
      expect(issues.single.word, 'wrld');
      expect(issues.single.startOffset, 6);
      expect(issues.single.endOffset, 10);
    });

    test('check ignores numbers and punctuation', () {
      final checker = FakeSpellChecker();
      expect(checker.check('123, 456.78!'), isEmpty);
      expect(checker.check('hello, 123 wrld!'), hasLength(1));
    });

    test('single-char words follow the dictionary (engine decides)', () {
      final checker = FakeSpellChecker(dictionary: {'a', 'i'});
      expect(checker.isValid('a'), true);
      expect(checker.isValid('x'), false);
      final issues = checker.check('a x');
      expect(issues, hasLength(1));
      expect(issues.single.word, 'x');
      expect(issues.single.startOffset, 2);
    });

    test('suggest is lazy and returns candidates by first letter', () {
      final checker = FakeSpellChecker();
      // 'world' shares the first letter with 'wrld'.
      expect(checker.suggest('wrld'), contains('world'));
      expect(checker.suggest('albrt'), contains('albert'));
    });

    test('suggestAsync defaults to the synchronous suggest', () async {
      final checker = _SyncOnlyChecker();
      expect(
        await checker.suggestAsync('wrld'),
        equals(checker.suggest('wrld')),
      );
    });

    test('suggestAsync can be overridden by async engines', () async {
      final checker = FakeSpellChecker();
      final suggestions = await checker.suggestAsync('wrld');
      expect(suggestions, contains('world'));
    });

    test('language is exposed', () {
      expect(FakeSpellChecker(language: 'es').language, 'es');
      expect(FakeSpellChecker().language, 'en');
    });

    test('addWord learns a word at runtime', () {
      final checker = FakeSpellChecker();
      expect(checker.isValid('kaleen'), false);
      checker.addWord('Kaleen');
      expect(checker.isValid('kaleen'), true);
      expect(checker.isValid('KALEEN'), true);
    });

    test('forgetWord unlearns a word at runtime', () {
      final checker = FakeSpellChecker();
      expect(checker.isValid('hello'), true);
      checker.forgetWord('hello');
      expect(checker.isValid('hello'), false);
    });

    test('addWord after forgetWord wins, and vice versa', () {
      final checker = FakeSpellChecker();
      checker.forgetWord('hello');
      checker.addWord('hello');
      expect(checker.isValid('hello'), true);
      checker.forgetWord('hello');
      expect(checker.isValid('hello'), false);
    });

    test('check reflects the learned/forgotten words', () {
      final checker = FakeSpellChecker();
      checker.addWord('kaleen');
      expect(checker.check('hello kaleen'), isEmpty);
      checker.forgetWord('hello');
      final issues = checker.check('hello kaleen');
      expect(issues, hasLength(1));
      expect(issues.single.word, 'hello');
    });
  });

  group('proofStateError constant', () {
    test('is the simple string marker agreed for the delta attribute', () {
      expect(proofStateError, 'err');
    });
  });
}
