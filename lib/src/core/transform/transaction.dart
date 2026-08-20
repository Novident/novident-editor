import 'dart:math' as math;

import 'package:novident_editor/novident_editor.dart';

/// A [Transaction] has a list of [Operation] objects that will be applied
/// to the editor.
///
/// There will be several ways to consume the transaction:
/// 1. Apply to the state to update the UI.
/// 2. Send to the backend to store and do operation transforming.
class Transaction {
  Transaction({
    required this.document,
  });

  final Document document;

  /// The operations to be applied.
  final List<Operation> _operations = [];

  List<Operation> get operations {
    if (markNeedsComposing) {
      // compose the delta operations
      compose();
      markNeedsComposing = false;
    }
    return _operations;
  }

  set operations(List<Operation> value) {
    _operations.clear();
    _operations.addAll(value);
  }

  /// The selection to be applied.
  Selection? afterSelection;

  /// The before selection is to be recovered if needed.
  Selection? beforeSelection;

  /// The custom selection type is to be applied.
  SelectionType? customSelectionType;

  /// The custom selection reason is to be applied.
  SelectionUpdateReason? reason;

  Map? selectionExtraInfo;

  // mark needs to be composed
  bool markNeedsComposing = false;

  /// Deltas waiting to be composed, per node. Was a `static` in the text
  /// extension; now per-transaction so abandoned transactions can't leak
  /// state into later ones.
  final Map<Node, List<Delta>> _composeMap = {};

  /// Delta changes captured while building this transaction, per node.
  /// Consumed by the editor after the transaction is applied.
  final Map<Node, List<DeltaChange>> _deltaChanges = {};

  /// Delta changes captured by this transaction, per node.
  Map<Node, List<DeltaChange>> get deltaChanges => _deltaChanges;

  /// Clears the captured delta changes (called after they are emitted).
  void clearDeltaChanges() => _deltaChanges.clear();

  /// Inserts the [Node] at the given [Path].
  void insertNode(
    Path path,
    Node node, {
    bool deepCopy = true,
  }) {
    insertNodes(path, [node], deepCopy: deepCopy);
  }

  /// Inserts a sequence of [Node]s at the given [Path].
  void insertNodes(
    Path path,
    Iterable<Node> nodes, {
    bool deepCopy = true,
  }) {
    if (nodes.isEmpty) {
      return;
    }
    if (deepCopy) {
      // add `toList()` to prevent the redundant copy of the nodes when looping
      nodes = nodes.map((e) => e.copyWith()).toList();
    }
    add(
      InsertOperation(
        path,
        nodes,
      ),
    );
  }

  /// Updates the attributes of the [Node].
  ///
  /// The [attributes] will be merged into the existing attributes.
  void updateNode(Node node, Attributes attributes) {
    final inverted = invertAttributes(node.attributes, attributes);
    add(
      UpdateOperation(
        node.path,
        {...attributes},
        inverted,
      ),
    );
  }

  /// Deletes the [Node] in the document.
  void deleteNode(Node node) {
    deleteNodesAtPath(node.path);
    if (beforeSelection != null) {
      final nodePath = node.path;
      final selectionPath = beforeSelection!.start.path;
      if (!nodePath.equals(selectionPath)) {
        afterSelection = beforeSelection;
      }
    }
  }

  /// Deletes the [Node]s in the document.
  void deleteNodes(Iterable<Node> nodes) {
    nodes.forEach(deleteNode);
  }

  /// Deletes the [Node]s at the given [Path].
  ///
  /// The [length] indicates the number of consecutive deletions,
  ///   including the node of the current path.
  void deleteNodesAtPath(Path path, [int length = 1]) {
    if (path.isEmpty) return;
    final nodes = <Node>[];
    final parent = path.parent;
    for (var i = 0; i < length; i++) {
      final node = document.nodeAtPath(parent + [path.last + i]);
      if (node == null) {
        break;
      }
      nodes.add(node);
    }
    add(DeleteOperation(path, nodes));
  }

  /// Moves a [Node] to the provided [Path]
  void moveNode(Path path, Node node) {
    deleteNode(node);
    insertNode(path, node, deepCopy: false);
  }

  /// Returns the JSON representation of the transaction.
  Map<String, dynamic> toJson() {
    final json = <String, dynamic>{};
    if (operations.isNotEmpty) {
      json['operations'] = operations.map((o) => o.toJson()).toList();
    }
    if (afterSelection != null) {
      json['after_selection'] = afterSelection!.toJson();
    }
    if (beforeSelection != null) {
      json['before_selection'] = beforeSelection!.toJson();
    }
    return json;
  }

