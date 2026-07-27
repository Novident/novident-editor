import 'package:flutter_test/flutter_test.dart';
import 'package:novident_editor/novident_editor.dart';

import 'package:novident_editor/src/editor/block_component/table_block_component/table_config.dart';

void main() {
  group('table_node.dart', () {
    test('fromJson', () {
      final tableNode = TableNode.fromJson({
        'type': TableBlockKeys.type,
        'data': {
          TableBlockKeys.colsLen: 2,
          TableBlockKeys.rowsLen: 2,
          TableBlockKeys.colDefaultWidth: 60,
          TableBlockKeys.rowDefaultHeight: 50,
          TableBlockKeys.colMinimumWidth: 30,
        },
        'children': [
          {
            'type': TableCellBlockKeys.type,
            'data': {
              TableCellBlockKeys.colPosition: 0,
              TableCellBlockKeys.rowPosition: 0,
              TableCellBlockKeys.width: 35,
            },
            'children': [
              {
                'type': 'heading',
                'data': {
                  'level': 2,
                  'delta': [
                    {'insert': 'a'},
                  ],
                },
              },
            ],
          },
          {
            'type': TableCellBlockKeys.type,
            'data': {
              TableCellBlockKeys.colPosition: 0,
              TableCellBlockKeys.rowPosition: 1,
            },
            'children': [
              {
                'type': 'paragraph',
                'data': {
                  'delta': [
                    {
                      'insert': 'b',
                      'data': {'bold': true},
                    }
                  ],
                },
              },
            ],
          },
          {
            'type': TableCellBlockKeys.type,
            'data': {
              TableCellBlockKeys.colPosition: 1,
              TableCellBlockKeys.rowPosition: 0,
            },
            'children': [
              {
                'type': 'paragraph',
                'data': {
                  'delta': [
                    {
                      'insert': 'c',
                      'data': {'italic': true},
                    }
                  ],
                },
              },
            ],
          },
          {
            'type': TableCellBlockKeys.type,
            'data': {
              TableCellBlockKeys.colPosition: 1,
              TableCellBlockKeys.rowPosition: 1,
            },
            'children': [
              {
                'type': 'paragraph',
                'data': {
                  'delta': [
                    {'insert': 'd'},
                  ],
                },
              }
            ],
          }
        ],
      });

      expect(tableNode.config.colMinimumWidth, 30);
      expect(tableNode.config.colDefaultWidth, 60);
      expect(tableNode.config.rowDefaultHeight, 50);

      expect(tableNode.getColWidth(0), 35);
      expect(tableNode.getColWidth(1), tableNode.config.colDefaultWidth);

      expect(tableNode.getRowHeight(0), tableNode.config.rowDefaultHeight);
      expect(tableNode.getRowHeight(1), tableNode.config.rowDefaultHeight);

      expect(
        tableNode.getCell(0, 0).children.first.toJson(),
        {
          'type': 'heading',
          'data': {
            'level': 2,
            'delta': [
              {'insert': 'a'},
            ],
          },
        },
      );
      expect(
        tableNode.getCell(1, 0).children.first.toJson(),
        {
          'type': 'paragraph',
          'data': {
            'delta': [
              {
                'insert': 'c',
                'data': {'italic': true},
              }
            ],
          },
        },
      );

      expect(
        tableNode.getCell(1, 1).children.first.toJson(),
        {
          'type': 'paragraph',
          'data': {
            'delta': [
              {'insert': 'd'},
            ],
          },
        },
      );
    });

    test('fromJson - error when columns length mismatch', () {
      final jsonData = {
        'type': TableBlockKeys.type,
        'data': {
          TableBlockKeys.colsLen: 2,
          TableBlockKeys.rowsLen: 2,
          TableBlockKeys.colDefaultWidth: 60,
          TableBlockKeys.rowDefaultHeight: 50,
          TableBlockKeys.colMinimumWidth: 30,
        },
        'children': [
          {
            'type': TableCellBlockKeys.type,
            'data': {
              TableCellBlockKeys.colPosition: 0,
              TableCellBlockKeys.rowPosition: 0,
              TableCellBlockKeys.width: 35,
            },
            'children': [
              {
                'type': 'heading',
                'data': {
                  'level': 2,
                  'delta': [
                    {'insert': 'a'},
                  ],
                },
              },
            ],
          },
          {
            'type': TableCellBlockKeys.type,
            'data': {
              TableCellBlockKeys.colPosition: 1,
              TableCellBlockKeys.rowPosition: 0,
            },
            'children': [
              {
                'type': 'paragraph',
                'data': {
                  'delta': [
                    {
                      'insert': 'c',
                      'data': {'italic': true},
                    }
                  ],
                },
              },
            ],
          },
          {
            'type': TableCellBlockKeys.type,
            'data': {
              TableCellBlockKeys.colPosition: 1,
              TableCellBlockKeys.rowPosition: 1,
            },
            'children': [
              {
                'type': 'paragraph',
                'data': {
                  'delta': [
                    {'insert': 'd'},
                  ],
                },
              }
            ],
          }
        ],
      };

      // it should not throw error
      expect(() => TableNode.fromJson(jsonData), isNot(throwsFlutterError));
    });

    test('default constructor (from list of list of strings)', () {
      final tableNode = TableNode.fromList([
        ['1', '2'],
        ['3', '4'],
      ]);
      final config = TableConfig();

      expect(tableNode.config.colMinimumWidth, config.colMinimumWidth);
      expect(tableNode.config.colDefaultWidth, config.colDefaultWidth);
      expect(tableNode.config.rowDefaultHeight, config.rowDefaultHeight);
      expect(
        tableNode.node.attributes[TableBlockKeys.colMinimumWidth],
        config.colMinimumWidth,
      );

      expect(tableNode.getColWidth(0), config.colDefaultWidth);
      expect(tableNode.getColWidth(1), config.colDefaultWidth);

      expect(tableNode.getRowHeight(0), config.rowDefaultHeight);
      expect(tableNode.getRowHeight(1), config.rowDefaultHeight);

      expect(
        tableNode.getCell(0, 0).children.first.toJson(),
        {
          'type': 'paragraph',
          'data': {
            'delta': [
              {'insert': '1'},
            ],
          },
        },
      );
      expect(
        tableNode.getCell(1, 0).children.first.toJson(),
        {
          'type': 'paragraph',
          'data': {
            'delta': [
              {
                'insert': '3',
              }
            ],
          },
        },
      );

      expect(
        tableNode.getCell(1, 1).children.first.toJson(),
        {
          'type': 'paragraph',
          'data': {
            'delta': [
              {'insert': '4'},
            ],
          },
        },
      );
    });

    test('default constructor (from list of list of strings)', () {
      final config = TableConfig(
        colMinimumWidth: 10,
        colDefaultWidth: 20,
        rowDefaultHeight: 30,
      );
      final tableNode = TableNode.fromList(
        [
          ['1', '2'],
          ['3', '4'],
        ],
        config: config,
      );

      expect(tableNode.config.colMinimumWidth, config.colMinimumWidth);
      expect(tableNode.config.colDefaultWidth, config.colDefaultWidth);
      expect(tableNode.config.rowDefaultHeight, config.rowDefaultHeight);

      expect(tableNode.getColWidth(0), config.colDefaultWidth);

      expect(tableNode.getRowHeight(1), config.rowDefaultHeight);

      expect(
        tableNode.getCell(1, 0).children.first.toJson(),
        {
          'type': 'paragraph',
          'data': {
            'delta': [
              {
                'insert': '3',
              }
            ],
          },
        },
      );
    });

    test(
        'default constructor (from list of list of strings) - error when columns length mismatch',
        () {
      final listData = [
        ['1', '2'],
        ['3'],
      ];

      expect(() => TableNode.fromList(listData), throwsAssertionError);
    });

    group('fromNodes', () {
      test('creates a table from paragraph nodes', () {
        final tableNode = TableNode.fromNodes([
          [paragraphNode(text: 'A1'), paragraphNode(text: 'B1')],
          [paragraphNode(text: 'A2'), paragraphNode(text: 'B2')],
        ]);

        expect(tableNode.colsLen, 2);
        expect(tableNode.rowsLen, 2);
        expect(
          tableNode.getCell(0, 0).children.first.toJson(),
          {
            'type': 'paragraph',
            'data': {
              'delta': [{'insert': 'A1'}],
            },
          },
        );
        expect(
          tableNode.getCell(1, 0).children.first.toJson(),
          {
            'type': 'paragraph',
            'data': {
              'delta': [{'insert': 'A2'}],
            },
          },
        );
      });

      test('creates a table from heading nodes', () {
        final tableNode = TableNode.fromNodes([
          [
            headingNode(level: 2, text: 'Header'),
            headingNode(level: 3, text: 'Sub'),
          ],
          [
            paragraphNode(text: 'Data A'),
            paragraphNode(text: 'Data B'),
          ],
        ]);

        expect(tableNode.colsLen, 2);
        expect(tableNode.rowsLen, 2);
        expect(
          tableNode.getCell(0, 0).children.first.toJson(),
          {
            'type': 'heading',
            'data': {
              'level': 2,
              'delta': [{'insert': 'Header'}],
            },
          },
        );
      });

      test('creates a table with styled deltas', () {
        final tableNode = TableNode.fromNodes([
          [
            paragraphNode(
              delta: Delta()
                ..insert('bold')
                ..insert(' text', attributes: {'bold': true}),
            ),
            paragraphNode(
              delta: Delta()..insert('italic', attributes: {'italic': true}),
            ),
          ],
        ]);

        expect(tableNode.colsLen, 1);
        expect(tableNode.rowsLen, 2);
        expect(
          tableNode.getCell(0, 0).children.first.toJson(),
          {
            'type': 'paragraph',
            'data': {
              'delta': [
                {'insert': 'bold'},
                {
                  'insert': ' text',
                  'attributes': {'bold': true},
                },
              ],
            },
          },
        );
      });

      test('creates a table with custom config', () {
        final config = TableConfig(
          colDefaultWidth: 200,
          rowDefaultHeight: 60,
          colMinimumWidth: 80,
        );
        final tableNode = TableNode.fromNodes(
          [
            [paragraphNode(text: 'Wide'), paragraphNode(text: 'Col')],
          ],
          config: config,
        );

        expect(tableNode.config.colDefaultWidth, 200);
        expect(tableNode.config.rowDefaultHeight, 60);
        expect(tableNode.config.colMinimumWidth, 80);
        expect(tableNode.getColWidth(0), 200);
        expect(tableNode.getRowHeight(0), 60);
      });

      test('throws assertion error when rows have mismatched lengths', () {
        expect(
          () => TableNode.fromNodes([
            [paragraphNode(text: 'A')],
            [paragraphNode(text: 'B'), paragraphNode(text: 'C')],
          ]),
          throwsAssertionError,
        );
      });

      test('throws assertion error when cols is empty', () {
        expect(
          () => TableNode.fromNodes([]),
          throwsAssertionError,
        );
      });

      test('throws assertion error when rows is empty', () {
        expect(
          () => TableNode.fromNodes([[]]),
          throwsAssertionError,
        );
      });

      test('preserves tableCellNode attributes (width, bg colors)', () {
        final tableNode = TableNode.fromNodes([
          [
            tableCellNode(
              rowPosition: 0,
              colPosition: 0,
              child: paragraphNode(text: 'Cell 00'),
              width: 120,
              rowBackgroundColor: '0xFFE3F2FD',
            ),
            tableCellNode(
              rowPosition: 0,
              colPosition: 1,
              child: paragraphNode(text: 'Cell 10'),
              height: 60,
              colBackgroundColor: '0xFFFFF3E0',
            ),
          ],
        ]);

        expect(tableNode.colsLen, 1);
        expect(tableNode.rowsLen, 2);

        final cell00 = tableNode.getCell(0, 0);
        final cell10 = tableNode.getCell(0, 1);

        // positions are overridden by fromNodes
        expect(cell00.attributes[TableCellBlockKeys.colPosition], 0);
        expect(cell00.attributes[TableCellBlockKeys.rowPosition], 0);
        // custom attributes are preserved
        expect(cell00.attributes[TableCellBlockKeys.width], 120);
        expect(
          cell00.attributes[TableCellBlockKeys.rowBackgroundColor],
          '0xFFE3F2FD',
        );
        // content is preserved
        expect(
          cell00.children.first.toJson(),
          {
            'type': 'paragraph',
            'data': {
              'delta': [{'insert': 'Cell 00'}],
            },
          },
        );

        expect(cell10.attributes[TableCellBlockKeys.colPosition], 0);
        expect(cell10.attributes[TableCellBlockKeys.rowPosition], 1);
        expect(cell10.attributes[TableCellBlockKeys.height], 60);
        expect(
          cell10.attributes[TableCellBlockKeys.colBackgroundColor],
          '0xFFFFF3E0',
        );
      });

      test('mixes raw nodes and tableCellNode wrappers', () {
        final tableNode = TableNode.fromNodes([
          [
            paragraphNode(text: 'Plain cell'),
            tableCellNode(
              rowPosition: 0,
              colPosition: 1,
              child: paragraphNode(text: 'Styled cell'),
              rowBackgroundColor: '0xFFE3F2FD',
            ),
          ],
        ]);

        // plain cell
        final cell0 = tableNode.getCell(0, 0);
        expect(cell0.attributes[TableCellBlockKeys.colPosition], 0);
        expect(cell0.attributes[TableCellBlockKeys.rowPosition], 0);
        expect(
          cell0.children.first.toJson(),
          {
            'type': 'paragraph',
            'data': {
              'delta': [{'insert': 'Plain cell'}],
            },
          },
        );

        // styled cell
        final cell1 = tableNode.getCell(0, 1);
        expect(cell1.attributes[TableCellBlockKeys.colPosition], 0);
        expect(cell1.attributes[TableCellBlockKeys.rowPosition], 1);
        expect(
          cell1.attributes[TableCellBlockKeys.rowBackgroundColor],
          '0xFFE3F2FD',
        );
      });
    });

    test('colsHeight', () {
      final tableNode = TableNode.fromList([
        ['1', '2'],
        ['3', '4'],
      ]);

      expect(
        tableNode.colsHeight,
        tableNode.config.rowDefaultHeight * 2 +
            tableNode.config.borderWidth * 3,
      );
    });
  });
}
