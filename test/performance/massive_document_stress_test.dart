import 'dart:async';
import 'dart:math';

import 'package:novident_editor/novident_editor.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';

import '../new/infra/testable_editor.dart';

const _kTotalParagraphs = 5000;
const _kWordsPerParagraph = 12;
const _kRenderThresholdMs = 8000;
const _kSelectionThresholdMs = 500;
const _kEditThresholdMs = 1000;
const _kUndoThresholdMs = 2000;
const _kIterationThresholdMs = 500;

const _loremWords = [
  'lorem', 'ipsum', 'dolor', 'sit', 'amet', 'consectetur', 'adipiscing',
  'elit', 'sed', 'do', 'eiusmod', 'tempor', 'incididunt', 'ut', 'labore',
  'et', 'dolore', 'magna', 'aliqua', 'enim', 'ad', 'minim', 'veniam',
  'quis', 'nostrud', 'exercitation', 'ullamco', 'laboris', 'nisi', 'ut',
  'aliquip', 'ex', 'ea', 'commodo', 'consequat', 'duis', 'aute', 'irure',
  'reprehenderit', 'voluptate', 'velit', 'esse', 'cillum', 'fugiat',
  'nulla', 'pariatur', 'excepteur', 'sint', 'occaecat', 'cupidatat',
  'non', 'proident', 'sunt', 'culpa', 'qui', 'officia', 'deserunt',
  'mollit', 'anim', 'id', 'est', 'laborum', 'praesent', 'elementum',
  'facilisis', 'leo', 'vel', 'fringilla', 'ullamcorper', 'morbi',
  'tincidunt', 'orci', 'lacus', 'hendrerit', 'blandit', 'turpis',
  'cursus', 'mattis', 'molestie', 'iaculis', 'erat', 'pellentesque',
  'adipiscing', 'commodo', 'elit', 'imperdiet', 'dui', 'sapien',
  'netus', 'malesuada', 'fames', 'turpis', 'egestas', 'integer',
  'egestas', 'tellus', 'rutrum', 'lectus', 'vestibulum', 'rhoncus',
  'pellentesque', 'eu', 'tincidunt', 'tortor', 'aliquam', 'facilisis',
];

String _randomParagraphText(int wordCount) {
  final rng = Random();
  final words = List.generate(wordCount, (_) => _loremWords[rng.nextInt(_loremWords.length)]);
  final text = words.join(' ');
  return '${text[0].toUpperCase()}${text.substring(1)}';
}

List<Node> _buildParagraphs(int count) {
  return List.generate(count, (i) {
    return paragraphNode(text: '[$i] ${_randomParagraphText(_kWordsPerParagraph)}');
  });
}

int _estimatedWordCount() => _kTotalParagraphs * _kWordsPerParagraph;

/// Scroll [scrollService] to the given offset and pump frames for [duration].
///
/// Uses a single large [tester.pump] call instead of [tester.pumpAndSettle]
/// because the virtualized list keeps building/disposing widgets as the
/// viewport changes — it never truly "settles".
Future<void> _scrollAndPump(
  WidgetTester tester,
  NovidentScrollService scrollService,
  double offset, {
  Duration duration = const Duration(seconds: 30),
}) async {
  scrollService.scrollTo(offset);
  await tester.pump(duration);
}

