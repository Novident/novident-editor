import 'dart:io';

import 'package:novident_editor/src/common/mixins/document_operations_mixin.dart';
import 'package:novident_editor/src/document/node.dart';
import 'package:novident_editor/src/document/root/root.dart';
import 'package:novident_editor/src/document/selection/document_selection.dart';
import 'package:novident_editor/src/document/selection/selection.dart';

class Document implements DocumentOperations {
  final Root root;

  Document({
    required List<Node> nodes,
  }) : root = Root(nodes: nodes);

  Document.empty() : root = Root(nodes: <Node>[]);

  @override
  void deleteTextAtSelection(DocumentSelection selection) {
    final Iterable<Node> nodes = queryAllNodesInSelection(
      selection,
    );
  }

  @override
  void formatNode(int index, Map<String, dynamic> attributes) {}

  @override
  void formatText(DocumentSelection selection, Map<String, dynamic> attributes) {}

  @override
  void insert(Node node, {Node? inNode, bool left = true}) {
    node.unlink();
    if (inNode == null) {
      root.insertNode(node);
      return;
    }
    if (left) {
      inNode.insertBefore(node);
      return;
    }
    inNode.insertAfter(node);
  }

  @override
  void insertAll(Iterable<Node> nodes, {Node? inNode, bool left = true}) {
    for (final Node child in nodes) {
      child.unlink();
      insert(child, inNode: inNode, left: left);
    }
  }

  @override
  void insertTextAtPosition(
    NodeSelection selection,
    String text, {
    Map<String, dynamic>? attrs,
  }) {}

  @override
  Node? remove(int index) {
    if (index < 0 || index > root.length) {
      return null;
    }
    final Node node = root.elementAt(index);
    final bool removed = root.remove(node);
    if (!removed) return null;
    return node;
  }

  @override
  void replace(Node node) {}

  @override
  void replaceText(DocumentSelection selection, String text) {}

  @override
  Node? queryNodeInSelection(DocumentSelection selection) {
    if(!selection.isSingle || !selection.isCollapsed || selection.isInvalid) return null;
    final DocumentSelection normalized = selection.normalized;
    Node? start = queryNodeByIndex(normalized.start.nodeIndex);
    void ensureThatIsNotNull(Node? node, String nodeId) {
      if (node == null || node.id != nodeId) {
        node = queryNodeById(nodeId)!;
      }
    }

    ensureThatIsNotNull(start, normalized.start.nodeId);
    return start;
  }

  @override
  Iterable<Node> queryAllNodesInSelection(DocumentSelection selection) {
    if(selection.isInvalid) return <Node>[];
    final DocumentSelection normalized = selection.normalized;
    Node? start = queryNodeByIndex(normalized.start.nodeIndex);
    Node? end = queryNodeByIndex(normalized.end.nodeIndex);
    void ensureThatIsNotNull(Node? node, String nodeId) {
      if (node == null || node.id != nodeId) {
        node = queryNodeById(nodeId)!;
      }
    }

    ensureThatIsNotNull(start, normalized.start.nodeId);

    if (normalized.isCollapsed || normalized.isSingle) {
      return <Node>[start!];
    }

    ensureThatIsNotNull(end, normalized.end.nodeId);

    final List<Node> result = <Node>[start!];

    Node? nextNode = start.next;
    while (nextNode != end) {
      result.add(nextNode!);
      nextNode = nextNode.next;
    }

    result.add(end!);
    return <Node>[...result];
  }

  @override
  String getSelectedText(DocumentSelection selection) {
    if(selection.isCollapsed || selection.isSingle) {
      final DocumentSelection normalized = selection.normalized; 
    }
    final Iterable<Node> nodes = queryAllNodesInSelection(selection);
    if (nodes.isEmpty) return '';
    StringBuffer buffer = StringBuffer();
    for (final Node node in nodes) {
      if (node.delta != null) {
        buffer.writeln(
          node.delta!.toPlainText(),
        );
      }
    }
    return buffer.toString().substring(selection.startIndex, selection.endIndex);
  }

  @override
  Node? queryNodeByIndex(int index) {
    return root.elementAtOrNull(index);
  }

  @override
  Node? queryNodeById(String id) {
    for (final child in root.children) {}
    return null;
  }

  @override
  Node? queryNodeByOffset(int offset) {
    throw UnimplementedError();
  }
}
