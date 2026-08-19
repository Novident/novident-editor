import 'package:novident_editor/novident_editor.dart';
import 'package:novident_editor/src/editor/editor_component/service/ime/delta_input_impl.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../../new/util/util.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  tearDown(() => EditorPlatform.reset());

  group('onNonTextUpdate', () {
    // Pro-performa test
    test('call', () async {
      await onNonTextUpdate(
        const TextEditingDeltaNonTextUpdate(
          oldText: 'Novident',
          selection: TextSelection(baseOffset: 0, extentOffset: 3),
          composing: TextRange(start: 0, end: 3),
        ),
        EditorState.blank(),
      );
    });

    group('multi-node selection', () {
      EditorState buildEditor() {
        final document = Document.blank()
          ..addParagraphs(2, initialText: 'Hello');
        return EditorState(document: document);
      }

      // The IME owns a *flat* buffer (the concatenation of the selected nodes,
      // "Hello\nHello"). When the user drags the magnifier/selection handle to
      // extend the END of an existing multi-node range, the IME reports a
      // TextEditingDeltaNonTextUpdate whose `selection` is *collapsed* (it only
      // describes the moving end), even though the editor still holds a range
      // spanning two nodes.
      //
      // onNonTextUpdate must NOT collapse the editor's selection in that case:
      // it must preserve the anchor and only move the moving end.
      for (final platform in const [
        EditorPlatformOverride(isLinux: true),
        EditorPlatformOverride(isMacOS: true),
      ]) {
        test(
          'does not collapse a multi-node selection '
          '(platform: $platform)',
          () async {
            EditorPlatform.override = platform;

            final editorState = buildEditor();
            editorState.selection = Selection(
              start: Position(path: [0]),
              end: Position(path: [1], offset: 5),
            );

            // Flat offset 11 == end of the "Hello\nHello" buffer.
            await onNonTextUpdate(
              const TextEditingDeltaNonTextUpdate(
                oldText: 'Hello\nHello',
                selection: TextSelection.collapsed(offset: 11),
                composing: TextRange.empty,
              ),
              editorState,
            );

            final selection = editorState.selection;
            expect(selection, isNotNull);

            // Regression: the range must survive.
            expect(
              selection!.isCollapsed,
              isFalse,
              reason: 'extending a selection must not collapse it',
            );

            // The anchor (start) must be preserved.
            expect(
              selection.start.path,
              [0],
              reason: 'the anchor node must not move',
            );
            expect(
              selection.start.offset,
              0,
              reason: 'the anchor offset must not move',
            );
          },
        );
      }

      test(
        'keeps the moved end within its own node (flat offset remapped)',
        () async {
          EditorPlatform.override = const EditorPlatformOverride(isLinux: true);

          final editorState = buildEditor();
          editorState.selection = Selection(
            start: Position(path: [0]),
            end: Position(path: [1], offset: 5),
          );

          await onNonTextUpdate(
            const TextEditingDeltaNonTextUpdate(
              oldText: 'Hello\nHello',
              selection: TextSelection.collapsed(offset: 11),
              composing: TextRange.empty,
            ),
            editorState,
          );

          final selection = editorState.selection;
          expect(selection, isNotNull);

          // The flat offset 11 belongs to the second node ([1]) at offset 5 —
          // NOT to node [0] at offset 11 (which would be out of range).
          final endNode = editorState.getNodeAtPath(selection!.end.path);
          expect(endNode, isNotNull);
          expect(
            selection.end.offset,
            lessThanOrEqualTo(endNode!.delta!.length),
            reason: 'the end offset must stay within the node it points to',
          );
        },
      );

      test('moves the start when the flat offset is near the anchor', () async {
        EditorPlatform.override = const EditorPlatformOverride(isLinux: true);

        final editorState = buildEditor();
        editorState.selection = Selection(
          start: Position(path: [0], offset: 2),
          end: Position(path: [1], offset: 5),
        );

        // Flat offset 0 == start of the buffer: the user drags the START
        // handle backwards, so the start must move and the end must stay.
        await onNonTextUpdate(
          const TextEditingDeltaNonTextUpdate(
            oldText: 'Hello\nHello',
            selection: TextSelection.collapsed(offset: 0),
            composing: TextRange.empty,
          ),
          editorState,
        );

        final selection = editorState.selection;
        expect(selection, isNotNull);
        expect(selection!.isCollapsed, isFalse);
        expect(selection.start.path, [0]);
        expect(selection.start.offset, 0);
        expect(selection.end.path, [1]);
        expect(selection.end.offset, 5);
      });

      test('preserves the anchor on a backward selection', () async {
        EditorPlatform.override = const EditorPlatformOverride(isLinux: true);

        final editorState = buildEditor();
        // Backward: the user dragged from [1] towards [0], so `start` is the
        // moving head (end of the buffer) and `end` is the anchor.
        editorState.selection = Selection(
          start: Position(path: [1], offset: 5),
          end: Position(path: [0]),
        );

        // Flat offset 3 (inside the first node of the buffer): the head
        // (start, at flat 5) is the closest end, so it moves to [1]:3 while
        // the anchor [0]:0 is preserved.
        await onNonTextUpdate(
          const TextEditingDeltaNonTextUpdate(
            oldText: 'Hello\nHello',
            selection: TextSelection.collapsed(offset: 3),
            composing: TextRange.empty,
          ),
          editorState,
        );

        final selection = editorState.selection;
        expect(selection, isNotNull);
        expect(selection!.isCollapsed, isFalse);
        expect(selection.start.path, [1]);
        expect(selection.start.offset, 3);
        expect(selection.end.path, [0]);
        expect(selection.end.offset, 0);
      });
    });

    group('collapsed selection', () {
      EditorState buildEditor() {
        final document = Document.blank()
          ..addParagraphs(2, initialText: 'Hello');
        return EditorState(document: document);
      }

      test('collapses a collapsed selection (real caret move)', () async {
        EditorPlatform.override = const EditorPlatformOverride(isLinux: true);

        final editorState = buildEditor();
        editorState.selection = Selection.collapsed(
          Position(path: [0], offset: 2),
        );

        await onNonTextUpdate(
          const TextEditingDeltaNonTextUpdate(
            oldText: 'Hello',
            selection: TextSelection.collapsed(offset: 4),
            composing: TextRange.empty,
          ),
          editorState,
        );

        final selection = editorState.selection;
        expect(selection, isNotNull);
        expect(selection!.isCollapsed, isTrue);
        expect(selection.start.path, [0]);
        expect(selection.start.offset, 4);
      });
    });

    group('platform branches', () {
      EditorState buildEditor() {
        final document = Document.blank()
          ..addParagraphs(2, initialText: 'Hello');
        return EditorState(document: document);
      }

      test('windows: preserves an active range', () async {
        EditorPlatform.override = const EditorPlatformOverride(isWindows: true);

        final editorState = buildEditor();
        editorState.selection = Selection(
          start: Position(path: [0]),
          end: Position(path: [1], offset: 5),
        );

        await onNonTextUpdate(
          const TextEditingDeltaNonTextUpdate(
            oldText: 'Hello\nHello',
            selection: TextSelection.collapsed(offset: 11),
            composing: TextRange.empty,
          ),
          editorState,
        );

        final selection = editorState.selection;
        expect(selection, isNotNull);
        expect(selection!.isCollapsed, isFalse);
        expect(selection.start.path, [0]);
        expect(selection.end.path, [1]);
      });

      test('windows: collapses a collapsed selection with remapped offset',
          () async {
        EditorPlatform.override = const EditorPlatformOverride(isWindows: true);

        final editorState = buildEditor();
        editorState.selection = Selection.collapsed(
          Position(path: [0], offset: 2),
        );

        await onNonTextUpdate(
          const TextEditingDeltaNonTextUpdate(
            oldText: 'Hello',
            selection: TextSelection.collapsed(offset: 4),
            composing: TextRange.empty,
          ),
          editorState,
        );

        final selection = editorState.selection;
        expect(selection, isNotNull);
        expect(selection!.isCollapsed, isTrue);
        expect(selection.start.offset, 4);
      });

      testWidgets('android: moves the caret with a remapped offset',
          (tester) async {
        EditorPlatform.override = const EditorPlatformOverride(isAndroid: true);

        final editorState = buildEditor();
        editorState.selection = Selection.collapsed(
          Position(path: [0], offset: 2),
        );

        await onNonTextUpdate(
          const TextEditingDeltaNonTextUpdate(
            oldText: 'Hello',
            selection: TextSelection.collapsed(offset: 4),
            composing: TextRange.empty,
          ),
          editorState,
        );
        // Android routes through `SelectionUpdateReason.uiEvent`, which only
        // completes after the next frame.
        await tester.pump();

        final selection = editorState.selection;
        expect(selection, isNotNull);
        expect(selection!.isCollapsed, isTrue);
        expect(selection.start.offset, 4);
      });
    });
  });
}
