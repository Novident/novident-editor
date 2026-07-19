import 'package:novident_editor/novident_editor.dart';

abstract class NodeParser {
  const NodeParser();

  String get id;
  String transform(Node node, DocumentMarkdownEncoder? encoder);
}
