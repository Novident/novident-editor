import 'package:flutter/material.dart';
import 'package:novident_editor/novident_editor.dart';

// ── Custom table styles (registered in the editor's styles config) ──
//
// These styles demonstrate how to use NovidentTableStyleDefinition.
// They are referenced by name via the 'styleRef' node attribute.
//
// Usage in the editor:
//   styles: NovidentStylesConfig(
//     registry: NovidentStyleRegistry({
//       ...kDefaultStyleRegistry.styles,
//       'readme-striped': kReadmeStripedTable,
//       'readme-plain': kReadmePlainTable,
//       'readme-colored': kReadmeColoredTable,
//     }),
//     defaultStyle: kDefaultBaseStyle,
//     defaultStylesByType: {'table': kDefaultTableStyle},
//   ),

/// Zebra-striped table: alternating even/odd row colors.
final kReadmeStripedTable = NovidentTableStyleDefinition.nextSame(
  id: 'readme-striped',
  name: 'Striped',
  basedOn: kDefaultTableStyle.id,
  evenRowColor: const Color(0xFFEEEEEE),
  oddRowColor: const Color(0xFFFFFFFF),
  headerRowCount: 1,
  headerStyle: const NovidentTableRowStyle(
    bold: true,
    alignment: TextAlign.center,
    backgroundColor: Color(0xFF1976D2),
    textColor: Colors.white,
  ),
);

/// Borderless table: clean, no borders anywhere.
final kReadmePlainTable = NovidentTableStyleDefinition.nextSame(
  id: 'readme-plain',
  name: 'Plain',
  basedOn: kDefaultTableStyle.id,
  noBorder: true,
  cellPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
);

/// Colored table: styled header row via the style system.
/// No per-cell attributes needed — the style handles everything.
final kReadmeColoredTable = NovidentTableStyleDefinition.nextSame(
  id: 'readme-colored',
  name: 'Colored',
  basedOn: kDefaultTableStyle.id,
  headerRowCount: 1,
  headerStyle: const NovidentTableRowStyle(
    backgroundColor: Color(0xFFE3F2FD),
    bold: true,
  ),
  evenRowColor: const Color(0xFFFFF8E1),
  oddRowColor: const Color(0xFFFFF3E0),
);

// ── Document ────────────────────────────────────────────

final Document readmeDocument = Document(
  root: pageNode(
    children: <Node>[
      paragraphNode(text: 'Readme', styleRef: kHeadingDefaultStyles[0].id),
      paragraphNode(text: 'So, this is just an example'),

      // ── 1) fromList — plain text, column-major ────────
      paragraphNode(text: '1. Basic table (fromList)'),
      TableNode.fromList([
        ['Name', 'Elara', 'Doran'], // column 0
        ['Role', 'Mage', 'Warrior'], // column 1
        ['Level', '8', '6'], // column 2
      ]).node,

      // ── 2) fromNodes — any node type, column-major ────
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

      // ── 3) Style: noBorder (borderless table) ────────
      paragraphNode(text: '3. Borderless table (style: readme-plain)'),
      TableNode.fromNodes([
        [
          paragraphNode(text: 'Feature'),
          paragraphNode(text: 'Supports'),
        ],
        [
          paragraphNode(text: 'noBorder'),
          paragraphNode(text: '✅'),
        ],
        [
          paragraphNode(text: 'row striping'),
          paragraphNode(text: '✅'),
        ],
      ]).node,

      // ── 3) Style: noBorder (borderless table) ────────
      paragraphNode(text: '3. Borderless table (style: readme-plain)'),
      TableNode.fromNodes(
        [
          [
            paragraphNode(text: 'Feature'),
            paragraphNode(text: 'Supports'),
          ],
          [
            paragraphNode(text: 'noBorder'),
            paragraphNode(text: '✅'),
          ],
          [
            paragraphNode(text: 'row striping'),
            paragraphNode(text: '✅'),
          ],
        ],
        styleRef: 'readme-plain',
      ).node,

      // ── 4) Style: zebra stripes + colored header ──────
      paragraphNode(text: '4. Striped table (style: readme-striped)'),
      TableNode.fromNodes(
        [
          [paragraphNode(text: 'Name'), paragraphNode(text: 'Elara')],
          [paragraphNode(text: 'Role'), paragraphNode(text: 'Mage')],
          [paragraphNode(text: 'Level'), paragraphNode(text: '8')],
        ],
        styleRef: 'readme-striped',
      ).node,

      // ── 5) Style: colored header + evenRow ───────────
      paragraphNode(text: '5. Colored table (style: readme-colored)'),
      TableNode.fromNodes(
        [
          [paragraphNode(text: 'Header A'), paragraphNode(text: 'Value 1')],
          [paragraphNode(text: 'Header B'), paragraphNode(text: 'Value 2')],
          [paragraphNode(text: 'Header C'), paragraphNode(text: 'Value 3')],
        ],
        styleRef: 'readme-colored',
      ).node,
    ],
  ),
);
