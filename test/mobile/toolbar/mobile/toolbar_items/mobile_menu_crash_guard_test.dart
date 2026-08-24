import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:novident_editor/novident_editor.dart';

import '../test_helpers/mobile_toolbar_style_test_widget.dart';

class _StubService implements MobileToolbarWidgetService {
  @override
  void closeItemMenu() {}
}

/// Regression tests: the block/heading/list menus must not crash when the
/// selection points at a path that no longer exists (e.g. a stale selection
/// after a node was removed). The legacy code used `getNodeAtPath(...)!`,
/// which throws a null-check on the missing node.
void main() {
  setUpAll(() async {
    TestWidgetsFlutterBinding.ensureInitialized();
    await NovidentEditorLocalizations.load(const Locale('en'));
  });

  EditorState editorWithOneNode() {
    final doc = Document.blank();
    final delta = Delta()..insert('Hello');
    doc.insert(
      [
        0,
      ],
      [
        Node(
          type: 'paragraph',
          attributes: {
            blockComponentDelta: delta.toJson(),
          },
        ),
      ],
    );
    return EditorState(document: doc);
  }

  Future<void> pumpMenu(
    WidgetTester tester,
    EditorState editorState,
    MobileToolbarItem item,
  ) async {
    await tester.pumpWidget(
      Material(
        child: MobileToolbarStyleTestWidget(
          child: Builder(
            builder: (context) {
              final menu = item.itemMenuBuilder!(
                context,
                editorState,
                _StubService(),
              );
              return menu ?? const SizedBox.shrink();
            },
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();
  }

  final items = <String, MobileToolbarItem>{
    'heading': headingMobileToolbarItem,
    'blocks': blocksMobileToolbarItem,
    'list': listMobileToolbarItem,
  };

  for (final entry in items.entries) {
    testWidgets('${entry.key} menu does not crash on invalid selection path',
        (tester) async {
      final editorState = editorWithOneNode();
      addTearDown(() => editorState.dispose());

      // Point the selection at a path that does not exist.
      unawaited(
        editorState.updateSelectionWithReason(
          Selection.single(path: [99], startOffset: 0),
        ),
      );

      await pumpMenu(tester, editorState, entry.value);

      // No menu buttons should be rendered (the menu degrades gracefully).
      expect(find.byType(MobileToolbarItemMenuBtn), findsNothing);
    });
  }
}
