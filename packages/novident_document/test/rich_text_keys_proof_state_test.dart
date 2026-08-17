import 'package:flutter_test/flutter_test.dart';
import 'package:novident_editor_document/novident_editor_document.dart';

void main() {
  group('RichTextKeys.proofState', () {
    test('key exists and is part of the sliced attributes', () {
      expect(RichTextKeys.proofState, 'proofState');
      expect(RichTextKeys.supportSliced, contains(RichTextKeys.proofState));
    });

    test('is inherited from the previous character (index > 0)', () {
      final delta = Delta()
        ..insert('hola', attributes: {
          RichTextKeys.proofState: 'error',
          RichTextKeys.bold: true,
        });

      final attributes = delta.sliceAttributes(2);
      expect(attributes, isNotNull);
      expect(attributes![RichTextKeys.proofState], 'error');
      expect(attributes[RichTextKeys.bold], true);
    });

    test('is inherited from the next character (index == 0)', () {
      final delta = Delta()
        ..insert('hola', attributes: {
          RichTextKeys.proofState: 'error',
        });

      final attributes = delta.sliceAttributes(0);
      expect(attributes, isNotNull);
      expect(attributes![RichTextKeys.proofState], 'error');
    });

    test('survives the partial-sliced logic for code/href', () {
      // When the previous char has `code` (partialSliced) and the next one
      // also has it, the attributes are returned as-is: proofState must
      // survive alongside code.
      final delta = Delta()
        ..insert('ab', attributes: {
          RichTextKeys.code: true,
          RichTextKeys.proofState: 'error',
        });

      final attributes = delta.sliceAttributes(1);
      expect(attributes, isNotNull);
      expect(attributes![RichTextKeys.code], true);
      expect(attributes[RichTextKeys.proofState], 'error');
    });

    test('is dropped when the source attributes are not fully supported', () {
      // A custom attribute that is not in supportSliced blocks slicing at
      // index 0 (rule: only slice if every key is supported).
      final delta = Delta()
        ..insert('ab', attributes: {
          'custom_unknown_key': 1,
          RichTextKeys.proofState: 'error',
        });

      expect(delta.sliceAttributes(0), isNull);
    });
  });
}
