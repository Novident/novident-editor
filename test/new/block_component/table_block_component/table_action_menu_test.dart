import 'package:novident_editor/novident_editor.dart';
import 'package:novident_editor/src/editor/block_component/table_block_component/table_action_handler.dart';
import 'package:novident_editor/src/editor/block_component/table_block_component/table_col_border.dart';
import 'package:novident_editor/src/editor/block_component/table_block_component/table_view.dart';
import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_test/flutter_test.dart';

void main() async {
  setUpAll(() {
    TestWidgetsFlutterBinding.ensureInitialized();
  });

  Future<EditorState> pumpTableEditor(
    WidgetTester tester, {
    TableStyle tableStyle = const TableStyle(),
    List<TableActionMenuItem>? actionMenuItems,
    Attributes? tableAttributes,
  }) async {
    await NovidentEditorLocalizations.load(const Locale('en'));

    final tableNode = TableNode.fromList([
      ['a', 'b'],
      ['c', 'd'],
    ]);
    if (tableAttributes != null) {
      tableNode.node.updateAttributes(tableAttributes);
    }
    final document = Document.blank()..insert([0], [tableNode.node]);
    final editorState = EditorState(document: document);

    final builders = {
      ...standardBlockComponentBuilderMap,
      TableBlockKeys.type: TableBlockComponentBuilder(
        tableStyle: tableStyle,
        actionMenuItems: actionMenuItems,
      ),
      TableCellBlockKeys.type: TableCellBlockComponentBuilder(
        actionMenuItems: actionMenuItems,
      ),
    };

    await tester.pumpWidget(
      MaterialApp(
        localizationsDelegates: const [
          GlobalMaterialLocalizations.delegate,
          GlobalCupertinoLocalizations.delegate,
          GlobalWidgetsLocalizations.delegate,
          NovidentEditorLocalizations.delegate,
        ],
        supportedLocales: NovidentEditorLocalizations.delegate.supportedLocales,
        home: Scaffold(
          body: NovidentEditor(
            editorState: editorState,
            blockComponentBuilders: builders,
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();

    return editorState;
  }

  Node tableNodeOf(EditorState editorState) =>
      editorState.document.root.children.first;

  group('table action menu customization', () {
    test('defaultTableActionMenuItems exposes the 7 built-in entries', () {
      expect(defaultTableActionMenuItems.length, 7);
      expect(
        defaultTableActionMenuItems,
        containsAllInOrder([
          tableActionAddBeforeItem,
          tableActionAddAfterItem,
          tableActionRemoveItem,
          tableActionDuplicateItem,
          tableActionBackgroundColorItem,
          tableActionClearItem,
          tableActionBorderPropertiesItem,
        ]),
      );
      // the list is unmodifiable — copy it to customize.
      expect(
        () => defaultTableActionMenuItems.add(tableActionClearItem),
        throwsUnsupportedError,
      );
    });

    testWidgets('custom items are plumbed to the row and column handlers',
        (tester) async {
      final customItems = [
        TableActionMenuItem(
          nameBuilder: (_) => 'Custom action',
          iconBuilder: (_) => Icons.star,
          onPressed: (_) {},
        ),
      ];
      await pumpTableEditor(tester, actionMenuItems: customItems);

      final handlers = tester
          .widgetList<TableActionHandler>(find.byType(TableActionHandler))
          .toList();
      // 2 column handlers + 4 row handlers (one per cell).
      expect(handlers, isNotEmpty);
      for (final handler in handlers) {
        expect(handler.actionMenuItems, same(customItems));
      }
    });

    testWidgets('showActionMenu renders custom items and invokes onPressed',
        (tester) async {
      final editorState = await pumpTableEditor(tester);
      final node = tableNodeOf(editorState);

      TableActionMenuContext? pressedContext;
      final items = [
        TableActionMenuItem(
          nameBuilder: (dir) => dir == TableDirection.col
              ? 'Column custom action'
              : 'Row custom action',
          iconBuilder: (_) => Icons.star,
          onPressed: (menuContext) {
            pressedContext = menuContext;
            menuContext.dismiss();
          },
        ),
        TableActionMenuItem(
          nameBuilder: (_) => 'Hidden for columns',
          iconBuilder: (_) => Icons.visibility_off,
          onPressed: (_) {},
          visible: (_, __, dir) => dir == TableDirection.row,
        ),
      ];

      showActionMenu(
        tester.element(find.byType(TableView)),
        node,
        editorState,
        1,
        TableDirection.col,
        items: items,
      );
      await tester.pumpAndSettle();

      // the custom item is rendered with the direction-aware label and the
      // hidden one is filtered out by its visible predicate.
      expect(find.text('Column custom action'), findsOneWidget);
      expect(find.text('Hidden for columns'), findsNothing);
      // built-in entries are not rendered when a custom list is provided.
      expect(find.text(NovidentEditorL10n.current.colRemove), findsNothing);

      await tester.tap(find.text('Column custom action'));
      await tester.pumpAndSettle();

      expect(pressedContext, isNotNull);
      expect(pressedContext!.node, same(node));
      expect(pressedContext!.position, 1);
      expect(pressedContext!.dir, TableDirection.col);
      // dismiss() removed the overlay.
      expect(find.text('Column custom action'), findsNothing);
    });

    testWidgets('showActionMenu renders the built-in entries by default',
        (tester) async {
      final editorState = await pumpTableEditor(tester);

      showActionMenu(
        tester.element(find.byType(TableView)),
        tableNodeOf(editorState),
        editorState,
        0,
        TableDirection.row,
      );
      await tester.pumpAndSettle();

      expect(find.text(NovidentEditorL10n.current.rowAddBefore), findsOneWidget);
      expect(find.text(NovidentEditorL10n.current.rowAddAfter), findsOneWidget);
      expect(find.text(NovidentEditorL10n.current.rowRemove), findsOneWidget);
      expect(
        find.text(NovidentEditorL10n.current.rowDuplicate),
        findsOneWidget,
      );
      expect(
        find.text(NovidentEditorL10n.current.backgroundColor),
        findsOneWidget,
      );
      expect(find.text(NovidentEditorL10n.current.rowClear), findsOneWidget);

      // dismiss the overlay to leave a clean tree.
      await tester.tapAt(Offset.zero);
      await tester.pumpAndSettle();
    });
  });

  group('per-table border properties', () {
    testWidgets('TableActions.setBorderColor overrides the style color live',
        (tester) async {
      const customColor = Color(0xFF9C27B0);
      final editorState = await pumpTableEditor(tester);
      final node = tableNodeOf(editorState);

      TableActions.setBorderColor(
        node,
        editorState,
        color: '0xFF9C27B0',
      );
      await tester.pumpAndSettle();

      expect(node.attributes[TableBlockKeys.borderColor], '0xFF9C27B0');

      // vertical borders (fixed + resizable) use the override.
      final borderContainers = tester
          .widgetList<TableColBorder>(find.byType(TableColBorder))
          .toList();
      expect(borderContainers, isNotEmpty);
      for (final border in borderContainers) {
        final container = tester.widget<Container>(
          find
              .descendant(
                of: find.byWidget(border),
                matching: find.byType(Container),
              )
              .first,
        );
        expect(container.color, customColor);
      }

      // removing the override falls back to the style color.
      TableActions.setBorderColor(node, editorState, color: null);
      await tester.pumpAndSettle();

      final fixedBorder = tester.widget<Container>(
        find
            .descendant(
              of: find.byWidgetPredicate(
                (w) => w is TableColBorder && !w.resizable,
              ),
              matching: find.byType(Container),
            )
            .first,
      );
      expect(fixedBorder.color, TableDefaults.borderColor);
    });

    testWidgets(
        'TableActions.setBorderWidth updates the grid geometry live',
        (tester) async {
      final editorState = await pumpTableEditor(tester);
      final node = tableNodeOf(editorState);

      TableActions.setBorderWidth(node, editorState, width: 4);
      await tester.pumpAndSettle();

      expect(node.attributes[TableBlockKeys.borderWidth], 4);

      // vertical borders are rendered with the new width.
      final resizableBorder = tester.widget<Container>(
        find
            .descendant(
              of: find.byWidgetPredicate(
                (w) => w is TableColBorder && w.resizable,
              ),
              matching: find.byType(Container),
            )
            .first,
      );
      expect(resizableBorder.constraints?.maxWidth, 4);

      // the colsHeight attribute is recomputed with the new border width.
      final tableNode = TableNode(node: node);
      expect(tableNode.config.borderWidth, 4);
      expect(node.attributes[TableBlockKeys.colsHeight], tableNode.colsHeight);
    });

    testWidgets(
        'the border properties submenu changes the width and opens the '
        'color picker', (tester) async {
      final editorState = await pumpTableEditor(tester);
      final node = tableNodeOf(editorState);

      // open the default context menu: the border properties entry exists.
      showActionMenu(
        tester.element(find.byType(TableView)),
        node,
        editorState,
        0,
        TableDirection.col,
      );
      await tester.pumpAndSettle();
      expect(find.text('Border properties'), findsOneWidget);

      // open the submenu.
      await tester.tap(find.text('Border properties'));
      await tester.pumpAndSettle();
      expect(find.text('Width'), findsOneWidget);
      expect(find.text('Border color'), findsOneWidget);
      // the action menu was dismissed when the submenu opened.
      expect(find.text('Border properties'), findsNothing);

      // pick a width preset.
      await tester.tap(find.text('3'));
      await tester.pumpAndSettle();
      expect(node.attributes[TableBlockKeys.borderWidth], 3);
      expect(find.text('Width'), findsNothing);

      // reopen and open the color picker.
      showActionMenu(
        tester.element(find.byType(TableView)),
        node,
        editorState,
        0,
        TableDirection.col,
      );
      await tester.pumpAndSettle();
      await tester.tap(find.text('Border properties'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Border color'));
      await tester.pumpAndSettle();

      expect(find.byType(ColorPicker), findsOneWidget);

      // dismiss the picker to leave a clean tree.
      await tester.tapAt(Offset.zero);
      await tester.pumpAndSettle();
    });

    testWidgets('the width reset chip removes the override', (tester) async {
      final editorState = await pumpTableEditor(tester);
      final node = tableNodeOf(editorState);

      TableActions.setBorderWidth(node, editorState, width: 4);
      await tester.pumpAndSettle();
      expect(node.attributes[TableBlockKeys.borderWidth], 4);

      showActionMenu(
        tester.element(find.byType(TableView)),
        node,
        editorState,
        0,
        TableDirection.row,
      );
      await tester.pumpAndSettle();
      await tester.tap(find.text('Border properties'));
      await tester.pumpAndSettle();

      await tester.tap(find.byIcon(Icons.format_clear));
      await tester.pumpAndSettle();

      expect(node.attributes[TableBlockKeys.borderWidth], null);
      // geometry falls back to the style width.
      expect(TableNode(node: node).config.borderWidth, 2.0);
    });
  });

  group('per-table horizontal scroll', () {
    Finder tableScrollView() => find.descendant(
          of: find.byType(TableBlockComponentWidget),
          matching: find.byType(SingleChildScrollView),
        );

    testWidgets('the node attribute overrides an enabled style',
        (tester) async {
      await pumpTableEditor(
        tester,
        // style default: enableHorizontalScroll = true
        tableAttributes: {TableBlockKeys.enableHorizontalScroll: false},
      );

      expect(tableScrollView(), findsNothing);
      expect(find.byType(TableView), findsOneWidget);
    });

    testWidgets('the node attribute overrides a disabled style',
        (tester) async {
      await pumpTableEditor(
        tester,
        tableStyle: const TableStyle(enableHorizontalScroll: false),
        tableAttributes: {TableBlockKeys.enableHorizontalScroll: true},
      );

      expect(tableScrollView(), findsOneWidget);
    });

    testWidgets('without the attribute the style value is used',
        (tester) async {
      await pumpTableEditor(
        tester,
        tableStyle: const TableStyle(enableHorizontalScroll: false),
      );

      expect(tableScrollView(), findsNothing);
    });

    testWidgets(
        'TableActions.setEnableHorizontalScroll toggles a single table live',
        (tester) async {
      final editorState = await pumpTableEditor(tester);
      final node = tableNodeOf(editorState);

      expect(tableScrollView(), findsOneWidget);

      TableActions.setEnableHorizontalScroll(
        node,
        editorState,
        enable: false,
      );
      await tester.pumpAndSettle();

      expect(node.attributes[TableBlockKeys.enableHorizontalScroll], false);
      expect(tableScrollView(), findsNothing);

      // removing the override falls back to the style value.
      TableActions.setEnableHorizontalScroll(
        node,
        editorState,
        enable: null,
      );
      await tester.pumpAndSettle();

      expect(tableScrollView(), findsOneWidget);
    });
  });
}
