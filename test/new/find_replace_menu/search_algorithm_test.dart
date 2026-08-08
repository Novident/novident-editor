import 'package:flutter_test/flutter_test.dart';
import 'package:novident_editor/src/editor/find_replace_menu/search_algorithm.dart';

void main() {
  group('search_algorithm_test.dart', () {
    late SearchAlgorithm algorithm;

    setUp(() {
      algorithm = DartBuiltIn();
    });

    test('search algorithm returns the index of the only found pattern', () {
      const pattern = 'Novident';
      const text = 'Welcome to Novident 😁';

      final List<int> result =
          algorithm.searchMethod(pattern, text).map((e) => e.start).toList();
      expect(result, [11]);
    });

    test('search algorithm returns the index of the multiple found patterns',
        () {
      const pattern = 'Novident';
      const text = '''
Welcome to Novident 😁. Novident is an open source writing suite designed to be a free, 
cross-platform alternative that offers a familiar experience for writers who rely on 
project-based composition tools. Built with modularity and freedom in mind, 
Novident provides authors, researchers, and storytellers with powerful organizational 
features without the cost or limitations of closed source code.
      ''';

      final List<int> result =
          algorithm.searchMethod(pattern, text).map((e) => e.start).toList();
      expect(result, [11, 24, 252]);
    });

    test('search algorithm returns empty list if pattern is not found', () {
      const pattern = 'Flutter';
      const text = 'Welcome to Novident 😁';

      final result = algorithm.searchMethod(pattern, text);

      expect(result, []);
    });

    test('search algorithm returns pattern index if pattern is non-ASCII', () {
      const pattern = '😁';
      const text = 'Welcome to Novident 😁';

      final List<int> result =
          algorithm.searchMethod(pattern, text).map((e) => e.start).toList();
      expect(result, [20]);
    });

    test(
        'search algorithm returns pattern index if pattern is not separate word',
        () {
      const pattern = 'Nov';
      const text = 'Welcome to Novident 😁';

      final List<int> result =
          algorithm.searchMethod(pattern, text).map((e) => e.start).toList();
      expect(result, [11]);
    });

    test('search algorithm returns empty list bcz it is case sensitive', () {
      const pattern = 'NOVIDENT';
      const text = 'Welcome to Novident 😁';

      final List<int> result =
          algorithm.searchMethod(pattern, text).map((e) => e.start).toList();
      expect(result, []);
    });

    test('case insensitive search', () async {
      final pattern = RegExp('NOVIDENT', caseSensitive: false);
      const text = 'Welcome to Novident 😁';

      final List<int> result =
          algorithm.searchMethod(pattern, text).map((e) => e.start).toList();
      expect(result, [11]);
    });

    test('regex search', () async {
      final pattern = RegExp('N[a-z]v', caseSensitive: false);
      const text = 'Welcome to Novident example app 😁';

      final Iterable<Match> result = algorithm.searchMethod(pattern, text);
      final starts = result.map((e) => e.start).toList();
      final ends = result.map((e) => e.end).toList();
      expect(starts, [11]);
      expect(ends, [14]);
    });
  });
}
