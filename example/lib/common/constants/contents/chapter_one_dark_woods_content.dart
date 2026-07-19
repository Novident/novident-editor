import 'package:novident_editor/novident_editor.dart';

/// Content for `Manuscript ▸ Chapter 1 ▸ Dark Woods`.
final Document darkWoodsDocument = Document(
  root: pageNode(
    children: <Node>[
      headingNode(level: 2, text: 'Dark Woods'),
      paragraphNode(
        text: 'The path into the Hollow Forest had never frightened her in '
            'daylight. She had walked it a hundred times, basket in hand, '
            'counting the white stones her father had set along its edge.',
      ),
      paragraphNode(text: 'Tonight she counted them again.'),
      paragraphNode(
        delta: Delta()
          ..insert(
            'Twelve. There had always been eleven.',
            attributes: <String, dynamic>{NovidentRichTextKeys.italic: true},
          ),
      ),
      paragraphNode(
        delta: Delta()
          ..insert('She stopped beside the new stone. It was the same pale '
              'granite as the others, worn smooth as if it had sat there for '
              'decades, moss climbing its northern face. But it had ')
          ..insert(
            'not',
            attributes: <String, dynamic>{NovidentRichTextKeys.bold: true},
          )
          ..insert(' been there yesterday.'),
      ),
      paragraphNode(
        text: 'Somewhere deeper between the trees, a light flickered — '
            'warm and orange, like a lantern swinging from someone\'s hand. '
            'It was moving away from her, unhurried, patient.',
      ),
      paragraphNode(
        delta: Delta()
          ..insert('Every story she had ever been told ended the same way: ')
          ..insert(
            'never follow the lantern',
            attributes: <String, dynamic>{NovidentRichTextKeys.italic: true},
          )
          ..insert('.'),
      ),
      paragraphNode(
        delta: Delta()
          ..insert('But the stories never mentioned what the lantern does '
              'when you refuse. It stops. And then it starts moving toward ')
          ..insert(
            'you',
            attributes: <String, dynamic>{NovidentRichTextKeys.bold: true},
          )
          ..insert('.'),
      ),
    ],
  ),
);