  /// Adds an operation to the transaction.
  /// This method will merge operations if they are both TextEdits.
  ///
  /// Also, this method will transform the path of the operations
  /// to avoid conflicts.
  void add(Operation operation, {bool transform = true}) {
    Operation? op = operation;
    final Operation? last = _operations.isEmpty ? null : _operations.last;
    if (last != null) {
      if (op is UpdateTextOperation &&
          last is UpdateTextOperation &&
          op.path.equals(last.path)) {
        final newOp = UpdateTextOperation(
          op.path,
          last.delta.compose(op.delta),
          op.inverted.compose(last.inverted),
        );
        operations[_operations.length - 1] = newOp;
        return;
      }
    }
    if (transform) {
      for (var i = 0; i < _operations.length; i++) {
        if (op == null) {
          continue;
        }
        op = transformOperation(_operations[i], op);
      }
    }
    if (op is UpdateTextOperation && op.delta.isEmpty) {
      return;
    }
    if (op == null) {
      return;
    }
    _operations.add(op);
  }
}

extension TextTransaction on Transaction {
  /// Inserts the [text] at the given [index].
  ///
  /// If the [attributes] is null, the attributes of the previous character will be used.
  /// If the [attributes] is not null, the attributes will be used.
  void insertText(
    Node node,
    int index,
    String text, {
    Attributes? attributes,
    Attributes? toggledAttributes,
    bool sliceAttributes = true,
  }) {
    final delta = node.delta;
    if (delta == null) {
      assert(false, 'The node must have a delta.');
      return;
    }

    if (index < 0 || index > delta.length) {
      NovidentEditorLog.editor
          .info('The index($index) is out of range or negative.');
      return;
    }

    final newAttributes = attributes ??
        (sliceAttributes ? delta.sliceAttributes(index) : {}) ??
        {};

    if (toggledAttributes != null) {
      newAttributes.addAll(toggledAttributes);
    }

    final insert = Delta()
      ..retain(index)
      ..insert(text, attributes: newAttributes);

    addDeltaToComposeMap(node, insert);

    afterSelection = Selection.collapsed(
      Position(path: node.path, offset: index + text.length),
    );
  }

  void insertTextDelta(
    Node node,
    int index,
    Delta insertedDelta,
  ) {
    final delta = node.delta;
    if (delta == null) {
      assert(false, 'The node must have a delta.');
      return;
    }

    assert(
      index <= delta.length && index >= 0,
      'The index($index) is out of range or negative.',
    );

    final insert = Delta()
      ..retain(index)
      ..addAll(insertedDelta);

    addDeltaToComposeMap(node, insert);

    afterSelection = Selection.collapsed(
      Position(path: node.path, offset: index + insertedDelta.length),
    );
  }

  /// Deletes the [length] characters at the given [index].
  void deleteText(
    Node node,
    int index,
    int length,
  ) {
    final delta = node.delta;
    if (delta == null) {
      assert(false, 'The node must have a delta.');
      return;
    }

    assert(
      index + length <= delta.length && index >= 0 && length >= 0,
      'The index($index) or length($length) is out of range or negative.',
    );

    final delete = Delta()
      ..retain(index)
      ..delete(length);

    addDeltaToComposeMap(node, delete);

    afterSelection = Selection.collapsed(
      Position(path: node.path, offset: index),
    );
  }

  void mergeText(
    Node left,
    Node right, {
    int? leftOffset,
    int rightOffset = 0,
  }) {
    final leftDelta = left.delta;
    final rightDelta = right.delta;
    if (leftDelta == null || rightDelta == null) {
      return;
    }
    final leftLength = leftDelta.length;
    final rightLength = rightDelta.length;
    leftOffset ??= leftLength;

    final merge = Delta()
      ..retain(leftOffset)
      ..delete(leftLength - leftOffset)
      ..addAll(rightDelta.slice(rightOffset, rightLength));

    addDeltaToComposeMap(left, merge);

    afterSelection = Selection.collapsed(
      Position(
        path: left.path,
        offset: leftOffset,
      ),
    );
  }

  void formatText(
    Node node,
    int index,
    int length,
    Attributes attributes,
  ) {
    final delta = node.delta;
    if (delta == null) {
      return;
    }
    afterSelection = beforeSelection;

    final format = Delta()
      ..retain(index)
      ..retain(length, attributes: attributes);

    addDeltaToComposeMap(node, format);
  }

