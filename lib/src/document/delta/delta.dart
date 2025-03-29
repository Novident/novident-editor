import 'dart:math' as math;

import 'package:collection/collection.dart';
import 'package:flutter/services.dart';
import 'package:meta/meta.dart';
import 'package:novident_editor/src/document/delta/iterator/delta_iterator.dart';
import 'package:novident_editor/src/document/operations/operation.dart';
import 'package:quiver/core.dart';

/// Delta represents a document or a modification of a document as a sequence of
/// insert, delete and retain operations.
///
/// Delta consisting of only "insert" operations is usually referred to as
/// "document delta". When delta includes also "retain" or "delete" operations
/// it is a "change delta".
class Delta {
  /// Creates new empty [Delta].
  factory Delta() => Delta._(<Operation>[]);

  Delta._(this.operations);

  /// Creates new [Delta] from [other].
  factory Delta.from(Delta other) => Delta._(List<Operation>.from(other.operations));

  /// Creates new [Delta] from a List of Operation
  factory Delta.fromOperations(List<Operation> operations) =>
      Delta._(operations.toList());

  // Placeholder char for embed in diff()
  // ignore: unused_field
  static final String _kDefaultEmbedCharacter = String.fromCharCode(0);

  String? _cachePlainText;

  @internal
  void invalidateCache() {
    _cachePlainText = null;
  }

  String toPlainText() {
    return _cachePlainText ??= map(
      (Operation op) => op.data is! String ? _kDefaultEmbedCharacter : op.data as String,
    ).join();
  }

  /// This method will return the position of the previous rune.
  ///
  /// Since the encoding of the [String] in Dart is UTF-16.
  /// If you want to find the previous character of a position,
  /// you can't just use the `position - 1` simply.
  ///
  /// This method can help you to compute the position of the previous character.
  int prevRunePosition(int pos) {
    if (pos == 0) {
      return pos - 1;
    }
    final content = toPlainText();
    final boundary = CharacterBoundary(content);
    final index = boundary.getLeadingTextBoundaryAt(pos - 1);
    return index ?? 0;
  }

  /// This method will return the position of the next rune.
  ///
  /// Since the encoding of the [String] in Dart is UTF-16.
  /// If you want to find the next character of a position,
  /// you can't just use the `position + 1` simply.
  ///
  /// This method can help you to compute the position of the next character.
  int nextRunePosition(int pos) {
    final content = toPlainText();
    if (pos >= content.length - 1) {
      return content.length;
    }
    final boundary = CharacterBoundary(content);
    final index = boundary.getTrailingTextBoundaryAt(pos);
    return index ?? content.length;
  }

  /// Transforms two attribute sets.
  static Map<String, dynamic>? transformAttributes(
      Map<String, dynamic>? a, Map<String, dynamic>? b, bool priority) {
    if (a == null) return b;
    if (b == null) return null;

    if (!priority) return b;

    final result = b.keys.fold<Map<String, dynamic>>({}, (attributes, key) {
      if (!a.containsKey(key)) attributes[key] = b[key];
      return attributes;
    });

    return result.isEmpty ? null : result;
  }

  /// Composes two attribute sets.
  static Map<String, dynamic>? composeAttributes(
      Map<String, dynamic>? a, Map<String, dynamic>? b,
      {bool keepNull = false}) {
    a ??= const {};
    b ??= const {};

    final result = Map<String, dynamic>.from(a)..addAll(b);
    final keys = result.keys.toList(growable: false);

    if (!keepNull) {
      for (final key in keys) {
        if (result[key] == null) result.remove(key);
      }
    }

    return result.isEmpty ? null : result;
  }

  ///get anti-attr result base on base
  static Map<String, dynamic> invertAttributes(
      Map<String, dynamic>? attr, Map<String, dynamic>? base) {
    attr ??= const {};
    base ??= const {};

    final baseInverted = base.keys.fold({}, (dynamic memo, key) {
      if (base![key] != attr![key] && attr.containsKey(key)) {
        memo[key] = base[key];
      }
      return memo;
    });

    final inverted = Map<String, dynamic>.from(attr.keys.fold(baseInverted, (memo, key) {
      if (base![key] != attr![key] && !base.containsKey(key)) {
        memo[key] = null;
      }
      return memo;
    }));
    return inverted;
  }

