import 'package:novident_editor/novident_editor.dart';

/// Content for `Novident Showcase ▸ Stress Test ▸ Long Document`.
///
/// A very large document (~9000 nodes, 150k+ words) built to push the editor
/// to its limits. The weight is deliberately distributed across many small
/// paragraph nodes — never one giant node — because a single oversized
/// paragraph would overwhelm `RenderParagraph`. Each paragraph stays well
/// under the ~500-word ceiling typical of long-form prose.
final Document longStressDocument = Document(
  root: pageNode(
    children: _buildLongDocument(),
  ),
);

/// Content for `Novident Showcase ▸ Stress Test ▸ Medium Document`.
///
/// A smaller (~2000 nodes) but still substantial document for testing
/// scrolling and selection over a long body of text.
final Document mediumStressDocument = Document(
  root: pageNode(
    children: _buildMediumDocument(),
  ),
);

/// A pool of short sentences used to compose paragraphs. The pool is small
/// on purpose: this is a stress test, not prose — the goal is volume and
/// node distribution, not literary variety.
const List<String> _sentences = <String>[
  'The editor keeps every change in a transaction',
  'Nodes form a tree rooted at the page',
  'Rich text is stored as a Quill-style delta',
  'Each block type maps to a component builder',
  'Undo and redo invert the recorded operations',
  'The span pipeline resolves styles in six phases',
  'Selections are rendered by a dedicated renderer',
  'Spell check runs out of band after typing pauses',
  'Tables lay out columns by weight',
  'Vim mode emulates normal, insert and visual modes',
  'Zen mode dims the blocks that are not focused',
  'Typewriter scrolling keeps the caret centered',
  'Named styles inherit through a registry',
  'The document serializes to JSON for storage',
  'Keyboard handling is composed from strategies',
  'IME input flows through dedicated services',
  'Columns split the page into side-by-side panes',
  'Images load from a URL or base64 data',
  'The toolbar exposes formatting and block actions',
  'Localization ships with twenty-three locales',
  'A path addresses a node by child indices',
  'The renderer virtualizes long documents',
  'Block components compose shared behavior',
  'The clipboard moves plain text between nodes',
];

/// Builds a paragraph of 3–5 sentences (~30–40 words) from the sentence
/// pool, seeded so consecutive paragraphs differ.
String _paragraph(int seed) {
  final count = 3 + (seed % 3);
  final buffer = StringBuffer();
  for (var i = 0; i < count; i++) {
    if (i > 0) {
      buffer.write(' ');
    }
    buffer
      ..write(_sentences[(seed + i * 7) % _sentences.length])
      ..write('.');
  }
  return buffer.toString();
}

/// 900 groups × 10 nodes (1 heading + 9 paragraphs) = 9000 nodes.
List<Node> _buildLongDocument() {
  final nodes = <Node>[];
  for (var g = 0; g < 900; g++) {
    nodes.add(headingNode(level: 2, text: 'Section ${g + 1}'));
    for (var p = 0; p < 9; p++) {
      nodes.add(paragraphNode(text: _paragraph(g * 9 + p)));
    }
  }
  return nodes;
}

/// 200 groups × 10 nodes = 2000 nodes.
List<Node> _buildMediumDocument() {
  final nodes = <Node>[];
  for (var g = 0; g < 200; g++) {
    nodes.add(headingNode(level: 2, text: 'Section ${g + 1}'));
    for (var p = 0; p < 9; p++) {
      nodes.add(paragraphNode(text: _paragraph(g * 9 + p)));
    }
  }
  return nodes;
}
