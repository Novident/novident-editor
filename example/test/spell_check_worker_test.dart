import 'dart:convert';
import 'dart:typed_data';

import 'package:example/spell_check/hunspell_spell_checker.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('worker isolate serves validity and async suggestions', () async {
    // Tiny Hunspell dictionary: optional count header + stems. The .aff is
    // minimal (no affix rules), so only stems are trained.
    final dictionary = Uint8List.fromList(
      utf8.encode('3\nhello\nworld\nrun\n'),
    );
    final affix = Uint8List.fromList(
      utf8.encode('SET UTF-8\n'),
    );

    final checker = await HunspellSpellChecker.loadFromBytes(
      dictionary,
      affix,
    );
    addTearDown(checker.dispose);

    // Validity is served by the synchronous UI-side trie.
    expect(checker.isValid('hello'), true);
    expect(checker.isValid('world'), true);
    expect(checker.isValid('run'), true);
    expect(checker.isValid('wrld'), false);

    // Suggestions are answered by the worker isolate.
    final suggestions = await checker.suggestAsync('wrld');
    expect(suggestions, contains('world'));

    // The sync contract entry point only serves the cache: 'wrld' was
    // cached by the suggestAsync call above.
    expect(checker.suggest('wrld'), contains('world'));

    // Runtime learning: validity is local & immediate…
    checker.addWord('kaleen');
    expect(checker.isValid('kaleen'), true);
    expect(checker.isValid('KALEEN'), true);
    // …and the worker learns the word too, so it is suggested. Note that
    // addWord clears the suggestion cache on purpose (learned words can
    // change suggestion results).
    final learned = await checker.suggestAsync('kaleen');
    expect(learned, contains('kaleen'));
  });

  test('suggest warms the cache in the background when missing', () async {
    final dictionary = Uint8List.fromList(
      utf8.encode('2\nhello\nworld\n'),
    );
    final affix = Uint8List.fromList(
      utf8.encode('SET UTF-8\n'),
    );

    final checker = await HunspellSpellChecker.loadFromBytes(
      dictionary,
      affix,
    );
    addTearDown(checker.dispose);

    // First sync call: cache miss → empty, background fetch started.
    expect(checker.cachedSuggestions('wrld'), isNull);
    expect(checker.suggest('wrld'), isEmpty);

    // Wait for the worker round-trip to fill the cache.
    await checker.suggestAsync('wrld');
    expect(checker.cachedSuggestions('wrld'), isNotNull);
    expect(checker.suggest('wrld'), contains('world'));
  });
}
