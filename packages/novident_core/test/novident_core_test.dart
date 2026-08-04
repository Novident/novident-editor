import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:novident_core/novident_core.dart';

void main() {
  group('Position', () {
    test('creates with path and offset', () {
      final pos = Position(path: [0, 1], offset: 5);
      expect(pos.path, [0, 1]);
      expect(pos.offset, 5);
    });

    test('equality', () {
      final a = Position(path: [0], offset: 3);
      final b = Position(path: [0], offset: 3);
      final c = Position(path: [0], offset: 4);
      expect(a, equals(b));
      expect(a, isNot(equals(c)));
    });

    test('copyWith changes offset', () {
      final pos = Position(path: [0], offset: 3);
      final copy = pos.copyWith(offset: 10);
      expect(copy.offset, 10);
      expect(copy.path, [0]);
    });

    test('invalid position', () {
      final pos = Position.invalid();
      expect(pos.path, [-1]);
      expect(pos.offset, -1);
    });

    test('toJson and fromJson roundtrip', () {
      final pos = Position(path: [0, 2, 1], offset: 42);
      final json = pos.toJson();
      final restored = Position.fromJson(json);
      expect(restored, equals(pos));
    });
  });

  group('Selection', () {
    test('collapsed', () {
      final sel = Selection.collapsed(Position(path: [0], offset: 5));
      expect(sel.isCollapsed, isTrue);
      expect(sel.isSingle, isTrue);
    });

    test('single non-collapsed', () {
      final sel = Selection.single(path: [0], startOffset: 2, endOffset: 8);
      expect(sel.isCollapsed, isFalse);
      expect(sel.isSingle, isTrue);
      expect(sel.normalized.startIndex, 2);
      expect(sel.normalized.endIndex, 8);
    });

    test('equals', () {
      final a = Selection.single(path: [0], startOffset: 1, endOffset: 5);
      final b = Selection.single(path: [0], startOffset: 1, endOffset: 5);
      expect(a, equals(b));
    });
  });

  group('TextStyleConfiguration', () {
    test('defaults', () {
      const config = TextStyleConfiguration();
      expect(config.text.fontSize, 16.0);
      expect(config.lineHeight, 1.5);
    });

    test('copyWith', () {
      const config = TextStyleConfiguration();
      final copy = config.copyWith(lineHeight: 2.0);
      expect(copy.lineHeight, 2.0);
      expect(copy.text.fontSize, 16.0);
    });
  });

  group('ColorExtension', () {
    test('tryToColor hex', () {
      expect('#FF0000'.tryToColor(), isNotNull);
      expect('0xFF0000'.tryToColor(), isNotNull);
    });

    test('tryToColor invalid', () {
      expect('not-a-color'.tryToColor(), isNull);
    });
  });

  group('TextStyleExtensions', () {
    test('combine merges', () {
      const base = TextStyle(fontSize: 14);
      const other = TextStyle(fontWeight: FontWeight.bold);
      final combined = base.combine(other);
      expect(combined.fontSize, 14);
      expect(combined.fontWeight, FontWeight.bold);
    });

    test('combine null returns self', () {
      const base = TextStyle(fontSize: 14);
      final result = base.combine(null);
      expect(result.fontSize, 14);
    });
  });

  group('TextSpanExtensions', () {
    test('copyWith text', () {
      final span = TextSpan(text: 'hello');
      final copy = span.copyWith(text: 'world');
      expect(copy.text, 'world');
    });

    test('updateTextStyle null returns self', () {
      final span = TextSpan(text: 'hello');
      expect(identical(span.updateTextStyle(null), span), isTrue);
    });
  });

  group('PathSelectionExtension', () {
    test('inSelection true when inside', () {
      final path = [1];
      final sel = Selection(
        start: Position(path: [0], offset: 0),
        end: Position(path: [2], offset: 5),
      );
      expect(path.inSelection(sel), isTrue);
    });

    test('inSelection false when outside', () {
      final path = [3];
      final sel = Selection(
        start: Position(path: [0], offset: 0),
        end: Position(path: [2], offset: 5),
      );
      expect(path.inSelection(sel), isFalse);
    });

    test('inSelection null selection returns false', () {
      expect([0].inSelection(null), isFalse);
    });
  });
}