  /// replace the text at the given [index] with the [text].
  void replaceText(
    Node node,
    int index,
    int length,
    String text, {
    Attributes? attributes,
  }) {
    final delta = node.delta;
    if (delta == null) {
      return;
    }
    var newAttributes = attributes;
    if (attributes == null) {
      newAttributes = attributes ?? delta.sliceAttributes(index);

      if (newAttributes == null) {
        final slicedDelta = delta.slice(index, index + length);
        if (slicedDelta.isNotEmpty) {
          newAttributes = slicedDelta.first.attributes;
        }
      }
    }

    final replace = Delta()
      ..retain(index)
      ..delete(length)
      ..insert(text, attributes: {...newAttributes ?? {}});
    addDeltaToComposeMap(node, replace);

    afterSelection = Selection.collapsed(
      Position(
        path: node.path,
        offset: index + text.length,
      ),
    );
  }

  void replaceTexts(
    List<Node> nodes,
    Selection selection,
    List<String> texts,
  ) {
    if (nodes.isEmpty || texts.isEmpty) {
      return;
    }

    if (nodes.length == texts.length) {
      return replaceTextsWithEqualNodes(
        nodes,
        selection,
        texts,
      );
    }

    if (nodes.length > texts.length) {
      return replaceTextsWithMoreNodes(
        nodes,
        selection,
        texts,
      );
    }

    if (nodes.length < texts.length) {
      return replaceTextsWithLessNodes(
        nodes,
        selection,
        texts,
      );
    }
  }

  /// Compose the delta in the compose map.
  void compose() {
    if (_composeMap.isEmpty) {
      markNeedsComposing = false;
      return;
    }
    for (final entry in _composeMap.entries) {
      final node = entry.key;
      if (node.delta == null) {
        continue;
      }
      final deltaQueue = entry.value;
      final composed = deltaQueue.fold<Delta>(
        node.delta!,
        (p, e) => p.compose(e),
      );
      assert(composed.every((element) => element is TextInsert));
      updateNode(node, {
        blockComponentDelta: composed.toJson(),
      });
    }
    markNeedsComposing = false;
    _composeMap.clear();
  }

  void addDeltaToComposeMap(Node node, Delta delta) {
    markNeedsComposing = true;
    _composeMap.putIfAbsent(node, () => []).add(delta);

    // Capture the DeltaChange at the exact point where the index is known.
    final previousShift = _deltaChanges[node]
            ?.fold<int>(0, (sum, change) => sum + change.shift) ??
        0;
    final (start, end, shift) = _describeDeltaChange(delta);
    _deltaChanges.putIfAbsent(node, () => []).add(
          DeltaChange(
            delta: delta,
            start: start,
            end: end,
            shift: shift,
            previousShift: previousShift,
            order: document.nextDeltaChangeOrder(),
          ),
        );
  }

  /// Derives `(start, end, shift)` from a net change delta.
  ///
  /// Order-independent: [Delta] may reorder insert/delete operations, so
  /// offsets cannot be derived by walking the operations in sequence.
  ///
  /// - insert: start = end = insertion point, shift = +length
  /// - delete: start..end = deleted range, shift = −length
  /// - format (retain with attributes): start..end = formatted range
  /// - mixed (replace): start = first modification point, end = start +
  ///   deleted length
  static (int, int, int) _describeDeltaChange(Delta delta) {
    var shift = 0;
    var deleted = 0;
    var formatted = 0;
    var start = -1;
    var offset = 0;
    for (final op in delta) {
      if (op is TextInsert) {
        if (start < 0) {
          start = offset;
        }
        shift += op.length;
        offset += op.length;
      } else if (op is TextDelete) {
        if (start < 0) {
          start = offset;
        }
        deleted += op.length;
        offset += op.length;
      } else if (op is TextRetain) {
        final before = offset;
        offset += op.length;
        if (op.attributes != null) {
          if (start < 0) {
            start = before;
          }
          formatted = math.max(formatted, op.length);
        }
      }
    }
    if (start < 0) {
      start = 0;
    }
    shift -= deleted;
    final end = deleted > 0
        ? start + deleted
        : formatted > 0
            ? start + formatted
            : start;
    return (start, end, shift);
  }

