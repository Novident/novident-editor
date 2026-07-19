import 'package:novident_editor/novident_editor.dart';
import 'package:novident_editor/src/editor/block_component/table_block_component/table_add_button.dart';
import 'package:novident_editor/src/editor/block_component/table_block_component/table_col.dart';
import 'package:novident_editor/src/editor/block_component/table_block_component/table_col_border.dart';
import 'package:novident_editor/src/editor/block_component/table_block_component/table_config.dart';
import 'package:novident_editor/src/editor/block_component/table_block_component/table_view.dart';
import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_test/flutter_test.dart';

void main() async {
  setUpAll(() {
    TestWidgetsFlutterBinding.ensureInitialized();
  });

  group('TableConfig', () {
    test('toJson serializes borderWidth', () {
      final config = TableConfig(
        colDefaultWidth: 100,
        rowDefaultHeight: 50,
        colMinimumWidth: 30,
        borderWidth: 3,
      );

      final json = config.toJson();
      expect(json[TableBlockKeys.borderWidth], 3);

      // round trip keeps the border width.
      final restored = TableConfig.fromJson(json);
      expect(restored.borderWidth, 3);
      expect(restored.colDefaultWidth, 100);
      expect(restored.rowDefaultHeight, 50);
      expect(restored.colMinimumWidth, 30);
    });
  });

  group('TableNode height synchronization', () {
    test('getRowHeight uses the maximum height across all columns', () {
      final tableNode = TableNode.fromList([
        ['a', 'b'],
        ['c', 'd'],
      ]);

      // column 0 is stale, column 1 has the real (bigger) height.
      tableNode
          .getCell(0, 0)
          .updateAttributes({TableCellBlockKeys.height: 10.0});
      tableNode
          .getCell(1, 0)
          .updateAttributes({TableCellBlockKeys.height: 50.0});

      expect(tableNode.getRowHeight(0), 50.0);
    });

    test(
      'updateRowHeight syncs the other columns even when column 0 is '
      'already up to date',
      () {
        TableDefaults.cellVerticalPadding = 8.0;

        final tableNode = TableNode.fromList([
          ['a', 'b'],
          ['c', 'd'],
        ]);

        // unmounted nodes measure Rect.zero, so the computed row height is
        // deterministic: 0 + cellVerticalPadding.
        const expectedHeight = 8.0;

        // column 0 already has the target height, column 1 is stale. The old
        // guard (checking only column 0) skipped the synchronization here.
        tableNode
            .getCell(0, 0)
            .updateAttributes({TableCellBlockKeys.height: expectedHeight});
        tableNode
            .getCell(1, 0)
            .updateAttributes({TableCellBlockKeys.height: 40.0});

        tableNode.updateRowHeight(0);

        expect(
          tableNode.getCell(1, 0).attributes[TableCellBlockKeys.height],
          expectedHeight,
        );
        expect(
          tableNode.node.attributes[TableBlockKeys.colsHeight],
          tableNode.colsHeight,
        );
      },
    );
  });

  group('TableStyle rendering options', () {
    Future<EditorState> pumpTableEditor(
      WidgetTester tester, {
      TableStyle tableStyle = const TableStyle(),
      EdgeInsets? cellPadding,
    }) async {
      await NovidentEditorLocalizations.load(const Locale('en'));

      final tableNode = TableNode.fromList([
        ['a', 'b'],
        ['c', 'd'],
      ]);
      final document = Document.blank()..insert([0], [tableNode.node]);
      final editorState = EditorState(document: document);

      final builders = {
        ...standardBlockComponentBuilderMap,
        TableBlockKeys.type: TableBlockComponentBuilder(
          tableStyle: tableStyle,
        ),
        TableCellBlockKeys.type: TableCellBlockComponentBuilder(
          padding: cellPadding ?? const EdgeInsets.symmetric(horizontal: 4),
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
          supportedLocales:
              NovidentEditorLocalizations.delegate.supportedLocales,
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

    testWidgets('the fixed left border uses TableStyle.borderColor',
        (tester) async {
      const customBorderColor = Color(0xFF9C27B0);
      await pumpTableEditor(
        tester,
        tableStyle: const TableStyle(borderColor: customBorderColor),
      );

      final fixedBorderFinder = find.byWidgetPredicate(
        (w) => w is TableColBorder && !w.resizable,
      );
      expect(fixedBorderFinder, findsOneWidget);

      final container = tester.widget<Container>(
        find
            .descendant(
              of: fixedBorderFinder,
              matching: find.byType(Container),
            )
            .first,
      );
      expect(container.color, customBorderColor);
    });

    testWidgets('enableHorizontalScroll: true keeps the internal scroll view',
        (tester) async {
      await pumpTableEditor(tester);

      expect(
        find.descendant(
          of: find.byType(TableBlockComponentWidget),
          matching: find.byType(SingleChildScrollView),
        ),
        findsOneWidget,
      );
    });

    testWidgets(
        'enableHorizontalScroll: false removes the internal scroll view',
        (tester) async {
      await pumpTableEditor(
        tester,
        tableStyle: const TableStyle(enableHorizontalScroll: false),
      );

      expect(
        find.descendant(
          of: find.byType(TableBlockComponentWidget),
          matching: find.byType(SingleChildScrollView),
        ),
        findsNothing,
      );
      // the table is still rendered.
      expect(find.byType(TableView), findsOneWidget);
    });

    testWidgets('the add row/column buttons can be hidden', (tester) async {
      await pumpTableEditor(
        tester,
        tableStyle: const TableStyle(
          showAddColumnButton: false,
          showAddRowButton: false,
        ),
      );

      expect(find.byType(TableActionButton), findsNothing);
    });

    testWidgets('the add row/column buttons are shown by default',
        (tester) async {
      await pumpTableEditor(tester);

      expect(find.byType(TableActionButton), findsNWidgets(2));
    });

    testWidgets('the cell padding is configurable', (tester) async {
      const customPadding = EdgeInsets.symmetric(horizontal: 12);
      await pumpTableEditor(tester, cellPadding: customPadding);

      final paddingFinder = find.descendant(
        of: find.byType(TableCelBlockWidget),
        matching: find.byWidgetPredicate(
          (w) => w is Padding && w.padding == customPadding,
        ),
      );
      // one per cell (2x2).
      expect(paddingFinder, findsNWidgets(4));
    });

    testWidgets(
        'the grid rows/columns are anchored to the start '
        '(no centered gap splitting)', (tester) async {
      await pumpTableEditor(tester);

      // the root Row of every TableCol is start-aligned.
      final colRow = tester.widget<Row>(
        find
            .descendant(
              of: find.byType(TableCol).first,
              matching: find.byType(Row),
            )
            .first,
      );
      expect(colRow.crossAxisAlignment, CrossAxisAlignment.start);

      // the Column of the TableView is start-aligned.
      final viewColumn = tester.widget<Column>(
        find
            .descendant(
              of: find.byType(TableView),
              matching: find.byType(Column),
            )
            .first,
      );
      expect(viewColumn.crossAxisAlignment, CrossAxisAlignment.start);
    });
  });
}
