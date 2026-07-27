import 'package:novident_editor/novident_editor.dart';

final Document readmeDocument = Document(
  root: pageNode(
    children: <Node>[
      paragraphNode(text: 'Readme', styleRef: kHeadingDefaultStyles[0].id),
      paragraphNode(text: 'So, this is just an example'),

      // fromList — plain text, column-major ordering
      paragraphNode(text: '1. Basic table (fromList)'),
      TableNode.fromList([
        ['Name', 'Elara', 'Doran'], // column 0
        ['Role', 'Mage', 'Warrior'], // column 1
        ['Level', '8', '6'], // column 2
      ]).node,

      // fromNodes — any node type, column-major
      paragraphNode(text: '2. Table with mixed nodes (fromNodes)'),
      TableNode.fromNodes([
        [
          headingNode(level: 3, text: 'Item'),
          paragraphNode(text: 'Potion'),
        ],
        [
          paragraphNode(text: 'Price'),
          paragraphNode(text: '15 gp'),
        ],
        [
          paragraphNode(
            delta: Delta()..insert('Stock', attributes: {'bold': true}),
          ),
          paragraphNode(text: '12'),
        ],
      ]).node,

      // fromNodes + TableConfig — custom dimensions
      paragraphNode(text: '3. Table with custom sizes'),
      TableNode.fromNodes(
        [
          [
            headingNode(level: 3, text: 'Feature'),
            paragraphNode(text: 'Tables'),
            paragraphNode(text: 'Rich text'),
          ],
          [
            paragraphNode(
              delta: Delta()..insert('Status', attributes: {'italic': true}),
            ),
            paragraphNode(text: 'Done'),
            paragraphNode(text: 'Done'),
          ],
        ],
        config: TableConfig(
          colDefaultWidth: 140,
          rowDefaultHeight: 44,
          colMinimumWidth: 60,
          borderWidth: 2,
        ),
      ).node,

      // fromNodes + tableCellNode — per-cell attrs
      paragraphNode(
          text: '4. Table with backgrounds (fromNodes + tableCellNode)'),
      TableNode.fromNodes([
        // header row — blue background on every cell
        [
          tableCellNode(
            rowPosition: 0,
            colPosition: 0,
            child: paragraphNode(text: 'Header A'),
            rowBackgroundColor: '0xFFE3F2FD',
          ),
          tableCellNode(
            rowPosition: 0,
            colPosition: 1,
            child: paragraphNode(text: 'Header B'),
            rowBackgroundColor: '0xFFE3F2FD',
          ),
          tableCellNode(
            rowPosition: 0,
            colPosition: 2,
            child: paragraphNode(text: 'Header C'),
            rowBackgroundColor: '0xFFE3F2FD',
          ),
        ],
        // data row — orange background on every cell
        [
          tableCellNode(
            rowPosition: 1,
            colPosition: 0,
            child: paragraphNode(text: 'Value 1'),
            colBackgroundColor: '0xFFFFF3E0',
          ),
          tableCellNode(
            rowPosition: 1,
            colPosition: 1,
            child: paragraphNode(text: 'Value 2'),
            colBackgroundColor: '0xFFFFF3E0',
          ),
          tableCellNode(
            rowPosition: 1,
            colPosition: 2,
            child: paragraphNode(text: 'Value 3'),
            colBackgroundColor: '0xFFFFF3E0',
          ),
        ],
      ]).node,
    ],
  ),
);