  void replaceTextsWithEqualNodes(
    List<Node> nodes,
    Selection selection,
    List<String> texts,
  ) {
    if (nodes.length != texts.length) {
      return;
    }

    final length = nodes.length;

    if (length == 1) {
      replaceText(
        nodes.first,
        selection.startIndex,
        selection.endIndex - selection.startIndex,
        texts.first,
      );
      return;
    }

    for (var i = 0; i < nodes.length; i++) {
      final node = nodes[i];
      final delta = node.delta;
      if (delta == null) {
        continue;
      }
      if (i == 0) {
        replaceText(
          node,
          selection.startIndex,
          delta.length - selection.startIndex,
          texts.first,
        );
      } else if (i == length - 1) {
        replaceText(
          node,
          0,
          selection.endIndex,
          texts.last,
        );
      } else {
        replaceText(
          node,
          0,
          delta.toPlainText().length,
          texts[i],
        );
      }
    }

    final normalizedSelection = selection.normalized;
    final afterSelection = normalizedSelection.copyWith(
      end: normalizedSelection.end.copyWith(offset: texts.last.length),
    );
    this.afterSelection = afterSelection;

    return;
  }

  void replaceTextsWithMoreNodes(
    List<Node> nodes,
    Selection selection,
    List<String> texts,
  ) {
    if (nodes.length <= texts.length) {
      return;
    }

    final length = nodes.length;
    for (var i = 0; i < nodes.length; i++) {
      final node = nodes[i];
      final delta = node.delta;
      if (delta == null) {
        continue;
      }
      if (i == 0) {
        replaceText(
          node,
          selection.startIndex,
          delta.length - selection.startIndex,
          texts.first,
        );
      } else if (i == length - 1 && texts.length >= 2) {
        replaceText(
          node,
          0,
          selection.endIndex,
          texts.last,
        );
      } else if (i < texts.length - 1) {
        replaceText(
          node,
          0,
          delta.length,
          texts[i],
        );
      } else {
        deleteNode(node);
        if (i == nodes.length - 1) {
          final delta = nodes.last.delta?.slice(selection.end.offset);
          if (delta == null || delta.isEmpty) {
            continue;
          }
          final newDelta = Delta()
            ..insert(texts[0])
            ..addAll(delta);
          replaceText(
            node,
            selection.start.offset,
            texts[0].length,
            newDelta.toPlainText(),
          );
        }
      }
    }

    final normalizedSelection = selection.normalized;
    final afterSelection = normalizedSelection.copyWith(
      end: Position(
        path: normalizedSelection.end.path.previousNPath(
          nodes.length - texts.length,
        ),
        offset: texts.last.length,
      ),
    );
    this.afterSelection = afterSelection;
  }

  void replaceTextsWithLessNodes(
    List<Node> nodes,
    Selection selection,
    List<String> texts,
  ) {
    if (nodes.length >= texts.length) {
      return;
    }

    final length = texts.length;
    var path = nodes.first.path;

    for (var i = 0; i < texts.length; i++) {
      final text = texts[i];
      if (i == 0) {
        final node = nodes.first;
        final delta = node.delta;
        if (delta == null) {
          continue;
        }
        replaceText(
          nodes.first,
          selection.startIndex,
          delta.length - selection.startIndex,
          text,
        );
        path = path.next;
      } else if (i == length - 1 && nodes.length >= 2) {
        replaceText(
          nodes.last,
          0,
          selection.endIndex,
          text,
        );
        path = path.next;
      } else {
        if (i < nodes.length - 1) {
          final node = nodes[i];
          final delta = node.delta;
          if (delta == null) {
            continue;
          }
          replaceText(
            node,
            0,
            delta.length,
            text,
          );
          path = path.next;
        } else {
          if (i == texts.length - 1) {
            final delta = nodes.last.delta;
            if (delta == null) {
              continue;
            }
            final mewDelta = Delta()
              ..insert(text)
              ..addAll(
                delta.slice(selection.end.offset),
              );
            insertNode(
              path,
              paragraphNode(
                delta: mewDelta,
              ),
            );
          } else {
            insertNode(
              path,
              paragraphNode(
                delta: Delta()..insert(text),
              ),
            );
          }
        }
      }
    }

    final normalizedSelection = selection.normalized;
    final afterSelection = normalizedSelection.copyWith(
      end: Position(
        path: normalizedSelection.end.path.nextNPath(
          texts.length - nodes.length,
        ),
        offset: texts.last.length,
      ),
    );
    this.afterSelection = afterSelection;
  }
}
