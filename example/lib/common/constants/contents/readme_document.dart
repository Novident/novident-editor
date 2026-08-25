import 'package:flutter/material.dart';
import 'package:novident_editor/novident_editor.dart';

final kReadmeStripedTable = NovidentTableStyleDefinition.nextSame(
  id: 'readme-striped',
  name: 'Striped',
  basedOn: kDefaultTableStyle.id,
  evenRowColor: const Color(0xFFF5F5F5),
  oddRowColor: const Color(0xFFFFFFFF),
  headerRowCount: 1,
  headerStyle: const NovidentTableRowStyle(
    bold: true,
    backgroundColor: Color(0xFF37474F),
    textColor: Colors.white,
    height: 44,
  ),
);

final kReadmePlainTable = NovidentTableStyleDefinition.nextSame(
  id: 'readme-plain',
  name: 'Plain',
  basedOn: kDefaultTableStyle.id,
  noBorder: true,
  cellPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
);

final kReadmeAccentTable = NovidentTableStyleDefinition.nextSame(
  id: 'readme-accent',
  name: 'Accent',
  basedOn: kDefaultTableStyle.id,
  headerRowCount: 1,
  headerStyle: const NovidentTableRowStyle(
    bold: true,
    backgroundColor: Color(0xFFFFF8E1),
    bottomBorderColor: Color(0xFFFFCC02),
    bottomBorderWidth: 2.5,
  ),
  evenRowColor: const Color(0xFFFFFDE7),
  oddRowColor: const Color(0xFFFFF8E1),
);

final Document readmeDocument = Document(
  root: pageNode(
    children: <Node>[
      paragraphNode(text: 'Welcome', styleRef: kHeadingDefaultStyles[0].id),
      paragraphNode(
        text: 'This workspace showcases what the Novident editor can do. '
            'Open each document from the binder to see a different set of '
            'capabilities: text & formatting, lists & todo, blocks & quotes, '
            'tables, columns & layout, and two large stress-test documents '
            'that push the editor to its limits.',
      ),
      paragraphNode(
        text: 'Everything you see is editable — try the toolbar above, '
            'toggle zen mode with the moon button, and drag documents into '
            'the split view on desktop.',
      ),
      paragraphNode(
        text: 'The rest of this document demonstrates the table block and '
            'its built-in styles:',
      ),
      paragraphNode(
          text: '1. Basic table', styleRef: kHeadingDefaultStyles[1].id),
      TableNode.fromList([
        ['Name', 'Elara', 'Doran'],
        ['Role', 'Mage', 'Warrior'],
        ['Level', '8', '6'],
      ]).node,
      paragraphNode(
          text: '2. Mixed content', styleRef: kHeadingDefaultStyles[1].id),
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
          paragraphNode(
            delta: Delta()..insert('Stock', attributes: {'bold': true}),
          ),
          paragraphNode(text: '12'),
          paragraphNode(text: '5'),
        ],
      ]).node,
      paragraphNode(
          text: '3. Borderless', styleRef: kHeadingDefaultStyles[1].id),
      TableNode.fromNodes(
        [
          [paragraphNode(text: 'Feature'), paragraphNode(text: 'Status')],
          [paragraphNode(text: 'noBorder'), paragraphNode(text: '✅')],
          [paragraphNode(text: 'cellPadding'), paragraphNode(text: '✅')],
        ],
        styleRef: 'readme-plain',
      ).node,
      paragraphNode(
          text: '4. Striped with header',
          styleRef: kHeadingDefaultStyles[1].id),
      TableNode.fromNodes(
        [
          [
            paragraphNode(text: 'Name'),
            paragraphNode(text: 'Role'),
            paragraphNode(text: 'Level')
          ],
          [
            paragraphNode(text: 'Elara'),
            paragraphNode(text: 'Mage'),
            paragraphNode(text: '8')
          ],
          [
            paragraphNode(text: 'Doran'),
            paragraphNode(text: 'Warrior'),
            paragraphNode(text: '6')
          ],
          [
            paragraphNode(text: 'Lyra'),
            paragraphNode(text: 'Rogue'),
            paragraphNode(text: '4')
          ],
        ],
        styleRef: 'readme-striped',
      ).node,
      paragraphNode(text: '5. Accent', styleRef: kHeadingDefaultStyles[1].id),
      TableNode.fromNodes(
        [
          [
            paragraphNode(text: 'Task'),
            paragraphNode(text: 'Owner'),
            paragraphNode(text: 'Due')
          ],
          [
            paragraphNode(text: 'Design system'),
            paragraphNode(text: 'Elara'),
            paragraphNode(text: 'Aug 12')
          ],
          [
            paragraphNode(text: 'Table styles'),
            paragraphNode(text: 'Doran'),
            paragraphNode(text: 'Aug 20')
          ],
          [
            paragraphNode(text: 'Documentation'),
            paragraphNode(text: 'Lyra'),
            paragraphNode(text: 'Sep 1')
          ],
        ],
        styleRef: 'readme-accent',
      ).node,
    ],
  ),
);
