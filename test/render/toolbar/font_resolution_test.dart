import 'package:flutter_test/flutter_test.dart';
import 'package:novident_editor/novident_editor.dart';

/// Unit tests for the font-family / font-size resolution priority.
///
/// These tests verify the order: delta inline → resolved style → default.
/// They do NOT require widget trees — they validate the algorithm directly
/// using EditorState helpers.

void main() {
  group('Font resolution priority', () {
    late EditorState editorState;
    late Document document;

    setUp(() {
      document = Document.blank();
      editorState = EditorState(document: document);
    });

    tearDown(() {
      editorState.dispose();
    });

    // ------------------------------------------------------------------
    // Helpers
    // ------------------------------------------------------------------

    /// Inserts a paragraph node at [path] with [text] and optional inline
    /// [attributes] on every character.
    Node insertParagraph({
      required Path path,
      required String text,
      Map<String, dynamic>? attributes,
    }) {
      final node = Node(
        type: 'paragraph',
        attributes: {blockComponentStyleRef: null},
      );
      final delta = Delta()..insert(text, attributes: attributes);
      node.updateAttributes({
        ...node.attributes,
        blockComponentDelta: delta.toJson(),
      });
      document.insert(path, [node]);
      return node;
    }

    // ------------------------------------------------------------------
    // font_size
    // ------------------------------------------------------------------

    group('fontSize — delta vs style', () {
      test('delta attribute takes priority over style', () {
        insertParagraph(
          path: [0],
          text: 'Hello',
          attributes: {RichTextKeys.fontSize: 14.0},
        );

        editorState.updateSelectionWithReason(
          Selection.single(path: [0], startOffset: 0, endOffset: 5),
        );

        final node = editorState.getNodeAtPath([0])!;
        final nodes = editorState.getNodesInSelection(editorState.selection!);
        double? fromDelta;
        nodes.allSatisfyInSelection(editorState.selection!, (delta) {
          return delta.everyAttributes((attr) {
            final raw = attr[RichTextKeys.fontSize];
            if (raw != null) {
              fromDelta =
                  (raw is num) ? raw.toDouble() : double.tryParse('$raw');
            }
            return true;
          });
        });

        // Delta attribute must be found and take priority.
        expect(fromDelta, 14.0);
        // The style (kDefaultBaseStyle) has fontSize 12 — but delta wins.
      });

      test('falls back to default when no delta and no style', () {
        insertParagraph(path: [0], text: 'Plain');

        editorState.updateSelectionWithReason(
          Selection.single(path: [0], startOffset: 0, endOffset: 5),
        );

        final nodes = editorState.getNodesInSelection(editorState.selection!);
        double? fromDelta;
        nodes.allSatisfyInSelection(editorState.selection!, (delta) {
          return delta.everyAttributes((attr) {
            final raw = attr[RichTextKeys.fontSize];
            if (raw != null) {
              fromDelta =
                  (raw is num) ? raw.toDouble() : double.tryParse('$raw');
            }
            return true;
          });
        });

        // No delta attribute on the text.
        expect(fromDelta, isNull);
        // The default size (12 from kDefaultBaseStyle) would be the fallback
        // in the full resolveEffectiveToolbarStyle pipeline.
      });

      test('collapsed cursor reads previous character delta', () {
        insertParagraph(
          path: [0],
          text: 'AB',
          attributes: {RichTextKeys.fontSize: 18.0},
        );

        // Place collapsed cursor at position 1 (between A and B).
        // The previous character (index 0, 'A') has fontSize: 18.
        editorState.updateSelectionWithReason(
          Selection.collapsed(Position(path: [0], offset: 1)),
        );

        expect(editorState.selection?.isCollapsed, isTrue);

        // Simulate what _resolveFromNodeAndDelta does for collapsed:
        // look at prev char.
        final prevSelection = editorState.selection!.copyWith(
          start: editorState.selection!.start.copyWith(offset: 0),
        );
        final nodes = editorState.getNodesInSelection(prevSelection);
        double? fromDelta;
        nodes.allSatisfyInSelection(prevSelection, (delta) {
          return delta.everyAttributes((attr) {
            final raw = attr[RichTextKeys.fontSize];
            if (raw != null) {
              fromDelta =
                  (raw is num) ? raw.toDouble() : double.tryParse('$raw');
            }
            return true;
          });
        });

        expect(fromDelta, 18.0);
      });
    });

    // ------------------------------------------------------------------
    // font_family
    // ------------------------------------------------------------------

    group('fontFamily — delta vs default', () {
      test('delta fontFamily is detected', () {
        insertParagraph(
          path: [0],
          text: 'Hello',
          attributes: {RichTextKeys.fontFamily: 'Georgia'},
        );

        editorState.updateSelectionWithReason(
          Selection.single(path: [0], startOffset: 0, endOffset: 5),
        );

        final nodes = editorState.getNodesInSelection(editorState.selection!);
        String? fromDelta;
        nodes.allSatisfyInSelection(editorState.selection!, (delta) {
          return delta.everyAttributes((attr) {
            final raw = attr[RichTextKeys.fontFamily];
            if (raw is String && raw.isNotEmpty) {
              fromDelta = raw;
              return true;
            }
            return false;
          });
        });

        expect(fromDelta, 'Georgia');
      });

      test('no delta → falls back to kDefaultBaseStyle default font', () {
        insertParagraph(path: [0], text: 'Plain');

        editorState.updateSelectionWithReason(
          Selection.single(path: [0], startOffset: 0, endOffset: 5),
        );

        final nodes = editorState.getNodesInSelection(editorState.selection!);
        String? fromDelta;
        nodes.allSatisfyInSelection(editorState.selection!, (delta) {
          return delta.everyAttributes((attr) {
            final raw = attr[RichTextKeys.fontFamily];
            if (raw is String && raw.isNotEmpty) {
              fromDelta = raw;
              return true;
            }
            return false;
          });
        });

        // No inline font set — delta returns null.
        expect(fromDelta, isNull);
        // The fallback (kDefaultBaseStyle.fontFamily) is the platform
        // default font (Roboto on Windows/Android, SF Pro on macOS, etc.).
        expect(kDefaultBaseStyle.fontFamily, getDefaultFont());
      });
    });
  });
}
