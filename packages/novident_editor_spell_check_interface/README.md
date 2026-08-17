# Novident Spell Check Interface

The engine-agnostic spell-checking contract for [Novident Editor](https://github.com/Novident/novident-editor).
Pure Dart — no Flutter dependency — so checkers can be built, tested, and reused anywhere.

## Features

- **`NovidentSpellChecker`** — the single contract any engine implements:
  - `isValid(word)` — synchronous validation hot path (expected O(1), e.g. a trie);
  - `check(text)` — misspelled ranges of a text as `SpellCheckIssue`s;
  - `suggest(word)` / `suggestAsync(word)` — lazy suggestions for context menus
    (`suggestAsync` defaults to `suggest`; heavy engines override it to answer
    from a worker isolate so the UI never blocks);
  - `addWord` / `forgetWord` — runtime personal dictionary (no-op by default);
  - `language` — the active language code.
- **`SpellCheckIssue`** — `startOffset`/`endOffset` (UTF-16 code units relative
  to the checked text) plus the offending `word`.
- **`proofStateError` / `proofStateGrammarError`** — the attribute values stored
  under `RichTextKeys.proofState` in a delta to mark misspelled ranges. Only the
  engine writes them, and only for errors; the base editor ignores the key.

## Getting started

```yaml
dependencies:
  novident_spell_check_interface: <latest>
```

## Usage

### Implement a checker

```dart
import 'package:novident_spell_check_interface/novident_spell_check_interface.dart';

class DictionaryChecker extends NovidentSpellChecker {
  DictionaryChecker(this.dictionary);

  final Set<String> dictionary;
  final Set<String> _learned = {};
  static final _word = RegExp(r"[A-Za-zÀ-ÿ']+");

  @override
  String get language => 'en';

  @override
  bool isValid(String word) {
    final w = word.toLowerCase();
    return _learned.contains(w) || dictionary.contains(w);
  }

  @override
  List<SpellCheckIssue> check(String text) => _word
      .allMatches(text)
      .map((m) => (word: m.group(0)!, start: m.start, end: m.end))
      .where((m) => !isValid(m.word))
      .map((m) => SpellCheckIssue(
            startOffset: m.start,
            endOffset: m.end,
            word: m.word,
          ))
      .toList();

  @override
  List<String> suggest(String word) =>
      dictionary.where((d) => d.startsWith(word[0])).toList();

  @override
  void addWord(String word) => _learned.add(word.toLowerCase());

  @override
  void forgetWord(String word) => _learned.remove(word.toLowerCase());
}
```

### Go async for heavy engines

For engines with a heavy suggestion index (e.g. a `SymSpellEx` index living in
a worker isolate), override `suggestAsync` and leave `suggest` serving a local
cache — this is the pattern the editor's demo app ships:

```dart
@override
List<String> suggest(String word) => _cache[word] ?? const [];

@override
Future<List<String>> suggestAsync(String word) async {
  final cached = _cache[word];
  if (cached != null) return cached;
  final suggestions = await _worker.request(word); // port round-trip
  return _cache[word] = suggestions;
}
```

Consumers (context menus) call `suggestAsync` so the menu opens immediately
and fills the suggestions when the engine answers — no frame is ever blocked.

## How marks flow back into the editor

The engine does not render anything. The editor's spell-check service runs
`check` out of band (after typing inactivity), writes `proofStateError` into
the node delta under the `proofState` key, and the render pipeline merges the
misspelled style for those ranges. This package only defines the contract and
the values; the mark lifecycle belongs to the editor.

## Additional information

- **Repository**: [github.com/Novident/novident-editor](https://github.com/Novident/novident-editor)
- **Issue tracker**: [github.com/Novident/novident-editor/issues](https://github.com/Novident/novident-editor/issues)
- **License**: Mozilla Public License 2.0

Reference implementation: the main editor's `example/` ships a full Hunspell
checker (`HunspellSpellChecker`) backed by `novident_spell_checker`, including
a worker isolate that parses the dictionary, expands affix forms, and trains
the suggestion index entirely off the UI isolate.
