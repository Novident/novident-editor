import 'package:flutter_test/flutter_test.dart';
import 'package:novident_editor/novident_editor.dart';

void main() {
  group('NovidentFontProvider', () {
    group('fallback', () {
      test('provides universal safe fonts with Roboto as default', () {
        final provider = NovidentFontProvider.fallback();

        expect(provider.availableFonts, isNotEmpty);
        expect(provider.availableFonts.first, 'Roboto');
        expect(provider.defaultFontFamily, 'Roboto');
        expect(
          provider.availableFonts,
          containsAll([
            'Arial',
            'Times New Roman',
            'Courier New',
            'Georgia',
            'Verdana',
            'Helvetica',
          ]),
        );
      });

      test('availableFonts is immutable', () {
        final provider = NovidentFontProvider.fallback();

        expect(
          () => provider.availableFonts.add('FakeFont'),
          throwsUnsupportedError,
        );
      });
    });

    group('fromList', () {
      test('uses first font as default when defaultFamily is omitted', () {
        final provider = NovidentFontProvider.fromList(['Arial', 'Georgia']);

        expect(provider.defaultFontFamily, 'Arial');
        expect(provider.availableFonts, ['Arial', 'Georgia']);
      });

      test('explicit defaultFamily overrides first font', () {
        final provider = NovidentFontProvider.fromList(
          ['Arial', 'Georgia'],
          defaultFamily: 'Georgia',
        );

        expect(provider.defaultFontFamily, 'Georgia');
        expect(provider.availableFonts, ['Arial', 'Georgia']);
      });

      test('rejects empty font list', () {
        expect(
          () => NovidentFontProvider.fromList([]),
          throwsAssertionError,
        );
      });

      test('single font is valid', () {
        final provider = NovidentFontProvider.fromList(['Roboto']);

        expect(provider.availableFonts, ['Roboto']);
        expect(provider.defaultFontFamily, 'Roboto');
      });
    });
  });
}
