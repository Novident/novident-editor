import 'package:meta/meta.dart';

@internal
abstract class Diff {
  final int start;

  Diff({
    required this.start,
  });
}

@internal
class InsertDiff extends Diff {
  final String textInserted;
  InsertDiff({
    required super.start,
    required this.textInserted,
  });

  @override
  String toString() {
    return 'InsertDiff(start: $start, text: $textInserted)';
  }
}

@internal
class DeleteDiff extends Diff {
  final int length;

  DeleteDiff({
    required super.start,
    required this.length,
  });

  @override
  String toString() {
    return 'DeleteDiff(start: $start, length: $length)';
  }
}

@internal
class ReplaceDiff extends Diff {
  final String replacementText;
  final int length;

  ReplaceDiff({
    required this.replacementText,
    required this.length,
    required super.start,
  });

  @override
  String toString() {
    return 'DeleteDiff(start: $start, end: ${length + start}, replace: $replacementText)';
  }
}

@internal
class NoDiff extends Diff {
  NoDiff() : super(start: 0);

  @override
  String toString() {
    return 'NoDiff';
  }
}
