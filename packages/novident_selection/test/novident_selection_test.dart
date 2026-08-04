import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:novident_core/novident_core.dart';
import 'package:novident_editor_document/novident_editor_document.dart';
import 'package:novident_selection/novident_selection.dart';

class _TestSelectable extends StatefulWidget {
  // ignore: unused_element_parameter
  const _TestSelectable({super.key});
  @override State<_TestSelectable> createState() => _TestSelectableState();
}

class _TestSelectableState extends State<_TestSelectable>
    with SelectableMixin<_TestSelectable> {
  @override Rect getBlockRect({bool shiftWithBaseOffset = false}) =>
      const Rect.fromLTWH(0, 0, 100, 20);
  @override Selection getSelectionInRange(Offset start, Offset end) =>
      Selection.invalid();
  @override List<Rect> getRectsInSelection(Selection selection,
          {bool shiftWithBaseOffset = false}) =>
      [const Rect.fromLTWH(0, 0, 50, 20)];
  @override Position getPositionInOffset(Offset start) => Position.invalid();
  @override Rect? getCursorRectInPosition(Position position,
          {bool shiftWithBaseOffset = false}) =>
      const Rect.fromLTWH(0, 0, 2, 20);
  @override Offset localToGlobal(Offset offset,
          {bool shiftWithBaseOffset = false}) =>
      offset;
  @override Position start() => Position(path: [0], offset: 0);
  @override Position end() => Position(path: [0], offset: 10);
  @override TextDirection textDirection() => TextDirection.ltr;
  @override Widget build(BuildContext context) => const SizedBox.shrink();
}

class _TestHost implements BlockSelectionHost {
  @override bool isBlockSelectionMode() => false;
  @override CursorAppearance? customizeCursor(
          {required Node node,
          required Selection? selection,
          required Position position}) =>
      null;
  @override EdgeInsets? blockSelectionMargin(Node node) => null;
  @override String? selectionDragModeValue() => null;
}

Node _makeNode() => Node(type: 'paragraph');

void main() {
  group('BlockSelectionType', () {
    test('has 3 values', () {
      expect(BlockSelectionType.values.length, 3);
      expect(BlockSelectionType.cursor, isA<BlockSelectionType>());
      expect(BlockSelectionType.selection, isA<BlockSelectionType>());
      expect(BlockSelectionType.block, isA<BlockSelectionType>());
    });
  });

  group('RemoteSelection', () {
    test('constructor', () {
      final sel = Selection.collapsed(Position(path: [0], offset: 5));
      final remote = RemoteSelection(
        id: 'u1',
        selection: sel,
        selectionColor: Colors.blue,
        cursorColor: Colors.red,
      );
      expect(remote.id, 'u1');
      expect(remote.selection, sel);
      expect(remote.cursorColor, Colors.red);
    });
  });

  group('CursorAppearance', () {
    test('defaults', () {
      const a = CursorAppearance();
      expect(a.style, isNull);
      expect(a.shouldBlink, isNull);
      expect(a.paintOnExpandedSelection, false);
    });

    test('custom', () {
      const a = CursorAppearance(
        style: CursorStyle.cover,
        shouldBlink: false,
        paintOnExpandedSelection: true,
      );
      expect(a.style, CursorStyle.cover);
      expect(a.shouldBlink, false);
    });
  });

  group('BlockSelectionHost', () {
    test('standalone impl', () {
      final host = _TestHost();
      expect(host.isBlockSelectionMode(), false);
      expect(host.blockSelectionMargin(_makeNode()), isNull);
      expect(host.selectionDragModeValue(), isNull);
    });
  });

  group('Cursor widget', () {
    testWidgets('renders without error', (tester) async {
      await tester.pumpWidget(
        const MaterialApp(
          home: Stack(
            children: [
              Cursor(
                rect: Rect.fromLTWH(10, 10, 2, 16),
                color: Colors.black,
                shouldBlink: false,
              ),
            ],
          ),
        ),
      );
      expect(tester.takeException(), isNull);
    });
  });

  group('BlockSelectionContainer', () {
    testWidgets('renders child text', (tester) async {
      final node = _makeNode();
      final notifier = ValueNotifier<Selection?>(null);
      final host = _TestHost();

      await tester.pumpWidget(
        MaterialApp(
          home: BlockSelectionContainer(
            node: node,
            delegate: _TestSelectableState(),
            listenable: notifier,
            host: host,
            child: const Text('hello'),
          ),
        ),
      );

      expect(find.text('hello'), findsOneWidget);
      notifier.dispose();
    });
  });
}
