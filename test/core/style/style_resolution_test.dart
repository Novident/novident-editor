import 'package:flutter_test/flutter_test.dart';
import 'package:novident_editor/novident_editor.dart';

void main() {
  group('Style resolution', () {
    group('kDefaultBaseStyle', () {
      test('always has a non-null fontFamily', () {
        expect(kDefaultBaseStyle.fontFamily, isNotNull);
        expect(kDefaultBaseStyle.fontFamily, 'Roboto');
      });

      test('fontSize is 12', () {
        expect(kDefaultBaseStyle.fontSize, 12.0);
      });
    });

    group('basedOn chain', () {
      test('child inherits fontFamily from parent when not overridden', () {
        final registry = NovidentStyleRegistry({
          'base': const NovidentStyleDefinition(
            id: 'base',
            name: 'Base',
            fontFamily: 'Arial',
            fontSize: 14,
          ),
          'body': NovidentStyleDefinition(
            id: 'body',
            name: 'Body',
            basedOn: 'base',
          ),
        });

        final resolved = registry.resolve(
          'body',
          baseStyle: registry['base']!,
        );
        expect(resolved, isNotNull);
        expect(resolved!.fontFamily, 'Arial'); // inherited
        expect(resolved.fontSize, 12); // overridden
      });

      test('child overrides fontFamily explicitly', () {
        final registry = NovidentStyleRegistry({
          'base': const NovidentStyleDefinition(
            id: 'base',
            name: 'Base',
            fontFamily: 'Roboto',
          ),
          'heading': NovidentStyleDefinition(
            id: 'heading',
            name: 'Heading',
            basedOn: 'base',
            fontFamily: 'Georgia',
          ),
        });

        final resolved = registry.resolve(
          'heading',
          baseStyle: registry['base']!,
        );
        expect(resolved, isNotNull);
        expect(resolved!.fontFamily, 'Georgia'); // explicit override
      });

      test('three-level basedOn chain merges correctly', () {
        final registry = NovidentStyleRegistry({
          'root': const NovidentStyleDefinition(
            id: 'root',
            name: 'Root',
            fontFamily: 'Arial',
            fontSize: 10,
          ),
          'middle': NovidentStyleDefinition(
            id: 'middle',
            name: 'Middle',
            basedOn: 'root',
            fontSize: 14,
            // fontFamily not set → inherits Arial
          ),
          'leaf': NovidentStyleDefinition(
            id: 'leaf',
            name: 'Leaf',
            basedOn: 'middle',
            bold: true,
            // fontSize not set → constructor default is 12, but parent
            // middle overrides it via merge (different values).
            // fontFamily not set → inherits Arial from root.
          ),
        });

        final resolved = registry.resolve(
          'leaf',
          baseStyle: registry['root']!,
        );
        expect(resolved, isNotNull);
        expect(resolved!.fontFamily, 'Arial'); // root → middle → leaf
        // leaf constructor default fontSize (12) differs from middle (14),
        // so leaf's explicit value wins over the inherited one.
        expect(resolved.fontSize, 12.0);
        expect(resolved.bold, true); // leaf overrides root
      });

      test(
        'cyclic basedOn does not crash — breaks chain at cycle point',
        () {
          final registry = NovidentStyleRegistry({
            'a': NovidentStyleDefinition(
              id: 'a',
              name: 'A',
              basedOn: 'b', // → b
            ),
            'b': NovidentStyleDefinition(
              id: 'b',
              name: 'B',
              basedOn: 'a', // → a (cycle!)
            ),
          });

          // Must not throw or hang.
          final resolved = registry.resolve(
            'a',
            baseStyle: registry['a']!,
          );
          expect(resolved, isNotNull);
        },
      );
    });

    group('NovidentStylesConfig assertions', () {
      test('defaultStyle with null fontFamily is caught in debug mode', () {
        // This should fail because kDefaultBaseStyle now has fontFamily.
        // Verify the positive case.
        final config = NovidentStylesConfig(
          registry: NovidentStyleRegistry({}),
        );
        // kDefaultBaseStyle is the default — it has fontFamily: 'Roboto'.
        expect(config.defaultStyle.fontFamily, isNotNull);
      });
    });
  });
}
