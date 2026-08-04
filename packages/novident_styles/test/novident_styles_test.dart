import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:novident_styles/novident_styles.dart';

void main() {
  group('NovidentStyleDefinition', () {
    test('default values', () {
      const style = NovidentStyleDefinition(id: 'test', name: 'Test');
      expect(style.id, 'test');
      expect(style.name, 'Test');
      expect(style.fontSize, 12.0);
      expect(style.bold, false);
      expect(style.italic, false);
      expect(style.alignment, TextAlign.left);
    });

    test('custom values', () {
      const style = NovidentStyleDefinition(
        id: 'h1',
        name: 'Heading 1',
        fontSize: 32,
        bold: true,
        alignment: TextAlign.center,
      );
      expect(style.fontSize, 32);
      expect(style.bold, true);
      expect(style.alignment, TextAlign.center);
    });

    test('merge overrides properties', () {
      const base =
          NovidentStyleDefinition(id: 'base', name: 'Base', fontSize: 14);
      const override = NovidentStyleDefinition(
        id: 'override',
        name: 'Override',
        fontSize: 20,
        bold: true,
      );
      final merged = base.merge(override);
      expect(merged.fontSize, 20);
      expect(merged.bold, true);
      expect(merged.id, 'override');
    });

    test('nextSame sets next to id', () {
      const style =
          NovidentStyleDefinition.nextSame(id: 'normal', name: 'Normal');
      expect(style.next, 'normal');
    });
  });

  group('NovidentStyleSpacing', () {
    test('defaults are null', () {
      const spacing = NovidentStyleSpacing();
      expect(spacing.before, isNull);
      expect(spacing.after, isNull);
      expect(spacing.lineHeight, isNull);
    });

    test('merge prefers other values', () {
      const base = NovidentStyleSpacing(before: 8, after: 4);
      const other = NovidentStyleSpacing(before: 16);
      final merged = base.merge(other);
      expect(merged.before, 16);
      expect(merged.after, 4);
    });
  });

  group('NovidentStyleIndent', () {
    test('defaults are null', () {
      const indent = NovidentStyleIndent();
      expect(indent.left, isNull);
      expect(indent.firstLineIndent, isNull);
    });

    test('merge prefers other', () {
      const base = NovidentStyleIndent(left: 10, firstLineIndent: 20);
      const other = NovidentStyleIndent(firstLineIndent: 30);
      final merged = base.merge(other);
      expect(merged.firstLineIndent, 30);
      expect(merged.left, 10);
    });
  });

  group('NovidentStyleRegistry', () {
    test('lookup by id', () {
      final style = NovidentStyleDefinition(id: 'normal', name: 'Normal');
      final registry = NovidentStyleRegistry({'normal': style});
      expect(registry['normal'], equals(style));
      expect(registry['missing'], isNull);
    });

    test('resolve walks basedOn chain', () {
      final base =
          NovidentStyleDefinition(id: 'base', name: 'Base', fontSize: 12);
      final normal = NovidentStyleDefinition(
        id: 'normal',
        name: 'Normal',
        basedOn: 'base',
        fontSize: 16,
      );
      final registry = NovidentStyleRegistry({
        'base': base,
        'normal': normal,
      });

      final resolved = registry.resolve('normal', baseStyle: base);
      expect(resolved, isNotNull);
      expect(resolved!.fontSize, 16);
      expect(resolved.bold, false);
    });

    test('warns on cyclic basedOn via callback', () {
      final a = NovidentStyleDefinition(id: 'a', name: 'A', basedOn: 'b');
      final b = NovidentStyleDefinition(id: 'b', name: 'B', basedOn: 'a');
      String? warning;
      final registry = NovidentStyleRegistry(
        {'a': a, 'b': b},
        onWarning: (msg) => warning = msg,
      );
      final resolved = registry.resolve('a', baseStyle: a);
      expect(warning, isNotNull);
      expect(warning, contains('cyclic'));
      expect(resolved, isNotNull);
    });

    test('copyWith adds styles', () {
      final style = NovidentStyleDefinition(id: 'normal', name: 'Normal');
      final registry = NovidentStyleRegistry({'normal': style});
      final h1 = NovidentStyleDefinition(id: 'h1', name: 'H1', fontSize: 32);
      final updated = registry.copyWith({'h1': h1});
      expect(updated['h1'], equals(h1));
      expect(updated['normal'], equals(style));
    });
  });
}
