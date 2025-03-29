import 'package:flutter/cupertino.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:novident_editor/src/document/delta/delta.dart';
import 'package:novident_editor/src/document/document.dart';
import 'package:novident_editor/src/document/node.dart';
import 'package:novident_editor/src/document/selection/document_selection.dart';
import 'package:novident_editor/src/document/selection/selection.dart';
import 'package:novident_editor/src/editor/plugins/standard/paragraph_component.dart';

void main() {
  Document? document;

  setUp((){
    document = Document.empty();
  });

  group('Simple queries', () {
    test('should get all nodes in selection', () {
      final Node startNode = paragraphNode(delta: Delta()..insert('Start paragraph'));
      final Node middleNode = paragraphNode(delta: Delta()..insert('"Middle node   "'));
      final Node middle2Node = paragraphNode(
          delta: Delta()..insert('And this is another middle paragraph Middle node'));
      final Node endNode = paragraphNode(delta: Delta()..insert('End Node'));
      document!.insertAll([startNode, middleNode, middle2Node, endNode]);

      final DocumentSelection selection = DocumentSelection(
        start: NodeSelection(
          selection: TextPosition(offset: 37),
          nodeId: middle2Node.id,
          nodeIndex: middle2Node.index,
        ),
        end: NodeSelection(
            selection: TextPosition(offset: 5),
            nodeId: startNode.id,
            nodeIndex: startNode.index),
      );

      final Iterable<Node> nodes = document!.queryAllNodesInSelection(selection);

      expect(nodes, <Node>[
        startNode,
        middleNode,
        middle2Node,
      ]);
      expect(
        document!.getSelectedText(selection),
        ' paragraph\n"Middle node   "\nAnd ',
      );
    });

    test('shouldn\'t get nothing when the selection\'s not valid', () {
      final Node startNode = paragraphNode(delta: Delta()..insert('Start paragraph'));
      final Node middleNode = paragraphNode(delta: Delta()..insert('"Middle node   "'));
      final Node middle2Node = paragraphNode(
          delta: Delta()..insert('And this is another middle paragraph Middle node'));
      final Node endNode = paragraphNode(delta: Delta()..insert('End Node'));
      document!.insertAll(<Node>[startNode, middleNode, middle2Node, endNode]);

      final DocumentSelection selection = DocumentSelection.invalid();

      final Iterable<Node> nodes = document!.queryAllNodesInSelection(selection);

      expect(nodes, <Node>[]);
    });
  });
}
