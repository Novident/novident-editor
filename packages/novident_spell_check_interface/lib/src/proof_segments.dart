import 'spell_check_issue.dart';

/// A contiguous piece of checked text, either valid or misspelled.
///
/// Segments produced by [buildProofSegments] are contiguous and cover the
/// whole input text; offsets are UTF-16 code units relative to it.
class ProofSegment {
  const ProofSegment({
    required this.startOffset,
    required this.endOffset,
    required this.text,
    required this.isError,
  })  : assert(startOffset >= 0, 'startOffset must be >= 0'),
        assert(endOffset >= startOffset, 'endOffset must be >= startOffset');

  /// First code unit of the segment (inclusive).
  final int startOffset;

  /// One past the last code unit of the segment (exclusive).
  final int endOffset;

  /// The exact text of the segment.
  final String text;

  /// Whether the segment is a misspelled word.
  final bool isError;

  /// Length in UTF-16 code units.
  int get length => endOffset - startOffset;

  @override
  String toString() =>
      'ProofSegment($startOffset..$endOffset, error: $isError, "$text")';
}

/// Converts spell-check [issues] into contiguous segments covering [text].
///
/// Normalization rules (defensive against hostile or buggy checkers):
/// - issues are sorted by start offset (then end offset);
/// - zero-length issues are dropped;
/// - offsets are clamped to `[0, text.length]`;
/// - issues fully contained in a previous one are dropped;
/// - overlapping issues are truncated so the earliest one wins;
/// - gaps between issues become valid segments.
///
/// Resulting segments are contiguous: `segment[i].endOffset ==
/// segment[i + 1].startOffset`, the first starts at 0 and the last ends at
/// `text.length`. Concatenating the segment texts reproduces [text] exactly.
List<ProofSegment> buildProofSegments(
  String text,
  List<SpellCheckIssue> issues,
) {
  if (text.isEmpty) {
    return const [];
  }
  if (issues.isEmpty) {
    return [
      ProofSegment(
        startOffset: 0,
        endOffset: text.length,
        text: text,
        isError: false,
      ),
    ];
  }

  final normalized = <SpellCheckIssue>[];
  final sorted = [...issues]..sort((a, b) {
      final byStart = a.startOffset.compareTo(b.startOffset);
      return byStart != 0 ? byStart : a.endOffset.compareTo(b.endOffset);
    });

  for (final issue in sorted) {
    var start = issue.startOffset.clamp(0, text.length);
    var end = issue.endOffset.clamp(start, text.length);
    if (end <= start) {
      continue;
    }
    if (normalized.isNotEmpty) {
      final lastEnd = normalized.last.endOffset;
      if (start < lastEnd) {
        if (end <= lastEnd) {
          continue; // fully contained in the previous issue
        }
        start = lastEnd; // overlap: earliest issue wins, truncate this one
      }
    }
    normalized.add(
      SpellCheckIssue(startOffset: start, endOffset: end, word: issue.word),
    );
  }

  final segments = <ProofSegment>[];
  var cursor = 0;
  for (final issue in normalized) {
    if (issue.startOffset > cursor) {
      segments.add(
        ProofSegment(
          startOffset: cursor,
          endOffset: issue.startOffset,
          text: text.substring(cursor, issue.startOffset),
          isError: false,
        ),
      );
    }
    segments.add(
      ProofSegment(
        startOffset: issue.startOffset,
        endOffset: issue.endOffset,
        text: text.substring(issue.startOffset, issue.endOffset),
        isError: true,
      ),
    );
    cursor = issue.endOffset;
  }
  if (cursor < text.length) {
    segments.add(
      ProofSegment(
        startOffset: cursor,
        endOffset: text.length,
        text: text.substring(cursor),
        isError: false,
      ),
    );
  }
  return segments;
}
