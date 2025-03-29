import 'package:flutter/material.dart';
import 'package:quiver/core.dart';

class NodeSelection {
  final TextPosition selection;
  final String nodeId;
  final int nodeIndex;

  NodeSelection({
    required this.selection,
    required this.nodeId,
    required this.nodeIndex,
  });

  NodeSelection.invalid()
      : selection = TextPosition(offset: -1),
        nodeId = 'invalid',
        nodeIndex = -1;

  NodeSelection.collapsed({
    required this.nodeId,
    required this.nodeIndex,
    int offset = 0,
  }) : selection = TextPosition(offset: offset);

  int get offset => selection.offset;

  @override
  bool operator ==(covariant NodeSelection other) {
    return selection == other.selection &&
        nodeId == other.nodeId &&
        nodeIndex == other.nodeIndex;
  }

  @override
  int get hashCode => hash3(selection, nodeId, nodeIndex);

  @override
  String toString() => 'index -> $nodeId, offset -> $offset';

  NodeSelection copyWith({int? index, int? offset, String? nodeId}) {
    return NodeSelection(
      nodeIndex: index ?? nodeIndex,
      nodeId: nodeId ?? this.nodeId,
      selection: TextPosition(offset: offset ?? this.offset),
    );
  }

  Map<String, dynamic> toJson() {
    return <String, dynamic>{
      'index': nodeIndex,
      'offset': offset,
    };
  }
}
