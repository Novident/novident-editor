/// A misspelled range within a checked text.
///
/// Offsets are relative to the checked text and measured in UTF-16 code
/// units (the same convention used by editor [Delta] offsets).
///
/// No validity constraints are enforced here: issues come from external
/// checkers and may be hostile (negative or out-of-range offsets,
/// zero-length ranges). Consumers must normalize them — see
/// `buildProofSegments`.
class SpellCheckIssue {
  const SpellCheckIssue({
    required this.startOffset,
    required this.endOffset,
    required this.word,
  });

  /// First code unit of the misspelled word (inclusive).
  final int startOffset;

  /// One past the last code unit of the misspelled word (exclusive).
  final int endOffset;

  /// The misspelled word as found in the text.
  final String word;

  /// Length in UTF-16 code units.
  int get length => endOffset - startOffset;

  /// Whether the issue covers no text at all.
  bool get isEmpty => length == 0;

  @override
  bool operator ==(Object other) =>
      other is SpellCheckIssue &&
      other.startOffset == startOffset &&
      other.endOffset == endOffset &&
      other.word == word;

  @override
  int get hashCode => Object.hash(startOffset, endOffset, word);

  @override
  String toString() => 'SpellCheckIssue($startOffset..$endOffset, "$word")';
}