  /// Returns diff between two attribute sets
  static Map<String, dynamic>? diffAttributes(
      Map<String, dynamic>? a, Map<String, dynamic>? b) {
    a ??= const {};
    b ??= const {};

    final attributes = <String, dynamic>{};
    for (final key in (a.keys.toList()..addAll(b.keys))) {
      if (a[key] != b[key]) {
        attributes[key] = b.containsKey(key) ? b[key] : null;
      }
    }

    return attributes.keys.isNotEmpty ? attributes : null;
  }

  final List<Operation> operations;

  int modificationCount = 0;

  /// Creates [Delta] from de-serialized JSON representation.
  ///
  /// If `dataDecoder` parameter is not null then it is used to additionally
  /// decode the operation's data object. Only applied to insert operations.
  static Delta fromJson(List data, {DataDecoder? dataDecoder}) {
    return Delta._(
        data.map((op) => Operation.fromJson(op, dataDecoder: dataDecoder)).toList());
  }

  /// Returns list of operations in this delta.
  List<Operation> toList() => List.from(operations);

  /// Returns JSON-serializable version of this delta.
  List<Map<String, dynamic>> toJson() =>
      toList().map((operation) => operation.toJson()).toList();

  /// Returns `true` if this delta is empty.
  bool get isEmpty => operations.isEmpty;

  /// Returns `true` if this delta is not empty.
  bool get isNotEmpty => operations.isNotEmpty;

  /// Returns number of operations in this delta.
  int get length => operations.length;
  int get textLength => toPlainText().length;

  /// Returns [Operation] at specified [index] in this delta.
  Operation operator [](int index) => operations[index];

  /// Returns [Operation] at specified [index] in this delta.
  Operation elementAt(int index) => operations.elementAt(index);

  /// Returns the first [Operation] in this delta.
  Operation get first => operations.first;

