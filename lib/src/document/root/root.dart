import 'dart:collection';

import 'package:flutter/material.dart';
import 'package:meta/meta.dart';
import 'package:novident_editor/src/document/node.dart';
import 'package:novident_editor/src/document/utils/compose_maps.dart';

class Root extends ChangeNotifier {
  final LinkedList<Node> _nodes;

  Root({
    required List<Node> nodes,
  }) : _nodes = LinkedList<Node>()..addAll(nodes);

  Root.empty() : _nodes = LinkedList<Node>();

  int get length => _nodes.length;

  @internal
  LinkedList<Node> get nodes => _nodes;

  List<Node> get children => _nodes.toList();

  Node elementAt(int index) {
    return _nodes.elementAt(index);
  }

  Node? elementAtOrNull(int index) {
    return _nodes.elementAtOrNull(index);
  }

  bool remove(Node node) {
    return _nodes.remove(node);
  }

  void insertNode(Node node) {
    _nodes.add(node);
  }

  void updateNode(int index, Map<String, dynamic> data, {String? id}) {
    final node = _nodes.elementAtOrNull(index);
    if (node == null && id != null) {
      for (final node in _nodes) {
        if (node.id == id) {
          node.updateData(
            composeAttributes(node.data, data)!,
          );
          break;
        }
      }
      return;
    }
    node?.updateData(composeAttributes(node.data, data)!);
  }

  void removeNode(Node node) {
    _nodes.remove(node);
  }

  @override
  String toString() {
    return 'Root(nodes: $_nodes)';
  }
}
