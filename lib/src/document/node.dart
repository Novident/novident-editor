import 'dart:collection';

import 'package:flutter/material.dart';
import 'package:meta/meta.dart';
import 'package:novident_editor/src/common/nano_id_gen.dart';
import 'package:novident_editor/src/document/delta/delta.dart';

final class Node extends ChangeNotifier with LinkedListEntry<Node> {
  // params
  final String id;
  final String type;
  Map<String, dynamic> data;

  Node({
    String? id,
    required this.type,
    required this.data,
  }) : id = id ?? nanoid();

  // internal values

  final GlobalKey key = GlobalKey();
  final LayerLink layerLink = LayerLink();

  /// this is the cached index of the node
  int? _nodeIndex;

  @internal
  void clearIndex() {
    _nodeIndex = null;
  }

  void updateText(Delta delta) {
    if (delta == data['text']) return;
    data['text'] = delta;
    notify();
  }

  void updateBlockAttributes(Delta delta) {
    notify();
  }

  void notify() {
    notifyListeners();
  }

  int get index => _nodeIndex ??= _computeNodeIndex();

  int _computeNodeIndex() {
    if (list == null || list!.isEmpty) return -1;
    int baseIndex = 0;

    for (final Node node in list!) {
      if (node.id == id) {
        return baseIndex;
      }
      baseIndex++;
    }

    return -1;
  }

  Map<String, dynamic> toJson() {
    return <String, dynamic>{
      'id': id,
      'type': type,
      'data': <String, dynamic>{
        ...data,
      },
    };
  }
}
