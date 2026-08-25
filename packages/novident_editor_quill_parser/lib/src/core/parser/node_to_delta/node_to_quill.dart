import 'package:dart_quill_delta/dart_quill_delta.dart';
import 'package:novident_editor_core/novident_editor_core.dart';
import 'package:novident_editor_document/novident_editor_document.dart';
import 'package:novident_editor_quill_parser/src/utils/quill_rich_text_keys.dart';

import '../../../utils/extensions/text_insert_to_operation.dart';
import 'nodes.dart';

/// Converts a single novident block [Node] into its Quill Delta operations.
///
/// Quill represents a whole document as a flat list of operations in which
/// every block is terminated by a `\n` insert carrying the block's
/// formatting, while novident splits content into a tree of nodes (each with
/// its own `delta`). A [NodeToQuill] therefore emits the node's inline
/// operations followed by the terminating newline, with block attributes
/// attached to that newline.
abstract class NodeToQuill {
  const NodeToQuill();

  /// Returns the converter responsible for [node]'s block type.
  ///
  /// Throws an [UnsupportedError] for block types that have no Quill Delta
  /// representation (`table`, `table/cell`, `divider`, `columns`, `column`).
  factory NodeToQuill.getExact(Node node) {
    return switch (node.type) {
      ParagraphBlockKeys.type => ParagraphToDelta(),
      HeadingBlockKeys.type => HeadingToDelta(),
      QuoteBlockKeys.type => QuoteToDelta(),
      TodoListBlockKeys.type => TodoToDelta(),
      NumberedListBlockKeys.type => OrderedToDelta(),
      BulletedListBlockKeys.type => UnorderedToDelta(),
      ImageBlockKeys.type => ImageToDelta(),
      _ => throw UnsupportedError(
          'Unsupported node type "${node.type}" for Quill delta encoding.',
        ),
    };
  }

  /// Whether [node] is a valid input for this converter.
  bool validate(Node node);

  /// Produces the Quill operations for [node].
  ///
  /// [extra] carries conversion context shared across a nested subtree
  /// (currently the running `indent` level of nested lists).
  List<Operation> toQuill(Node node, {Map<String, dynamic>? extra});

  /// The inline insert operations for [node]'s delta (text only, no embeds),
  /// with their attributes mapped to Quill keys.
  ///
  /// Empty inserts are skipped; an empty delta yields an empty list.
  List<Operation> buildInlineOperations(Node node) {
    final delta = node.delta;
    if (delta == null || delta.isEmpty) {
      return const <Operation>[];
    }
    return [
      for (final op in delta.operations)
        if (op is TextInsert && op.text.isNotEmpty) op.toQuillOperation,
    ];
  }

  /// Recursively converts [node]'s children as nested list items.
  ///
  /// [indent] is the Quill `indent` level of [node] itself (`null` for a
  /// top-level item); each child is encoded at `indent + 1`.
  List<Operation> buildNestedListOperations(Node node, int? indent) {
    return <Operation>[
      for (final child in node.children)
        ...NodeToQuill.getExact(child).toQuill(
          child,
          extra: {QuillRichTextKeys.indent: (indent ?? 0) + 1},
        ),
    ];
  }
}
