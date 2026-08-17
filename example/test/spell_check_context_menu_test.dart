import 'package:example/spell_check/spell_check_context_menu.dart';
import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:novident_editor/novident_editor.dart';

class _SuggestionChecker implements NovidentSpellChecker {
  final Set<String> dictionary = {'hola', 'world'};
  final Set<String> _learned = {};

  @override
  bool isValid(String word) =>
      _learned.contains(word.toLowerCase()) ||
      dictionary.contains(word.toLowerCase());

  @override
  List<SpellCheckIssue> check(String text) {
    final issues = <SpellCheckIssue>[];
    final regex = RegExp(r"[A-Za-zÀ-ÿ']+");
    for (final match in regex.allMatches(text)) {
      final word = match.group(0)!;
      if (!isValid(word)) {
        issues.add(SpellCheckIssue(
          startOffset: match.start,
          endOffset: match.end,
          word: word,
        ));
      }
    }
    return issues;
  }

  @override
  List<String> suggest(String word) => const ['world'];

  @override
  void addWord(String word) => _learned.add(word.toLowerCase());

  @override
  void forgetWord(String word) => _learned.remove(word.toLowerCase());

  @override
  String? get language => 'en';
}

Offset globalPositionOf(Node node, int offset) {
  final selectable = node.selectable!;
  final rect = selectable.getCursorRectInPosition(
    Position(path: node.path, offset: offset),
    shiftWithBaseOffset: true,
  )!;
  return selectable
      .transformRectToGlobal(rect, shiftWithBaseOffset: true)
      .center;
}

bool isMarked(Node node) => node.delta!.whereType<TextInsert>().any(
    (insert) =>
        insert.attributes?[RichTextKeys.proofState] == proofStateError);

Future<EditorState> pumpEditor(
  WidgetTester tester,
  NovidentSpellChecker checker,
) async {
  final state = EditorState.blank();
  final node = state.document.first!;
  node.updateAttributes({'delta': (Delta()..insert('hola wrld')).toJson()});

  await tester.pumpWidget(
    MaterialApp(
      home: Scaffold(
        body: NovidentEditor(
          editorState: state,
          editorStyle: EditorStyle.desktop(spellChecker: checker),
          contextMenuBuilder: (context, position, editorState, onPressed) =>
              buildSpellCheckContextMenu(
            context: context,
            position: position,
            editorState: editorState,
            onPressed: onPressed,
            checker: checker,
          ),
        ),
      ),
    ),
  );
  // Wait past the configured idle debounce (+ margin) for the analysis.
  final debounce = state.editorStyle.spellCheckDebounce;
  await tester.pump(debounce + const Duration(milliseconds: 100));
  return state;
}

Future<void> rightClickAt(WidgetTester tester, Offset global) async {
  final gesture = await tester.startGesture(
    global,
    kind: PointerDeviceKind.mouse,
    buttons: kSecondaryMouseButton,
  );
  await tester.pump();
  await gesture.up();
  await tester.pump();
}

Future<void> teardownEditor(WidgetTester tester, EditorState state) async {
  await tester.pumpWidget(const SizedBox.shrink());
  state.dispose();
}

