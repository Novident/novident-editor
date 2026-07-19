import 'package:novident_editor/novident_editor.dart';
import 'package:flutter_test/flutter_test.dart';

void main() async {
  group('delta_markdown_encoder.dart', () {
    test('bold', () {
      final delta = Delta(
        operations: [
          TextInsert('Welcome to '),
          TextInsert(
            'Novident',
            attributes: {
              BuiltInAttributeKey.bold: true,
            },
          ),
        ],
      );
      final result = DeltaMarkdownEncoder().convert(delta);
      expect(result, 'Welcome to **Novident**');
    });

    test('italic', () {
      final delta = Delta(
        operations: [
          TextInsert('Welcome to '),
          TextInsert(
            'Novident',
            attributes: {
              BuiltInAttributeKey.italic: true,
            },
          ),
        ],
      );
      final result = DeltaMarkdownEncoder().convert(delta);
      expect(result, 'Welcome to _Novident_');
    });

    test('underline', () {
      final delta = Delta(
        operations: [
          TextInsert('Welcome to '),
          TextInsert(
            'Novident',
            attributes: {
              BuiltInAttributeKey.underline: true,
            },
          ),
        ],
      );
      final result = DeltaMarkdownEncoder().convert(delta);
      expect(result, 'Welcome to <u>Novident</u>');
    });

    test('strikethrough', () {
      final delta = Delta(
        operations: [
          TextInsert('Welcome to '),
          TextInsert(
            'Novident',
            attributes: {
              BuiltInAttributeKey.strikethrough: true,
            },
          ),
        ],
      );
      final result = DeltaMarkdownEncoder().convert(delta);
      expect(result, 'Welcome to ~~Novident~~');
    });

    test('href', () {
      final delta = Delta(
        operations: [
          TextInsert('Welcome to '),
          TextInsert(
            'Novident',
            attributes: {
              BuiltInAttributeKey.href: 'https://appflowy.io',
            },
          ),
        ],
      );
      final result = DeltaMarkdownEncoder().convert(delta);
      expect(result, 'Welcome to [Novident](https://appflowy.io)');
    });

    test('code', () {
      final delta = Delta(
        operations: [
          TextInsert('Welcome to '),
          TextInsert(
            'Novident',
            attributes: {
              BuiltInAttributeKey.code: true,
            },
          ),
        ],
      );
      final result = DeltaMarkdownEncoder().convert(delta);
      expect(result, 'Welcome to `Novident`');
    });

    test('composition', () {
      final delta = Delta(
        operations: [
          TextInsert(
            'Welcome',
            attributes: {
              BuiltInAttributeKey.code: true,
              BuiltInAttributeKey.italic: true,
              BuiltInAttributeKey.bold: true,
              BuiltInAttributeKey.underline: true,
            },
          ),
          TextInsert(' '),
          TextInsert(
            'to',
            attributes: {
              BuiltInAttributeKey.italic: true,
              BuiltInAttributeKey.bold: true,
              BuiltInAttributeKey.strikethrough: true,
            },
          ),
          TextInsert(' '),
          TextInsert(
            'Novident',
            attributes: {
              BuiltInAttributeKey.href: 'https://appflowy.io',
              BuiltInAttributeKey.bold: true,
              BuiltInAttributeKey.italic: true,
            },
          ),
        ],
      );
      final result = DeltaMarkdownEncoder().convert(delta);
      expect(
        result,
        '***<u>`Welcome`</u>*** ***~~to~~*** ***[Novident](https://appflowy.io)***',
      );
    });

    test('formula', () {
      final delta = Delta(
        operations: [
          TextInsert('This is a formula:'),
          TextInsert(
            '\$',
            attributes: {
              BuiltInAttributeKey.formula: 'E = MC ^ 2',
            },
          ),
          TextInsert('.'),
        ],
      );
      final result = DeltaMarkdownEncoder().convert(delta);
      expect(result, 'This is a formula:\$E = MC ^ 2\$.');
    });
  });
}
