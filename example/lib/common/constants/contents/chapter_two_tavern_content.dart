import 'package:novident_editor/novident_editor.dart';

/// Content for `Manuscript ▸ Chapter 2 ▸ The Tavern`.
final Document tavernDocument = Document(
  root: pageNode(
    children: <Node>[
      headingNode(level: 2, text: 'The Tavern'),
      paragraphNode(
        delta: Delta()
          ..insert('The ')
          ..insert(
            'Wandering Lantern',
            attributes: <String, dynamic>{NovidentRichTextKeys.bold: true},
          )
          ..insert(' was the only building in the village with its windows '
              'still lit past midnight, and the only place where questions '
              'about the forest were answered with anything other than a '
              'closed door.'),
      ),
      paragraphNode(
        text: 'Elara pushed inside. The warmth hit her first — woodsmoke, '
            'spilled ale, wet wool. A dozen faces turned toward her, then '
            'quickly away. Only the innkeeper held her gaze.',
      ),
      paragraphNode(text: '"You\'ve seen it," he said. Not a question.'),
      paragraphNode(
        text: 'He set down the mug he had been drying and nodded toward '
            'the empty stool at the end of the bar, the one nobody ever '
            'seemed to sit on.',
      ),
      paragraphNode(text: '"Twelve stones," she said quietly.'),
      paragraphNode(
        text: 'The room went still. Someone\'s chair scraped. The fire '
            'popped once, loud as a snapped branch.',
      ),
      quoteNode(
        delta: Delta()
          ..insert('"Then it\'s chosen the path," the innkeeper said. "And '
              'paths, girl — paths go both ways."'),
      ),
    ],
  ),
);