void main() {
  testWidgets('finds the misspelled word from the collapsed selection',
      (tester) async {
    final checker = _SuggestionChecker();
    final state = await pumpEditor(tester, checker);
    final node = state.document.first!;

    state.selection = Selection.collapsed(
      Position(path: node.path, offset: 7),
    );
    final misspelled = findMisspelledWord(editorState: state);
    expect(misspelled, isNotNull);
    expect(misspelled!.word, 'wrld');
    expect(misspelled.start, 5);
    expect(misspelled.end, 9);

    // Over an unmarked word → null.
    state.selection = Selection.collapsed(
      Position(path: node.path, offset: 1),
    );
    expect(findMisspelledWord(editorState: state), isNull);

    // A real (non-collapsed) selection → null (standard menu applies).
    state.selection = Selection(
      start: Position(path: node.path, offset: 0),
      end: Position(path: node.path, offset: 4),
    );
    expect(findMisspelledWord(editorState: state), isNull);

    await teardownEditor(tester, state);
  });

  testWidgets('right-click on a misspelled word shows suggestions and '
      'applies the correction', (tester) async {
    final checker = _SuggestionChecker();
    final state = await pumpEditor(tester, checker);
    final node = state.document.first!;
    expect(isMarked(node), true);

    await rightClickAt(tester, globalPositionOf(node, 7));

    expect(find.text('world'), findsOneWidget);
    expect(find.text('Add to dictionary'), findsOneWidget);
    // Collapsed selection: cut/copy must not be offered.
    expect(find.text('Cut'), findsNothing);
    expect(find.text('Copy'), findsNothing);

    await tester.tap(find.text('world'));
    await tester.pump();
    expect(node.delta!.toPlainText(), 'hola world');

    // The applied correction re-analyzes the node; the fixed word loses its
    // mark after the idle debounce.
    await tester.pump(
      state.editorStyle.spellCheckDebounce + const Duration(milliseconds: 100),
    );
    expect(isMarked(node), false);

    await teardownEditor(tester, state);
  });

  testWidgets('right-click on a valid word shows the standard menu only',
      (tester) async {
    final checker = _SuggestionChecker();
    final state = await pumpEditor(tester, checker);
    final node = state.document.first!;

    await rightClickAt(tester, globalPositionOf(node, 1));

    expect(find.text('world'), findsNothing);
    expect(find.text('Add to dictionary'), findsNothing);
    expect(find.text('Paste'), findsOneWidget);
    // Collapsed selection: cut/copy hidden.
    expect(find.text('Cut'), findsNothing);
    expect(find.text('Copy'), findsNothing);

    await teardownEditor(tester, state);
  });

  testWidgets(
      'right-click on a marked word collapses an existing selection in '
      'another node and shows suggestions', (tester) async {
    final checker = _SuggestionChecker();
    final state = await pumpEditor(tester, checker);
    final firstNode = state.document.first!;

    // A second paragraph with a misspelled word ('wrld' at offsets 5..9).
    await state.apply(
      state.transaction
        ..insertNode(
          const [1],
          paragraphNode(delta: (Delta()..insert('otro wrld'))),
        ),
    );
    final debounce = state.editorStyle.spellCheckDebounce;
    await tester.pump(debounce + const Duration(milliseconds: 100));
    final secondNode = state.document.root.children[1];

    // A real (non-collapsed) selection on the FIRST paragraph.
    state.selection = Selection(
      start: Position(path: firstNode.path, offset: 0),
      end: Position(path: firstNode.path, offset: 4),
    );

    // Right-click on the misspelled word of the SECOND paragraph.
    await rightClickAt(tester, globalPositionOf(secondNode, 7));

    // The selection must collapse at the click position in the second
    // node, and the suggestion menu must be shown.
    expect(state.selection, isNotNull);
    expect(state.selection!.isCollapsed, true);
    expect(state.selection!.start.path, const [1]);
    expect(state.selection!.start.offset, 7);
    expect(find.text('world'), findsOneWidget);
    expect(find.text('Add to dictionary'), findsOneWidget);

    await teardownEditor(tester, state);
  });

  testWidgets('cut and copy are offered with a real selection',
      (tester) async {
    final checker = _SuggestionChecker();
    final state = await pumpEditor(tester, checker);
    final node = state.document.first!;

    state.selection = Selection(
      start: Position(path: node.path, offset: 0),
      end: Position(path: node.path, offset: 4),
    );
    await rightClickAt(tester, globalPositionOf(node, 2));

    expect(find.text('Cut'), findsOneWidget);
    expect(find.text('Copy'), findsOneWidget);
    expect(find.text('Paste'), findsOneWidget);

    await teardownEditor(tester, state);
  });

  testWidgets('Add to dictionary clears the mark after re-analysis',
      (tester) async {
    final checker = _SuggestionChecker();
    final state = await pumpEditor(tester, checker);
    final node = state.document.first!;
    expect(isMarked(node), true);

    await rightClickAt(tester, globalPositionOf(node, 7));
    await tester.tap(find.text('Add to dictionary'));
    await tester.pump();

    // requestAnalysis schedules a new pass; wait past the debounce.
    await tester.pump(
      state.editorStyle.spellCheckDebounce + const Duration(milliseconds: 100),
    );
    expect(isMarked(node), false);

    await teardownEditor(tester, state);
  });
}
