import 'package:dart_quill_delta/dart_quill_delta.dart';
import 'package:novident_editor_core/novident_editor_core.dart';
import 'package:novident_editor_document/novident_editor_document.dart'
    hide Delta;

import 'parser/node_to_delta/node_to_quill.dart';

/// Converts a novident [Document] into its Quill Delta representation.
///
/// Quill stores a whole document as a single flat delta where each block is
/// terminated by a `\n` insert carrying the block's attributes. Novident
/// splits the same content into a tree of nodes (each holding its own
/// `delta`). This class walks that tree and emits the equivalent flat delta.
///
/// ```json
/// {
///   'document': {
///     'type': 'page',
///     'children': [
///       {
///         'type': 'paragraph',
///         'data': {
///           'delta': [
///             { 'insert': 'Welcome ' },
///             { 'insert': 'to ' },
///             { 'insert': 'Novident!' }
///           ]
///         }
///       }
///     ]
///   }
/// }
/// ```
///
/// Produces: `[{ 'insert': 'Welcome to Novident!' }, { 'insert': '\n' }]`.
class QuillDeltaFromNovident {
  /// Creates an encoder with optional custom [converters], keyed by node
  /// `type`, that take precedence over the built-in routing.
  QuillDeltaFromNovident({
    Map<String, NodeToQuill> converters = const <String, NodeToQuill>{},
  }) : _converters = converters;

  final Map<String, NodeToQuill> _converters;

  /// Returns the [NodeToQuill] responsible for encoding [node].
  ///
  /// Consults the [QuillDeltaFromNovident] custom converters first, then
  /// falls back to the built-in routing. Override this method to fully
  /// customise resolution (for example to handle custom block types without
  /// registering them up-front); the default throws [UnsupportedError] for
  /// block types neither side knows about.
  ///
  /// ```dart
  /// class MyEncoder extends QuillDeltaFromNovident {
  ///   @override
  ///   NodeToQuill converterFor(Node node) {
  ///     if (node.type == 'my_custom_block') {
  ///       return MyCustomBlockToDelta();
  ///     }
  ///     return super.converterFor(node);
  ///   }
  /// }
  /// ```
  NodeToQuill converterFor(Node node) =>
      _converters[node.type] ?? NodeToQuill.getExact(node);

  /// Converts a document encoded as JSON (the [Document.fromJson] shape)
  /// into its Quill Delta.
  Delta fromJson(Map<String, dynamic> json) {
    return fromDocument(Document.fromJson(json));
  }

  /// Converts a [Document] into its Quill Delta.
  Delta fromDocument(Document document) {
    return parsePage(document.root);
  }

  /// Converts a `page` node (the document root) into its Quill Delta.
  Delta parsePage(Node node) {
    assert(
      node.type == PageBlockKeys.type,
      'Expected a "page" node, got "${node.type}".',
    );
    return parse(node.children);
  }

  /// Converts an iterable of block [Node]s into a single Quill Delta.
  ///
  /// Runs in linear time and memory over the total number of operations. It
  /// deliberately builds the operation list with [Delta.fromOperations]
  /// instead of feeding `Delta.push`, whose tail-compaction performs a fresh
  /// full-length string copy on every consecutive plain-text merge — that
  /// turns a large flat document into O(n²) string allocation. Keeping text
  /// and its terminating `\n` as separate operations is also the idiomatic
  /// Quill form (block attributes attach to the newline).
  Delta parse(Iterable<Node> nodes) {
    final operations = <Operation>[];
    for (final node in nodes) {
      operations.addAll(converterFor(node).toQuill(node));
    }
    return Delta.fromOperations(operations);
  }
}
