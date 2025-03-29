import 'dart:collection';

import 'package:flutter/material.dart';
import 'package:novident_editor/src/document/node.dart';

class Root extends ChangeNotifier {
  final LinkedList<Node> nodes;

  Root({
    required List<Node> nodes,
  }) : nodes = LinkedList<Node>()..addAll(nodes);

  Root.empty() : nodes = LinkedList<Node>();
}
