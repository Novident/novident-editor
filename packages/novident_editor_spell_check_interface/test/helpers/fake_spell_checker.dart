import 'package:novident_editor_spell_check_interface/novident_editor_spell_check_interface.dart';

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

  final Set<String> _learned = {};
  final Set<String> _forgotten = {};

  static final RegExp _wordPattern = RegExp(r"[A-Za-zÀ-ÿ']+");

  @override
  bool isValid(String word) {
    final normalized = word.toLowerCase();
    if (_forgotten.contains(normalized)) {
      return false;
    }
    return _learned.contains(normalized) || dictionary.contains(normalized);
  }

  @override
  void addWord(String word) {
    final normalized = word.toLowerCase();
    _forgotten.remove(normalized);
    _learned.add(normalized);
  }

  @override
  void forgetWord(String word) {
    final normalized = word.toLowerCase();
    _learned.remove(normalized);
    _forgotten.add(normalized);
  }

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

  @override
  Future<List<String>> suggestAsync(String word) async {
    // Simulates a tiny engine-side latency so async consumers are exercised.
    await Future<void>.delayed(Duration.zero);
    return suggest(word);
  }
}