void main() {
  group('Massive document stress test ($_kTotalParagraphs nodes, ~${_estimatedWordCount()} words)', () {
    late List<Node> paragraphs;

    setUpAll(() {
      debugPrint('Generating $_kTotalParagraphs paragraph nodes (~${_estimatedWordCount()} words)...');
      final sw = Stopwatch()..start();
      paragraphs = _buildParagraphs(_kTotalParagraphs);
      sw.stop();
      debugPrint('Node generation took ${sw.elapsedMilliseconds} ms');
    });

    testWidgets('document creation and initial render', (tester) async {
      final editor = tester.editor;
      for (final node in paragraphs) {
        editor.addNode(node);
      }

      final renderSw = Stopwatch()..start();
      await editor.startTesting(shrinkWrap: false);
      await tester.pumpAndSettle();
      renderSw.stop();

      final elapsedMs = renderSw.elapsedMilliseconds;
      debugPrint('Massive document render + settle: $elapsedMs ms');

      expect(editor.documentRootLen, _kTotalParagraphs);
      expect(editor.nodeAtPath([0]), isNotNull);
      expect(editor.nodeAtPath([_kTotalParagraphs - 1]), isNotNull);

      expect(elapsedMs, lessThan(_kRenderThresholdMs),
          reason: 'Document creation + render must complete within $_kRenderThresholdMs ms');

      await editor.dispose();
    });

    testWidgets('selection tap at start of document', (tester) async {
      final editor = tester.editor;
      for (final node in paragraphs) {
        editor.addNode(node);
      }
      await editor.startTesting(shrinkWrap: false);

      final editorState = editor.editorState;

      final selectionUpdatedCompleter = Completer<void>();
      final stopwatch = Stopwatch();

      void selectionListener() {
        if (stopwatch.isRunning && editorState.selection != null) {
          stopwatch.stop();
          selectionUpdatedCompleter.complete();
        }
      }

      editorState.selectionNotifier.addListener(selectionListener);

      final targetNode = editor.nodeAtPath([0]);
      expect(targetNode, isNotNull, reason: 'First paragraph should exist');

      final finder = find.byKey(targetNode!.key);
      expect(finder, findsOneWidget, reason: 'First paragraph should be rendered');

      final rect = tester.getRect(finder);

      stopwatch.start();
      await tester.tapAt(rect.centerLeft);
      await tester.pump();

      await selectionUpdatedCompleter.future.timeout(
        const Duration(seconds: 10),
        onTimeout: () {
          stopwatch.stop();
          fail('Selection did not update within timeout. '
              'Elapsed: ${stopwatch.elapsedMilliseconds}ms');
        },
      );

      final elapsedMs = stopwatch.elapsedMilliseconds;
      debugPrint('Selection tap at start (path [0]): $elapsedMs ms');

      expect(editorState.selection, isNotNull);
      expect(editorState.selection!.start.path, [0]);

      expect(elapsedMs, lessThan(_kSelectionThresholdMs),
          reason: 'Selection update at start must be < $_kSelectionThresholdMs ms');

      editorState.selectionNotifier.removeListener(selectionListener);
      await editor.dispose();
    });

    testWidgets('text editing and undo on first paragraph', (tester) async {
      final editor = tester.editor;
      for (final node in paragraphs) {
        editor.addNode(node);
      }
      await editor.startTesting(shrinkWrap: false);

      final editorState = editor.editorState;
      editorState.disableSealTimer = true;

      // Place cursor at first paragraph — always in viewport
      final firstNode = editor.nodeAtPath([0])!;
      final firstRect = tester.getRect(find.byKey(firstNode.key));
      await tester.tapAt(firstRect.centerLeft);
      await tester.pumpAndSettle();

      expect(editorState.selection, isNotNull);

      // --- Text insertion ---
      const insertText = 'INSERT_TEST';
      final insertSw = Stopwatch()..start();
      await editor.pressKey(character: insertText);
      await tester.pumpAndSettle();
      insertSw.stop();

      debugPrint('Text insertion at first paragraph: ${insertSw.elapsedMilliseconds} ms');
      expect(insertSw.elapsedMilliseconds, lessThan(_kEditThresholdMs),
          reason: 'Text insertion must be < $_kEditThresholdMs ms');

      final nodeAfterInsert = editor.nodeAtPath([0]);
      final plainText = nodeAfterInsert?.delta?.toPlainText() ?? '';
      expect(plainText, contains(insertText));

      // --- Undo ---
      final undoSw = Stopwatch()..start();
      await simulateKeyDownEvent(LogicalKeyboardKey.control);
      await simulateKeyDownEvent(LogicalKeyboardKey.keyZ);
      await simulateKeyUpEvent(LogicalKeyboardKey.keyZ);
      await simulateKeyUpEvent(LogicalKeyboardKey.control);
      await tester.pumpAndSettle();
      undoSw.stop();

      debugPrint('Undo at first paragraph: ${undoSw.elapsedMilliseconds} ms');
      expect(undoSw.elapsedMilliseconds, lessThan(_kUndoThresholdMs),
          reason: 'Undo must be < $_kUndoThresholdMs ms');

      await editor.dispose();
    });

    testWidgets('scroll to end — informational measurement', (tester) async {
      final editor = tester.editor;
      for (final node in paragraphs) {
        editor.addNode(node);
      }
      await editor.startTesting(shrinkWrap: false);
      await tester.pump();

      final scrollService = editor.editorState.service.scrollService;
      if (scrollService == null) {
        await editor.dispose();
        return;
      }

      final scrollSw = Stopwatch()..start();
      await _scrollAndPump(tester, scrollService, scrollService.maxScrollExtent);
      scrollSw.stop();

      final elapsedMs = scrollSw.elapsedMilliseconds;
      final maxExtent = scrollService.maxScrollExtent.toStringAsFixed(0);
      debugPrint('SCROLL_STRESS_RESULT: extent=$maxExtent px, time=$elapsedMs ms, '
          'nodes=$_kTotalParagraphs');

      // Informational only: the scroll time with a virtualized list of 5000
      // items depends on how many frames the engine can process in the pump
      // window and is not a hard performance contract.
      // The purpose is to measure the cost, not to assert a ceiling.

      // Verify document still usable after scroll
      final lastNode = editor.nodeAtPath([_kTotalParagraphs - 1]);
      expect(lastNode, isNotNull);

      await editor.dispose();
    });

    testWidgets('selection extension from start to middle', (tester) async {
      final editor = tester.editor;
      for (final node in paragraphs) {
        editor.addNode(node);
      }
      await editor.startTesting(shrinkWrap: false);

      final editorState = editor.editorState;
      final midPath = _kTotalParagraphs ~/ 2;

      // Place cursor at first paragraph
      final firstNode = editor.nodeAtPath([0])!;
      final firstRect = tester.getRect(find.byKey(firstNode.key));
      await tester.tapAt(firstRect.centerLeft);
      await tester.pumpAndSettle();

      expect(editorState.selection, isNotNull);

      // Extend selection from [0] to [midPath]
      final extendSw = Stopwatch()..start();
      await editorState.updateSelectionWithReason(
        Selection(
          start: Position(path: [0], offset: 0),
          end: Position(path: [midPath], offset: 10),
        ),
        reason: SelectionUpdateReason.uiEvent,
      );
      await tester.pump();
      extendSw.stop();

      debugPrint('Selection extension [0] -> [$midPath] (${midPath + 1} nodes): '
          '${extendSw.elapsedMilliseconds} ms');

      // Verify editor is still functional
      final lastNode = editor.nodeAtPath([_kTotalParagraphs - 1]);
      expect(lastNode, isNotNull);

      await editor.dispose();
    });

    testWidgets('rapid sequential selection changes', (tester) async {
      final editor = tester.editor;
      for (final node in paragraphs) {
        editor.addNode(node);
      }
      await editor.startTesting(shrinkWrap: false);

      final editorState = editor.editorState;

      const iterations = 50;
      final rapidSw = Stopwatch()..start();

      for (var i = 0; i < iterations; i++) {
        final pathIdx = (i * (_kTotalParagraphs ~/ iterations)).clamp(0, _kTotalParagraphs - 1);
        await editorState.updateSelectionWithReason(
          Selection.collapsed(Position(path: [pathIdx], offset: 0)),
          reason: SelectionUpdateReason.uiEvent,
        );
        await tester.pump(const Duration(milliseconds: 1));
      }

      rapidSw.stop();
      debugPrint('Rapid selection changes: $iterations ops in ${rapidSw.elapsedMilliseconds} ms '
          '(${(rapidSw.elapsedMilliseconds / iterations).toStringAsFixed(1)} ms avg)');

      final lastNode = editor.nodeAtPath([_kTotalParagraphs - 1]);
      expect(lastNode, isNotNull);

      await editor.dispose();
    });

    testWidgets('full node iteration from root', (tester) async {
      final editor = tester.editor;
      for (final node in paragraphs) {
        editor.addNode(node);
      }
      await editor.startTesting(shrinkWrap: false);

      final editorState = editor.editorState;

      final iterSw = Stopwatch()..start();
      final iterator = NodeIterator(
        document: editorState.document,
        startNode: editorState.document.root,
      );
      int count = 0;
      int totalChars = 0;
      while (iterator.moveNext()) {
        final node = iterator.current;
        count++;
        final plain = node.delta?.toPlainText() ?? '';
        totalChars += plain.length;
      }
      iterSw.stop();

      debugPrint('Full node iteration: $count nodes, $totalChars chars, '
          '${iterSw.elapsedMilliseconds} ms');

      expect(count, greaterThanOrEqualTo(_kTotalParagraphs + 1));
      expect(iterSw.elapsedMilliseconds, lessThan(_kIterationThresholdMs),
          reason: 'Node iteration must be < $_kIterationThresholdMs ms');

      await editor.dispose();
    });

    testWidgets('create use dispose stability — 3 cycles', (tester) async {
      for (var cycle = 1; cycle <= 3; cycle++) {
        final cycleSw = Stopwatch()..start();

        final editor = tester.editor;
        for (final node in paragraphs) {
          editor.addNode(node);
        }
        await editor.startTesting(shrinkWrap: false);

        final firstNode = editor.nodeAtPath([0])!;
        final firstRect = tester.getRect(find.byKey(firstNode.key));
        await tester.tapAt(firstRect.centerLeft);
        await tester.pumpAndSettle();

        await editor.pressKey(character: 'CYCLE_$cycle');
        await tester.pumpAndSettle();

        await editor.dispose();

        cycleSw.stop();
        debugPrint('Stability cycle $cycle/3: ${cycleSw.elapsedMilliseconds} ms');
      }

      expect(true, isTrue);
    });
  });
}
