import 'package:flutter/material.dart';
import 'package:quiver/core.dart';

class NodeSelection {
  final TextSelection selection;
  final String nodeId;

  NodeSelection({
    required this.selection,
    required this.nodeId,
  });

  NodeSelection.collapsed({
    required this.nodeId,
    int offset = 0,
  }) : selection = TextSelection.collapsed(offset: offset);

  @override
  bool operator ==(covariant NodeSelection other) {
    return selection == other.selection && nodeId == other.nodeId;
  }

  @override
  int get hashCode => hash2(selection, nodeId);
}
