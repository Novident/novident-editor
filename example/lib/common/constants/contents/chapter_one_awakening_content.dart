import 'package:novident_editor/novident_editor.dart';

/// Content for `Manuscript ▸ Chapter 1 ▸ Awakening`.
final Document awakeningDocument = Document(
  root: pageNode(
    children: <Node>[
      headingNode(level: 2, text: 'Awakening'),
      paragraphNode(
        text: 'The first thing Elara noticed was the silence. Not the '
            'comfortable hush of a sleeping house, but a silence so complete '
            'it felt like a held breath.',
      ),
      paragraphNode(
        text: 'She sat up. The candle by her bed had burned down to a stub '
            'of wax, and the window she was certain she had latched the night '
            'before now stood open, its curtains perfectly still despite the '
            'cold air pouring in.',
      ),
      paragraphNode(
        delta: Delta()
          ..insert(
            'Something is wrong with the woods tonight.',
            attributes: <String, dynamic>{NovidentRichTextKeys.italic: true},
          ),
      ),
      paragraphNode(
        delta: Delta()
          ..insert('The thought arrived unbidden, the way her grandmother\'s '
              'warnings always did — half memory, half instinct. Beyond the '
              'garden wall, the treeline of the ')
          ..insert(
            'Hollow Forest',
            attributes: <String, dynamic>{NovidentRichTextKeys.bold: true},
          )
          ..insert(' stood darker than the sky behind it, and no owl called, '
              'no branch creaked.'),
      ),
      paragraphNode(text: 'Her grandmother used to say:'),
      quoteNode(
        delta: Delta()
          ..insert(
            'When the forest goes quiet, it is because it is listening.',
          ),
      ),
      paragraphNode(
        text: 'Elara pulled on her boots, took the iron knife from the '
            'drawer, and did the one thing every sensible person in the '
            'village would have told her not to do.',
      ),
      paragraphNode(text: 'She went outside.'),
    ],
  ),
);
