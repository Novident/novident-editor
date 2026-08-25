import 'package:novident_editor/novident_editor.dart';

import 'readme_document.dart' show kReadmeAccentTable, kReadmePlainTable, kReadmeStripedTable;

/// Content for `Novident Showcase ▸ Tables`.
///
/// Demonstrates the table block: `TableNode.fromList` for plain strings,
/// `TableNode.fromNodes` for arbitrary node content, and the built-in table
/// styles (striped, plain, accent).
final Document tablesDocument = Document(
  root: pageNode(
    children: <Node>[
      headingNode(level: 1, text: 'Tables'),
      paragraphNode(
        text: 'Tables are a weight-based column layout. Build them with '
            '`TableNode.fromList` (strings) or `TableNode.fromNodes` (any '
            'node). The outer list is columns, each inner list is the rows '
            'of that column.',
      ),
      headingNode(level: 2, text: 'Basic table'),
      paragraphNode(text: 'A simple 2×2 table from plain strings:'),
      TableNode.fromList(
        [
          ['Name', 'Role'],
          ['Elara', 'Mage'],
        ],
      ).node,
      headingNode(level: 2, text: 'Mixed content'),
      paragraphNode(
        text: 'Cells can hold any block — here a heading and a styled '
            'paragraph:',
      ),
      TableNode.fromNodes(
        [
          [
            headingNode(level: 3, text: 'Item'),
            paragraphNode(text: 'Potion'),
          ],
          [
            paragraphNode(text: 'Price'),
            paragraphNode(
              delta: Delta()..insert('15 gp', attributes: <String, dynamic>{RichTextKeys.bold: true}),
            ),
          ],
        ],
      ).node,
      headingNode(level: 2, text: 'Table styles'),
      paragraphNode(
        text: 'Tables can reference a named style with `styleRef`. Three '
            'styles ship with the example:',
      ),
      paragraphNode(text: 'Striped with header:'),
      TableNode.fromNodes(
        [
          [paragraphNode(text: 'Name'), paragraphNode(text: 'Role')],
          [paragraphNode(text: 'Elara'), paragraphNode(text: 'Mage')],
          [paragraphNode(text: 'Doran'), paragraphNode(text: 'Warrior')],
        ],
        styleRef: kReadmeStripedTable.id,
      ).node,
      paragraphNode(text: 'Borderless:'),
      TableNode.fromNodes(
        [
          [paragraphNode(text: 'Feature'), paragraphNode(text: 'Status')],
          [paragraphNode(text: 'noBorder'), paragraphNode(text: '✅')],
        ],
        styleRef: kReadmePlainTable.id,
      ).node,
      paragraphNode(text: 'Accent header:'),
      TableNode.fromNodes(
        [
          [paragraphNode(text: 'Task'), paragraphNode(text: 'Owner')],
          [paragraphNode(text: 'Design system'), paragraphNode(text: 'Elara')],
          [paragraphNode(text: 'Documentation'), paragraphNode(text: 'Lyra')],
        ],
        styleRef: kReadmeAccentTable.id,
      ).node,
    ],
  ),
);