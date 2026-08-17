import 'delta/text_delta.dart';
import 'node.dart';

/// A single delta mutation captured by a transaction.
///
/// Offsets are UTF-16 code units in the coordinates of the node's text
/// **at the moment the change was made** (i.e. after any previous change of
/// the same batch). [previousShift] is the accumulated [shift] of earlier
/// changes to the same node in the batch — it allows translating the
/// offsets back to the text before the batch.
class DeltaChange {
  const DeltaChange({
    required this.delta,
    required this.start,
    required this.end,
    required this.shift,
    required this.previousShift,
    required this.order,
  });

  /// The net change delta (retain + insert/delete/format).
  final Delta delta;

  /// First affected offset (inclusive).
  final int start;

  /// Last affected offset (exclusive, pre-change coordinates).
  final int end;

  /// Net length change: +inserted − deleted.
  final int shift;

  /// Accumulated shift of previous changes to the same node in the batch.
  final int previousShift;

  /// Monotonic global order (issued by [Document.nextDeltaChangeOrder]).
  final int order;

  @override
  String toString() =>
      'DeltaChange($start..$end, shift: $shift, prev: $previousShift, '
      'order: $order)';
}

/// An immutable delta-change notification emitted by [Document.emitChanges].
///
/// [changes] is empty when the change came without local metadata (remote
/// updates, full-text replacements) — consumers must then decide whether to
/// review the node entirely (e.g. via the ephemeral `required_revision` flag
/// in `node.extraInfos`).
class DeltaChangeEvent {
  const DeltaChangeEvent(this.node, this.changes);

  final Node node;
  final List<DeltaChange> changes;
}
