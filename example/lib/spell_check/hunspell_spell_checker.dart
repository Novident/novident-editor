import 'package:novident_editor/novident_editor.dart';
import 'package:novident_spell_checker/novident_spell_checker.dart';

/// Demo [NovidentSpellChecker] backed by the standalone `novident_spell_checker`
/// library and the bundled Hunspell `en_US` dictionary (`.dic` + `.aff`).
///
/// Loaded once at startup with [load]:
/// - validity: compact [Trie] over the expanded dictionary (O(1) per word,
///   used by the idle analysis hot path);
/// - suggestions: lazy [SymSpellEx] index (heavy — trained once here for the
///   demo; a real app would build it lazily or in an isolate).
class HunspellSpellChecker implements NovidentSpellChecker {
  HunspellSpellChecker._({
    required this.vocabulary,
    required this.suggester,
  });

  static HunspellSpellChecker? _instance;

  /// The loaded instance. Call [load] before accessing it.
  static HunspellSpellChecker get instance {
    final instance = _instance;
    if (instance == null) {
      throw StateError('HunspellSpellChecker.load() has not been called.');
    }
    return instance;
  }

  final Trie vocabulary;
  final SymSpellEx suggester;
  final CoreTokenizer _tokenizer = CoreTokenizer();

  /// Runtime personal dictionary: learned words and forgotten words.
  final Set<String> _learned = {};
  final Set<String> _forgotten = {};

  /// LRU-ish cache for [suggest]: the context menu suggests the same word on
  /// repeated right-clicks, and each SymSpell lookup is not free.
  final Map<String, List<String>> _suggestCache = {};
  static const int _suggestCacheCapacity = 64;

  /// Remembers a suggestion list. Public so the demo app and its tests can
  /// inspect the cache.
  List<String>? cachedSuggestions(String word) => _suggestCache[word];

  @override
  String? get language => Languages.english;

  @override
  bool isValid(String word) {
    final normalized = word.toLowerCase();
    if (_forgotten.contains(normalized)) {
      return false;
    }
    return _learned.contains(normalized) || vocabulary.contains(normalized);
  }

  @override
  void addWord(String word) {
    final normalized = word.toLowerCase().trim();
    _forgotten.remove(normalized);
    if (_learned.add(normalized)) {
      vocabulary.insert(normalized);
      suggester.add(normalized, 1, Languages.english);
      _suggestCache.clear();
    }
  }

  @override
  void forgetWord(String word) {
    final normalized = word.toLowerCase().trim();
    _learned.remove(normalized);
    _forgotten.add(normalized);
    _suggestCache.clear();
  }

  /// Loads, expands and trains the bundled en_US dictionary.
  static Future<HunspellSpellChecker> load() async {
    final dictionary = await AssetDictionaryLoader.loadHunspellWithAffixes(
      'assets/dictionaries/en_US.dic',
      'assets/dictionaries/en_US.aff',
    );

    final vocabulary = Trie.fromDictionary(dictionary);
    final suggester = SymSpellEx(MemoryStore())..initialize();
    suggester.trainDictionary(dictionary, Languages.english);

    _instance = HunspellSpellChecker._(
      vocabulary: vocabulary,
      suggester: suggester,
    );
    return _instance!;
  }

  @override
  List<SpellCheckIssue> check(String text) {
    final issues = <SpellCheckIssue>[];
    for (final token in _tokenizer.tokenize(text)) {
      // novident_spell_checker >= 1.0.1: Token.offset is the exact start
      // offset in the original input; the issue must cover ONLY the word
      // (spacing stays outside the mark).
      if (token.tag == TokenTags.word &&
          token.value.length >= 2 &&
          !isValid(token.value)) {
        issues.add(SpellCheckIssue(
          startOffset: token.offset,
          endOffset: token.offset + token.value.length,
          word: token.value,
        ));
      }
    }
    return issues;
  }

  @override
  List<String> suggest(String word) {
    // Touch for LRU recency.
    final cached = _suggestCache.remove(word);
    if (cached != null) {
      _suggestCache[word] = cached;
      return cached;
    }
    final suggestions = suggester
        .lookup(word, language: Languages.english, maxSuggestions: 7)
        .map((suggestion) => suggestion.suggestion ?? suggestion.term)
        .toList();
    _suggestCache[word] = suggestions;
    if (_suggestCache.length > _suggestCacheCapacity) {
      for (final key in _suggestCache.keys.take(8)) {
        _suggestCache.remove(key);
      }
    }
    return suggestions;
  }
}
