import 'package:novident_editor/novident_editor.dart';

Node _field(String label, String value) => bulletedListNode(
      delta: Delta()
        ..insert(
          label,
          attributes: <String, dynamic>{NovidentRichTextKeys.bold: true},
        )
        ..insert(value),
    );

/// Content for `Characters ▸ Elara` (character sheet).
final Document characterElaraDocument = Document(
  root: pageNode(
    children: <Node>[
      headingNode(level: 2, text: 'Elara'),
      _field('Role: ', 'Protagonist'),
      _field('Age: ', '19'),
      _field('Home: ', 'Bryrmoor, last village before the Hollow Forest'),
      _field('Keepsake: ', 'Her grandmother\'s iron knife'),
      headingNode(level: 3, text: 'Overview'),
      paragraphNode(
        text: 'Raised by her grandmother after the forest "kept" her '
            'parents, Elara grew up on the warnings everyone else treats as '
            'superstition. She is practical, stubborn, and quietly convinced '
            'that the stories are instructions, not entertainment.',
      ),
      headingNode(level: 3, text: 'Voice notes'),
      paragraphNode(
        delta: Delta()
          ..insert(
            'Short sentences under pressure. Counts things when she is '
            'afraid — stones, steps, breaths.',
            attributes: <String, dynamic>{NovidentRichTextKeys.italic: true},
          ),
      ),
    ],
  ),
);
