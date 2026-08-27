import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:novident_editor/novident_editor.dart';
import 'package:novident_editor/src/editor/block_component/table_block_component/table_block_component.dart';

import '../../test_helper.dart';

/// Replicates the readme document structure (paragraphs + 5 tables) using
/// only root-package APIs. The example-only style definitions
/// (`readme-striped`, `readme-plain`, `readme-accent`) are omitted — tables
/// fall back to [kDefaultTableStyle].
Document _readmeLikeDocument() {
  return Document(
    root: pageNode(
      children: <Node>[
        paragraphNode(text: 'Welcome'),
        paragraphNode(
          text: 'This workspace showcases what the Novident editor can do. '
              'Open each document to see a different set of capabilities.',
        ),
        paragraphNode(text: '1. Basic table'),
        TableNode.fromList([
          ['Name', 'Elara', 'Doran'],
          ['Role', 'Mage', 'Warrior'],
          ['Level', '8', '6'],
        ]).node,
        paragraphNode(text: '2. Mixed content'),
        TableNode.fromNodes([
          [
            headingNode(level: 3, text: 'Item'),
            paragraphNode(text: 'Potion'),
            paragraphNode(text: 'Scroll'),
          ],
          [
            paragraphNode(text: 'Price'),
            paragraphNode(text: '15 gp'),
            paragraphNode(text: '50 gp'),
          ],
          [
            paragraphNode(text: 'Stock'),
            paragraphNode(text: '12'),
            paragraphNode(text: '5'),
          ],
        ]).node,
        paragraphNode(text: '3. Borderless'),
        TableNode.fromNodes([
          [paragraphNode(text: 'Feature'), paragraphNode(text: 'Status')],
          [paragraphNode(text: 'noBorder'), paragraphNode(text: 'ok')],
          [paragraphNode(text: 'cellPadding'), paragraphNode(text: 'ok')],
        ]).node,
        paragraphNode(text: '4. Striped with header'),
        TableNode.fromNodes([
          [
            paragraphNode(text: 'Name'),
            paragraphNode(text: 'Role'),
            paragraphNode(text: 'Level'),
          ],
          [
            paragraphNode(text: 'Elara'),
            paragraphNode(text: 'Mage'),
            paragraphNode(text: '8'),
          ],
          [
            paragraphNode(text: 'Doran'),
            paragraphNode(text: 'Warrior'),
            paragraphNode(text: '6'),
          ],
          [
            paragraphNode(text: 'Lyra'),
            paragraphNode(text: 'Rogue'),
            paragraphNode(text: '4'),
          ],
        ]).node,
        paragraphNode(text: '5. Accent'),
        TableNode.fromNodes([
          [
            paragraphNode(text: 'Task'),
            paragraphNode(text: 'Owner'),
            paragraphNode(text: 'Due'),
          ],
          [
            paragraphNode(text: 'Design system'),
            paragraphNode(text: 'Elara'),
            paragraphNode(text: 'Aug 12'),
          ],
          [
            paragraphNode(text: 'Table styles'),
            paragraphNode(text: 'Doran'),
            paragraphNode(text: 'Aug 20'),
          ],
          [
            paragraphNode(text: 'Documentation'),
            paragraphNode(text: 'Lyra'),
            paragraphNode(text: 'Sep 1'),
          ],
        ]).node,
      ],
    ),
  );
}

/// Replicates the `_FileSheet._buildPage` layout of the example's
/// `MultiEditorView`: a white "sheet" constrained to [maxWidth], whose
/// editor runs in dynamic-height mode and receives an explicit
/// [DynamicHeightConfig.availableWidth] derived from a [LayoutBuilder].
///
/// This is exactly the shape that used to crash: `IntrinsicHeight` (from
/// dynamic-height) wrapping a table, while the table still used its own
/// `LayoutBuilder` because the internal controller had been disposed.
Widget _buildSheet(EditorState editorState) {
  return Center(
    child: ConstrainedBox(
      constraints: const BoxConstraints(maxWidth: 750),
      child: Container(
        margin: const EdgeInsets.fromLTRB(16, 0, 16, 12),
        clipBehavior: Clip.antiAlias,
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(3),
        ),
        child: Padding(
          padding: const EdgeInsets.only(top: 8),
          child: LayoutBuilder(
            builder: (context, constraints) {
              return NovidentEditor(
                editorState: editorState,
                editable: true,
                editorStyle: const EditorStyle.desktop(
                  padding: EdgeInsets.symmetric(horizontal: 32),
                ),
                dynamicHeightConfig: DynamicHeightConfig(
                  availableWidth: (constraints.maxWidth - 32) -
                      const EdgeInsets.fromLTRB(16, 15, 16, 0).horizontal,
                  minHeight: 80,
                ),
              );
            },
          ),
        ),
      ),
    ),
  );
}

Future<List<dynamic>> _settle(WidgetTester tester) async {
  final collected = <dynamic>[];
  for (var i = 0; i < 15; i++) {
    await tester.pump();
    while (true) {
      final e = tester.takeException();
      if (e == null) break;
      collected.add(e);
    }
  }
  return collected;
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('Multi-editor view (dynamic height + tables)', () {
    testWidgets('renders the readme-like document without overflow or crash',
        (tester) async {
      final editorState = EditorState(document: _readmeLikeDocument());

      await tester.buildAndPump(_buildSheet(editorState));
      final exceptions = await _settle(tester);

      // 5 tables in the document.
      expect(find.byType(TableBlockComponentWidget), findsNWidgets(5));

      // No intrinsic-layout crash nor RenderFlex overflow may be thrown.
      expect(
        exceptions.where(
          (e) =>
              e.toString().contains('LayoutBuilder') ||
              e.toString().contains('overflowed'),
        ),
        isEmpty,
        reason: 'The multi-editor scenario threw: $exceptions',
      );

      editorState.dispose();
    });
  });
}