  /// Returns the last [Operation] in this delta.
  Operation get last => operations.last;

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) return true;
    if (other is! Delta) return false;
    final typedOther = other;
    const comparator = ListEquality<Operation>(DefaultEquality<Operation>());
    return comparator.equals(operations, typedOther.operations);
  }

  @override
  int get hashCode => hashObjects(operations);

  /// Retain [count] of characters from current position.
  void retain(int count, [Map<String, dynamic>? attributes]) {
    assert(count >= 0);
    if (count == 0) return; // no-op
    push(Operation.retain(count, attributes));
  }

  /// Insert [data] at current position.
  void insert(dynamic data, [Map<String, dynamic>? attributes]) {
    if (data is String && data.isEmpty) return; // no-op
    push(Operation.insert(data, attributes));
  }

  /// Delete [count] characters from current position.
  void delete(int count) {
    assert(count >= 0);
    if (count == 0) return;
    push(Operation.delete(count));
  }

  void _mergeWithTail(Operation operation) {
    assert(isNotEmpty);
    assert(last.key == operation.key);
    assert(operation.data is String && last.data is String);

    final length = operation.length! + last.length!;
    final lastText = last.data as String;
    final opText = operation.data as String;
    final resultText = lastText + opText;
    final index = operations.length;
    operations.replaceRange(index - 1, index, [
      Operation(operation.key, length, resultText, operation.attributes),
    ]);
  }

  /// Pushes new operation into this delta.
  ///
  /// Performs compaction by composing [operation] with current tail operation
  /// of this delta, when possible. For instance, if current tail is
  /// `insert('abc')` and pushed operation is `insert('123')` then existing
  /// tail is replaced with `insert('abc123')` - a compound result of the two
  /// operations.
  void push(Operation operation) {
    if (operation.isEmpty) return;

    var index = operations.length;
    final lastOp = operations.isNotEmpty ? operations.last : null;
    if (lastOp != null) {
      if (lastOp.isDelete && operation.isDelete) {
        _mergeWithTail(operation);
        return;
      }

      if (lastOp.isDelete && operation.isInsert) {
        index -= 1; // Always insert before deleting
        final nLastOp = (index > 0) ? operations.elementAt(index - 1) : null;
        if (nLastOp == null) {
          operations.insert(0, operation);
          return;
        }
      }

      if (lastOp.isInsert && operation.isInsert) {
        if (lastOp.hasSameAttributes(operation) &&
            operation.data is String &&
            lastOp.data is String) {
          _mergeWithTail(operation);
          return;
        }
      }

      if (lastOp.isRetain && operation.isRetain) {
        if (lastOp.hasSameAttributes(operation)) {
          _mergeWithTail(operation);
          return;
        }
      }
    }
    if (index == operations.length) {
      operations.add(operation);
    } else {
      final opAtIndex = operations.elementAt(index);
      operations.replaceRange(index, index + 1, [operation, opAtIndex]);
    }
    modificationCount++;
  }

  /// Composes next operation from [thisIter] and [otherIter].
  ///
  /// Returns new operation or `null` if operations from [thisIter] and
  /// [otherIter] nullify each other. For instance, for the pair `insert('abc')`
  /// and `delete(3)` composition result would be empty string.
  Operation? _composeOperation(DeltaIterator thisIter, DeltaIterator otherIter) {
    if (otherIter.isNextInsert) return otherIter.next();
    if (thisIter.isNextDelete) return thisIter.next();

    final length = math.min(thisIter.peekLength(), otherIter.peekLength());
    final thisOp = thisIter.next(length);
    final otherOp = otherIter.next(length);
    assert(thisOp.length == otherOp.length);

    if (otherOp.isRetain) {
      final attributes = composeAttributes(
        thisOp.attributes,
        otherOp.attributes,
        keepNull: thisOp.isRetain,
      );
      if (thisOp.isRetain) {
        return Operation.retain(thisOp.length, attributes);
      } else if (thisOp.isInsert) {
        return Operation.insert(thisOp.data, attributes);
      } else {
        throw StateError('Unreachable');
      }
    } else {
      // otherOp == delete && thisOp in [retain, insert]
      assert(otherOp.isDelete);
      if (thisOp.isRetain) return otherOp;
      assert(thisOp.isInsert);
      // otherOp(delete) + thisOp(insert) => null
    }
    return null;
  }

  /// Composes this delta with [other] and returns new [Delta].
  ///
  /// It is not required for this and [other] delta to represent a document
  /// delta (consisting only of insert operations).
  Delta compose(Delta other) {
    final result = Delta();
    final thisIter = DeltaIterator(this);
    final otherIter = DeltaIterator(other);

    while (thisIter.hasNext || otherIter.hasNext) {
      final newOp = _composeOperation(thisIter, otherIter);
      if (newOp != null) result.push(newOp);
    }
    return result..trim();
  }

  /// Returns a new lazy Iterable with elements that are created by calling
  /// f on each element of this Iterable in iteration order.
  ///
  /// Convenience method
  Iterable<T> map<T>(T Function(Operation) f) {
    return operations.map<T>(f);
  }

  /// Transforms next operation from [otherIter] against next operation in
  /// [thisIter].
  ///
  /// Returns `null` if both operations nullify each other.
  Operation? _transformOperation(
      DeltaIterator thisIter, DeltaIterator otherIter, bool priority) {
    if (thisIter.isNextInsert && (priority || !otherIter.isNextInsert)) {
      return Operation.retain(thisIter.next().length);
    } else if (otherIter.isNextInsert) {
      return otherIter.next();
    }

    final length = math.min(thisIter.peekLength(), otherIter.peekLength());
    final thisOp = thisIter.next(length);
    final otherOp = otherIter.next(length);
    assert(thisOp.length == otherOp.length);

    // At this point only delete and retain operations are possible.
    if (thisOp.isDelete) {
      // otherOp is either delete or retain, so they nullify each other.
      return null;
    } else if (otherOp.isDelete) {
      return otherOp;
    } else {
      // Retain otherOp which is either retain or insert.
      return Operation.retain(
        length,
        transformAttributes(thisOp.attributes, otherOp.attributes, priority),
      );
    }
  }

  /// Transforms [other] delta against operations in this delta.
  Delta transform(Delta other, bool priority) {
    final result = Delta();
    final thisIter = DeltaIterator(this);
    final otherIter = DeltaIterator(other);

    while (thisIter.hasNext || otherIter.hasNext) {
      final newOp = _transformOperation(thisIter, otherIter, priority);
      if (newOp != null) result.push(newOp);
    }
    return result..trim();
  }

  /// Removes trailing retain operation with empty attributes, if present.
  void trim() {
    if (isNotEmpty) {
      final last = operations.last;
      if (last.isRetain && last.isPlain) operations.removeLast();
    }
  }

  /// Removes trailing '\n'
  void _trimNewLine() {
    if (isNotEmpty) {
      final lastOp = operations.last;
      final lastOpData = lastOp.data;

      if (lastOpData is String && lastOpData.endsWith('\n')) {
        operations.removeLast();
        if (lastOpData.length > 1) {
          insert(lastOpData.substring(0, lastOpData.length - 1), lastOp.attributes);
        }
      }
    }
  }

  /// Concatenates [other] with this delta and returns the result.
  Delta concat(Delta other, {bool trimNewLine = false}) {
    final result = Delta.from(this);
    if (trimNewLine) {
      result._trimNewLine();
    }
    if (other.isNotEmpty) {
      // In case first operation of other can be merged with last operation in
      // our list.
      result.push(other.operations.first);
      result.operations.addAll(other.operations.sublist(1));
    }
    return result;
  }

  /// Inverts this delta against [base].
  ///
  /// Returns new delta which negates effect of this delta when applied to
  /// [base]. This is an equivalent of "undo" operation on deltas.
  Delta invert(Delta base) {
    final inverted = Delta();
    if (base.isEmpty) return inverted;

    var baseIndex = 0;
    for (final op in operations) {
      if (op.isInsert) {
        inverted.delete(op.length!);
      } else if (op.isRetain && op.isPlain) {
        inverted.retain(op.length!);
        baseIndex += op.length!;
      } else if (op.isDelete || (op.isRetain && op.isNotPlain)) {
        final length = op.length!;
        final sliceDelta = base.slice(baseIndex, baseIndex + length);
        sliceDelta.toList().forEach((baseOp) {
          if (op.isDelete) {
            inverted.push(baseOp);
          } else if (op.isRetain && op.isNotPlain) {
            final invertAttr = invertAttributes(op.attributes, baseOp.attributes);
            inverted.retain(baseOp.length!, invertAttr.isEmpty ? null : invertAttr);
          }
        });
        baseIndex += length;
      } else {
        throw StateError('Unreachable');
      }
    }
    inverted.trim();
    return inverted;
  }

  /// Returns slice of this delta from [start] index (inclusive) to [end]
  /// (exclusive).
  Delta slice(int start, [int? end]) {
    final Delta delta = Delta();
    int index = 0;
    final DeltaIterator opIterator = DeltaIterator(this);

    final int actualEnd = end ?? DeltaIterator.maxLength;

    while (index < actualEnd && opIterator.hasNext) {
      Operation op;
      if (index < start) {
        op = opIterator.next(start - index);
      } else {
        op = opIterator.next(actualEnd - index);
        delta.push(op);
      }
      index += op.length!;
    }
    return delta;
  }

  /// This method joins two Delta together.
  Delta operator +(Delta other) {
    if (other.operations.isNotEmpty) {
      operations.add(other.operations[0]);
      operations.addAll(other.operations.sublist(1));
    }
    return Delta.fromOperations(operations);
  }

  /// Transforms [index] against this delta.
  ///
  /// Any "delete" operation before specified [index] shifts it backward, as
  /// well as any "insert" operation shifts it forward.
  ///
  /// The [force] argument is used to resolve scenarios when there is an
  /// insert operation at the same position as [index]. If [force] is set to
  /// `true` (default) then position is forced to shift forward, otherwise
  /// position stays at the same index. In other words setting [force] to
  /// `false` gives higher priority to the transformed position.
  ///
  /// Useful to adjust caret or selection positions.
  int transformPosition(int index, {bool force = true}) {
    final iter = DeltaIterator(this);
    var offset = 0;
    while (iter.hasNext && offset <= index) {
      final op = iter.next();
      if (op.isDelete) {
        index -= math.min(op.length!, index - offset);
        continue;
      } else if (op.isInsert && (offset < index || force)) {
        index += op.length!;
      }
      offset += op.length!;
    }
    return index;
  }

  @override
  String toString() => operations.join('\n');
}
