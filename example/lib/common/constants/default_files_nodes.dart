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

import 'contents/readme_document.dart';

String _content(Document document) => jsonEncode(document.toJson());

/// A fresh default workspace: project structure + initial document
/// contents, built together so the node ids match the content map.
///
/// Every call builds NEW node instances — tests boot several workspaces
/// without disposing shared mutable node state.
({List<Node> nodes, Map<String, String> contents}) buildDefaultWorkspace() {
  final awakening = File(
    details: NodeDetails.withLevel(2),
    name: 'Awakening',
    createAt: DateTime.now(),
  );
  final darkWoods = File(
    details: NodeDetails.withLevel(2),
    name: 'Dark Woods',
    createAt: DateTime.now(),
  );
  final tavern = File(
    details: NodeDetails.withLevel(2),
    name: 'The Tavern',
    createAt: DateTime.now(),
  );
  final readme = File(
    details: NodeDetails.withLevel(1),
    name: 'README',
    createAt: DateTime.now(),
  );
  final elara = File(
    details: NodeDetails.withLevel(1),
    name: 'Elara',
    createAt: DateTime.now(),
  );
  final hollowForest = File(
    details: NodeDetails.withLevel(1),
    name: 'The Hollow Forest',
    createAt: DateTime.now(),
  );

  // Keep this file structure-only: every document's content lives in its
  // own file under `constants/contents/` and is delivered through the
  // contents map below — the nodes themselves carry no content.
  //
  // Note: `Research` must stay at root index `1` — the desktop view
  // selects the README on startup through `root.atPath([1, 0])`.
  final nodes = <Node>[
    Directory(
      details: NodeDetails.zero(),
      name: 'Manuscript',
      createAt: DateTime.now(),
      children: [
        Directory(
          details: NodeDetails(level: 1),
          name: 'Chapter 1',
          createAt: DateTime.now(),
          children: [awakening, darkWoods],
        ),
        Directory(
          details: NodeDetails(level: 1),
          name: 'Chapter 2',
          createAt: DateTime.now(),
          children: [tavern],
        ),
      ],
    ),
    Directory(
      details: NodeDetails.withLevel(0),
      name: 'Research',
      createAt: DateTime.now(),
      children: [readme],
    ),
    Directory(
      details: NodeDetails.withLevel(0),
      name: 'Characters',
      createAt: DateTime.now(),
      children: [elara],
    ),
    Directory(
      details: NodeDetails.withLevel(0),
      name: 'Places',
      createAt: DateTime.now(),
      children: [hollowForest],
    ),
  ];

  final contents = <String, String>{
    awakening.id: _content(awakeningDocument),
    darkWoods.id: _content(darkWoodsDocument),
    tavern.id: _content(tavernDocument),
    elara.id: _content(characterElaraDocument),
    hollowForest.id: _content(placeHollowForestDocument),
    readme.id: _content(readmeDocument),
  };

  return (nodes: nodes, contents: contents);
}
