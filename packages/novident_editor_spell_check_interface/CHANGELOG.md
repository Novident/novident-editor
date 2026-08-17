# Changelog

## 1.0.0

* Initial release: the spell-check engine contract for Novident Editor.
* `NovidentSpellChecker` — `isValid` (synchronous hot path, expected O(1)),
  `check` (misspelled ranges of a text), `suggest` (lazy), `suggestAsync`
  (defaults to `suggest`; heavy engines override it to answer from a worker
  isolate), `addWord`/`forgetWord` (runtime personal dictionary, no-op by
  default), and `language`.
* `SpellCheckIssue` — `startOffset`/`endOffset` (UTF-16, relative to the
  checked text) plus the offending `word`.
* `proofStateError` / `proofStateGrammarError` — the attribute values stored
  under `RichTextKeys.proofState` in a delta to mark misspelled ranges. Only
  the error value is ever written, and only by the spell-check engine; the
  base editor ignores the key entirely.
