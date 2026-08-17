import 'package:novident_spell_check_interface/novident_spell_check_interface.dart';

/// Minimal deterministic checker for tests.
///
/// Tokenizes latin words (letters incl. accents and apostrophes) with a
/// simple regex; numbers, punctuation and other symbols are never checked,
/// mirroring the behavior documented for the real engine's tokenizer.
class FakeSpellChecker implements NovidentSpellChecker {
  FakeSpellChecker({
    Set<String>? dictionary,
    this.language = 'en',
  }) : dictionary = dictionary ?? {'hello', 'world', 'albert', 'novident'};

  final Set<String> dictionary;
  @override
  final String? language;

  static final RegExp _wordPattern = RegExp(r"[A-Za-zÀ-ÿ']+");

  @override
  bool isValid(String word) => dictionary.contains(word.toLowerCase());

  @override
  List<SpellCheckIssue> check(String text) {
    final issues = <SpellCheckIssue>[];
    for (final match in _wordPattern.allMatches(text)) {
      final word = match.group(0)!;
      if (!isValid(word)) {
        issues.add(SpellCheckIssue(
          startOffset: match.start,
          endOffset: match.end,
          word: word,
        ));
      }
    }
    return issues;
  }

  @override
  List<String> suggest(String word) => dictionary
      .where((entry) => entry.startsWith(word.substring(0, 1)))
      .take(5)
      .toList();
}
