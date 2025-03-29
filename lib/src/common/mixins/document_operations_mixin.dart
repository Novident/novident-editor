import 'package:novident_editor/src/document/node.dart';
import 'package:novident_editor/src/document/selection/document_selection.dart';
import 'package:novident_editor/src/document/selection/selection.dart';

mixin DocumentOperations {
  void replace(Node node);
  void insert(Node node, {Node? inNode, bool left = true});
  void insertAll(Iterable<Node> node, {Node? inNode, bool left = true});
  Node? remove(int index);
  void insertTextAtPosition(
    NodeSelection selection,
    String text, {
    Map<String, dynamic>? attrs,
  });
  void replaceText(DocumentSelection selection, String text);
  void deleteTextAtSelection(DocumentSelection selection);
  void formatText(DocumentSelection selection, Map<String, dynamic> attributes);
  void formatNode(int index, Map<String, dynamic> attributes);
  Node? queryNodeById(String id);
  Node? queryNodeByIndex(int index);
  Node? queryNodeByOffset(int offset);
  Iterable<Node> queryAllNodesInSelection(DocumentSelection selection);
  Node? queryNodeInSelection(DocumentSelection selection);
  String getSelectedText(DocumentSelection selection);
}
