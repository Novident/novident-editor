import 'dart:convert';

import 'package:example/common/constants/contents/chapter_one_awakening_content.dart';
import 'package:example/common/constants/contents/chapter_one_dark_woods_content.dart';
import 'package:example/common/constants/contents/chapter_two_tavern_content.dart';
import 'package:example/common/constants/contents/character_elara_content.dart';
import 'package:example/common/constants/contents/place_hollow_forest_content.dart';
import 'package:example/common/nodes/directory.dart';
import 'package:example/common/nodes/file.dart';
import 'package:novident_editor/novident_editor.dart' show Document;
import 'package:novident_nodes/novident_nodes.dart';

String _content(Document document) => jsonEncode(document.toJson());

// The File instances are shared between [defaultNodes] (structure) and
// [defaultDocumentContents] (node id → content): ids are generated at
// construction, so the content map must be built AFTER the nodes.
final File _awakening = File(
  details: NodeDetails.withLevel(2),
  name: 'Awakening',
  createAt: DateTime.now(),
);
final File _darkWoods = File(
  details: NodeDetails.withLevel(2),
  name: 'Dark Woods',
  createAt: DateTime.now(),
);
final File _tavern = File(
  details: NodeDetails.withLevel(2),
  name: 'The Tavern',
  createAt: DateTime.now(),
);
final File _readme = File(
  details: NodeDetails.withLevel(1),
  name: 'README',
  createAt: DateTime.now(),
);
final File _elara = File(
  details: NodeDetails.withLevel(1),
  name: 'Elara',
  createAt: DateTime.now(),
);
final File _hollowForest = File(
  details: NodeDetails.withLevel(1),
  name: 'The Hollow Forest',
  createAt: DateTime.now(),
);

/// Initial document contents, keyed by node id — feeds the
/// `DocumentContentStore` mounted above the MaterialApp.
///
/// Note: the README carries no initial content on purpose — it opens as
/// an empty document.
final Map<String, String> defaultDocumentContents = <String, String>{
  _awakening.id: _content(awakeningDocument),
  _darkWoods.id: _content(darkWoodsDocument),
  _tavern.id: _content(tavernDocument),
  _elara.id: _content(characterElaraDocument),
  _hollowForest.id: _content(placeHollowForestDocument),
};

/// Default project structure.
///
/// Keep this file structure-only: every document's content lives in its
/// own file under `constants/contents/` and is delivered through
/// [defaultDocumentContents] — the nodes themselves carry no content.
///
/// Note: `Research` must stay at root index `1` — the desktop view
/// selects the README on startup through `root.atPath([1, 0])`.
final List<Node> defaultNodes = <Node>[
  Directory(
    details: NodeDetails.zero(),
    name: 'Manuscript',
    createAt: DateTime.now(),
    children: [
      Directory(
        details: NodeDetails(level: 1),
        name: 'Chapter 1',
        createAt: DateTime.now(),
        children: [_awakening, _darkWoods],
      ),
      Directory(
        details: NodeDetails(level: 1),
        name: 'Chapter 2',
        createAt: DateTime.now(),
        children: [_tavern],
      ),
    ],
  ),
  Directory(
    details: NodeDetails.withLevel(0),
    name: 'Research',
    createAt: DateTime.now(),
    children: [_readme],
  ),
  Directory(
    details: NodeDetails.withLevel(0),
    name: 'Characters',
    createAt: DateTime.now(),
    children: [_elara],
  ),
  Directory(
    details: NodeDetails.withLevel(0),
    name: 'Places',
    createAt: DateTime.now(),
    children: [_hollowForest],
  ),
];
