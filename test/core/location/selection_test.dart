import 'package:flutter_test/flutter_test.dart';
import 'package:novident_editor/novident_editor.dart';

void main() {
  group('Selection.normalized', () {
    test('returns the same instance when forward (no allocation)', () {
      // start.offset > end.offset is forward within a single path.
      final sel = Selection(
        start: Position(path: [0], offset: 7),
        end: Position(path: [0], offset: 3),
      );
      expect(sel.isForward, true);
      expect(identical(sel.normalized, sel), true);
      expect(sel.normalized.start.offset, 7);
      expect(sel.normalized.end.offset, 3);
    });

    test('reverses (and allocates) when backward', () {
      final sel = Selection(
        start: Position(path: [0], offset: 3),
        end: Position(path: [0], offset: 7),
      );
      expect(sel.isBackward, true);
      expect(identical(sel.normalized, sel), false);
      expect(sel.normalized.start.offset, 7);
      expect(sel.normalized.end.offset, 3);
    });

    test('collapsed returns the same instance', () {
      // collapsed: start==end → isBackward==isForward==false → returns 'this'.
      final sel = Selection.collapsed(Position(path: [0], offset: 3));
      expect(identical(sel.normalized, sel), true);
    });

    test('forward across nodes returns the same instance', () {
      // [1] → [0] is forward (index 1 > 0).
      final sel = Selection(
        start: Position(path: [1], offset: 2),
        end: Position(path: [0], offset: 5),
      );
      expect(sel.isForward, true);
      expect(identical(sel.normalized, sel), true);
      expect(sel.normalized.start.path, [1]);
      expect(sel.normalized.end.path, [0]);
    });
  });
}
