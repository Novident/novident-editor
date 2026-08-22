import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:novident_editor/novident_editor.dart';

import '../util/node_util.dart';

void main() {
  Document documentWith(int count) {
    final document = Document.blank();
    document.root.addParagraphs(count);
    return document;
  }

  Widget buildBlock({
    required Node node,
    required ValueNotifier<ZenModeConfiguration> config,
    required ValueNotifier<Selection?> selection,
    Widget child = const SizedBox(width: 100, height: 50),
  }) {
    return MaterialApp(
      home: ZenModeBlock(
        configuration: config,
        selection: selection,
        node: node,
        child: child,
      ),
    );
  }

  group('ZenModeBlock dimming', () {
    testWidgets('dims a block outside the selection', (tester) async {
      final document = documentWith(3);
      final node = document.root.children[1]; // path [1]
      final config = ValueNotifier(const ZenModeConfiguration());
      final selection =
          ValueNotifier<Selection?>(Selection.collapsed(Position(path: [0])));

      await tester.pumpWidget(
        buildBlock(
          node: node,
          config: config,
          selection: selection,
        ),
      );

      final scope = tester.widget<ZenModeScope>(find.byType(ZenModeScope));
      expect(scope.dimmed, isTrue);
    });

    testWidgets('does not dim a block inside the selection', (tester) async {
      final document = documentWith(3);
      final node = document.root.children[0]; // path [0]
      final config = ValueNotifier(const ZenModeConfiguration());
      final selection =
          ValueNotifier<Selection?>(Selection.collapsed(Position(path: [0])));

      await tester.pumpWidget(
        buildBlock(
          node: node,
          config: config,
          selection: selection,
        ),
      );

      final scope = tester.widget<ZenModeScope>(find.byType(ZenModeScope));
      expect(scope.dimmed, isFalse);
    });

    testWidgets('collapsed selection inside the block keeps it undimmed',
        (tester) async {
      final document = documentWith(3);
      final node = document.root.children[1]; // path [1]
      final config = ValueNotifier(const ZenModeConfiguration());
      // cursor inside block [1] (e.g. its first text child).
      final selection = ValueNotifier<Selection?>(
        Selection.collapsed(Position(path: [1, 0, 0])),
      );

      await tester.pumpWidget(
        buildBlock(
          node: node,
          config: config,
          selection: selection,
        ),
      );

      final scope = tester.widget<ZenModeScope>(find.byType(ZenModeScope));
      expect(scope.dimmed, isFalse);
    });

    testWidgets('multi-block selection keeps intermediate blocks undimmed',
        (tester) async {
      final document = documentWith(3);
      final node = document.root.children[1]; // path [1]
      final config = ValueNotifier(const ZenModeConfiguration());
      final selection = ValueNotifier<Selection?>(
        Selection(
          start: Position(path: [0]),
          end: Position(path: [2]),
        ),
      );

      await tester.pumpWidget(
        buildBlock(
          node: node,
          config: config,
          selection: selection,
        ),
      );

      final scope = tester.widget<ZenModeScope>(find.byType(ZenModeScope));
      expect(scope.dimmed, isFalse);
    });

    testWidgets('zen disabled never dims', (tester) async {
      final document = documentWith(3);
      final node = document.root.children[1];
      final config = ValueNotifier(
        const ZenModeConfiguration(enabled: false),
      );
      final selection =
          ValueNotifier<Selection?>(Selection.collapsed(Position(path: [0])));

      await tester.pumpWidget(
        buildBlock(
          node: node,
          config: config,
          selection: selection,
        ),
      );

      final scope = tester.widget<ZenModeScope>(find.byType(ZenModeScope));
      expect(scope.dimmed, isFalse);
    });
  });

  group('ZenModeBlock rebuild behavior', () {
    testWidgets('does not rebuild when the focus changes but dimmed stays',
        (tester) async {
      final document = documentWith(3);
      final node = document.root.children[1]; // path [1]
      final config = ValueNotifier(const ZenModeConfiguration());
      final selection =
          ValueNotifier<Selection?>(Selection.collapsed(Position(path: [0])));

      await tester.pumpWidget(
        buildBlock(
          node: node,
          config: config,
          selection: selection,
        ),
      );
      final scopeBefore =
          tester.widget<ZenModeScope>(find.byType(ZenModeScope));
      expect(scopeBefore.dimmed, isTrue);

      // focus moves to block [2]: node [1] stays dimmed → no setState.
      selection.value = Selection.collapsed(Position(path: [2]));
      await tester.pump();

      final scopeAfter =
          tester.widget<ZenModeScope>(find.byType(ZenModeScope));
      expect(scopeAfter.dimmed, isTrue);
      expect(identical(scopeBefore, scopeAfter), isTrue);
    });

    testWidgets('rebuilds when its own dimmed state flips', (tester) async {
      final document = documentWith(3);
      final node = document.root.children[1]; // path [1]
      final config = ValueNotifier(const ZenModeConfiguration());
      final selection =
          ValueNotifier<Selection?>(Selection.collapsed(Position(path: [0])));

      await tester.pumpWidget(
        buildBlock(
          node: node,
          config: config,
          selection: selection,
        ),
      );
      final scopeBefore =
          tester.widget<ZenModeScope>(find.byType(ZenModeScope));
      expect(scopeBefore.dimmed, isTrue);

      // focus moves to block [1]: node [1] becomes focused → setState.
      selection.value = Selection.collapsed(Position(path: [1]));
      await tester.pump();

      final scopeAfter =
          tester.widget<ZenModeScope>(find.byType(ZenModeScope));
      expect(scopeAfter.dimmed, isFalse);
      expect(identical(scopeBefore, scopeAfter), isFalse);
    });
  });

  group('ZenModeBlock text re-resolution', () {
    testWidgets('text re-resolves when the dimmed state flips',
        (tester) async {
      final document = documentWith(3);
      final node = document.root.children[1]; // path [1]
      final config = ValueNotifier(const ZenModeConfiguration());
      final selection =
          ValueNotifier<Selection?>(Selection.collapsed(Position(path: [0])));

      await tester.pumpWidget(
        MaterialApp(
          home: ZenModeBlock(
            configuration: config,
            selection: selection,
            node: node,
            child: Builder(
              builder: (context) {
                final scope = ZenModeScope.maybeOf(context);
                return Text(scope?.dimmed == true ? 'dimmed' : 'focused');
              },
            ),
          ),
        ),
      );

      expect(find.text('dimmed'), findsOneWidget);

      // move the cursor to block [1] with a collapsed selection — the text
      // must re-resolve even though the block component does not rebuild on
      // its own (regression: stale dimming after a collapsed selection move).
      selection.value = Selection.collapsed(Position(path: [1]));
      await tester.pump();

      expect(find.text('focused'), findsOneWidget);
      expect(find.text('dimmed'), findsNothing);
    });
  });

  group('ZenModeBlock non-text wrapping', () {
    testWidgets('wraps a dimmed image block in Opacity', (tester) async {
      final document = Document.blank();
      document.root.addParagraphs(2);
      document.root.insert(Node(type: ImageBlockKeys.type));
      final node = document.root.children[2]; // path [2], image
      final config = ValueNotifier(const ZenModeConfiguration());
      final selection =
          ValueNotifier<Selection?>(Selection.collapsed(Position(path: [0])));

      await tester.pumpWidget(
        buildBlock(
          node: node,
          config: config,
          selection: selection,
        ),
      );

      final blockFinder = find.byType(ZenModeBlock);
      expect(
        find.descendant(of: blockFinder, matching: find.byType(Opacity)),
        findsOneWidget,
      );
    });

    testWidgets('does not wrap a dimmed paragraph in Opacity', (tester) async {
      final document = documentWith(3);
      final node = document.root.children[1]; // paragraph
      final config = ValueNotifier(const ZenModeConfiguration());
      final selection =
          ValueNotifier<Selection?>(Selection.collapsed(Position(path: [0])));

      await tester.pumpWidget(
        buildBlock(
          node: node,
          config: config,
          selection: selection,
        ),
      );

      final blockFinder = find.byType(ZenModeBlock);
      expect(
        find.descendant(of: blockFinder, matching: find.byType(Opacity)),
        findsNothing,
      );
    });
  });
}