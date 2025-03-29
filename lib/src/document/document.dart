import 'package:novident_editor/src/document/node.dart';
import 'package:novident_editor/src/document/root.dart';

class Document {
  final Root root;

  Document({
    required List<Node> nodes,
  }) : root = Root(nodes: nodes);

  Document.empty() : root = Root(nodes: []);
}
