import 'package:novident_editor/novident_editor.dart';

/// Content for `Places ▸ The Hollow Forest` (setting sheet).
final Document placeHollowForestDocument = Document(
  root: pageNode(
    children: <Node>[
      headingNode(level: 2, text: 'The Hollow Forest'),
      paragraphNode(
        text: 'Ancient woodland bordering Bryrmoor to the north. The '
            'canopy is dense enough that noon looks like dusk, and the '
            'village marks its only safe path with white granite stones.',
      ),
      headingNode(level: 3, text: 'Rules of the forest'),
      numberedListNode(
        delta: Delta()
          ..insert('The stones count themselves. If the count changes, the '
              'path has changed.'),
      ),
      numberedListNode(
        delta: Delta()
          ..insert(
            'Silence means it is listening. Noise means it is speaking.',
          ),
      ),
      numberedListNode(
        delta: Delta()..insert('Never follow the lantern light.'),
      ),
      headingNode(level: 3, text: 'Open questions'),
      bulletedListNode(text: 'Who set the original eleven stones?'),
      bulletedListNode(text: 'Why does the forest never cross the garden walls?'),
      bulletedListNode(text: 'What did it take from the innkeeper?'),
    ],
  ),
);
