import 'dart:collection';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:meta/meta.dart';
import 'package:novident_editor/src/common/nano_id_gen.dart';
import 'package:novident_editor/src/document/delta/delta.dart';
import 'package:novident_editor/src/document/utils/compose_maps.dart';
import 'package:quiver/core.dart';

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
  int? _length;

  @internal
  void invalidateLength() {
    _length = null;
  }

  void updateText(Delta delta) {
    if (delta == data['text']) return;
    data['text'] = delta;
    invalidateLength();
    notify();
  }

  void updateData(Map<String, dynamic> data) {
    if (data.containsKey('text')) {
      invalidateLength();
    }
    this.data = composeAttributes(
          this.data,
          data,
        ) ??
        <String, dynamic>{};
    notify();
  }

  void notify() {
    notifyListeners();
  }

  @override
  void unlink() {
    if (list != null) {
      super.unlink();
    }
  }

  int get index => _computeNodeIndex();

  int get length => _length ??= delta?.textLength ?? 0;

  Delta? get delta => data['text'] as Delta?;

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
        if (data.containsKey('text')) 'text': (data['text'] as Delta?)?.toJson(),
      },
    };
  }

  @override
  String toString() {
    return '$type($id, $data)';
  }

  @override
  bool operator ==(covariant Node other) {
    return id == other.id &&
        type == other.type &&
        mapEquals(
          data,
          other.data,
        );
  }

  @override
  int get hashCode => hash3(type, id, data);
}
