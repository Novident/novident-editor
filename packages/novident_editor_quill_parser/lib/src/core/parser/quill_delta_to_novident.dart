import 'package:dart_quill_delta/dart_quill_delta.dart' as quill;
import 'package:flutter_quill_delta_easy_parser/flutter_quill_delta_easy_parser.dart'
    as easy;
import 'package:novident_editor_core/novident_editor_core.dart';
import 'package:novident_editor_document/novident_editor_document.dart'
    hide Delta;

import 'package:novident_editor_quill_parser/src/utils/quill_rich_text_keys.dart';

import '../quill_delta_to_node.dart';

/// Converts a Quill Delta into a novident [Document].
///
/// The delta is first parsed into an AST by
/// `flutter_quill_delta_easy_parser` (each block becomes a [easy.Paragraph]
/// whose [easy.Paragraph.blockAttributes] carry the Quill block formatting),
/// then each paragraph is converted into a novident [Node] by a
/// [QuillDeltaToNode]. This is the inverse of [QuillDeltaFromNovident].
class QuillDeltaToNovident {
  /// Creates a decoder with optional custom [embedConverters], keyed by the
  /// Quill embed key (the first key of an `insert` object, e.g. `image`),
  /// that take precedence over the built-in routing.
  QuillDeltaToNovident({
    Map<String, QuillDeltaToNode> embedConverters =
        const <String, QuillDeltaToNode>{},
  }) : _embedConverters = embedConverters;

  final Map<String, QuillDeltaToNode> _embedConverters;

  /// Returns the [QuillDeltaToNode] responsible for decoding [paragraph].
  ///
  /// Consults the [QuillDeltaToNovident] custom embed converters first, then
  /// falls back to the built-in routing. Override this method to fully
  /// customise resolution (for example to parse embeds or block attributes
  /// the built-ins don't know about); the default throws [UnsupportedError]
  /// for unknown embeds.
  ///
  /// ```dart
  /// class MyDecoder extends QuillDeltaToNovident {
  ///   @override
  ///   DeltaToNode converterFor(easy.Paragraph paragraph) {
  ///     if (paragraph.isEmbed) {
  ///       final embed = paragraph.lines.first.fragments.first.getEmbedValue();
  ///       if (embed.containsKey('my_custom_embed')) {
  ///         return MyCustomEmbedToNode();
  ///       }
  ///     }
  ///     return super.converterFor(paragraph);
  ///   }
  /// }
  /// ```
  QuillDeltaToNode converterFor(easy.Paragraph paragraph) {
    if (paragraph.isEmbed) {
      final embed = paragraph.lines.first.fragments.first.getEmbedValue();
      if (embed.isNotEmpty) {
        final custom = _embedConverters[embed.keys.first];
        if (custom != null) {
          return custom;
        }
      }
    }
    return QuillDeltaToNode.getExact(paragraph);
  }

  /// Converts a Quill [delta] into a novident [Document].
  Document parse(quill.Delta delta) {
    final parsed = easy.DocumentParser(
      // Each list item must remain its own paragraph; the default merger
      // would collapse adjacent blocks that share block attributes.
      mergerBuilder: const easy.NoMergeBuilder(),
    ).parseDelta(delta: delta);
    if (parsed == null) {
      return Document.blank();
    }

    // Top-level nodes are accumulated here and attached to the root in a
    // single [Node] constructor call. Building the tree with
    // `Node.insert` would trigger an O(n) sibling re-index per insertion
    // (see `novident_editor_document`), turning large flat documents into
    // O(n²). The constructor assigns each child index directly.
    final topLevel = <Node>[];
    final stack = <_OpenList>[];

    for (final paragraph in parsed.paragraphs) {
      final nodes = converterFor(paragraph).toNodes(paragraph);
      final isList =
          paragraph.blockAttributes?[QuillRichTextKeys.list] is String;

      if (!isList) {
        while (stack.isNotEmpty) {
          _closeOne(stack, topLevel);
        }
        topLevel.addAll(nodes);
        continue;
      }

      // Reconstruct the nested list tree from the flat `indent` levels.
      final indent =
          paragraph.blockAttributes?[QuillRichTextKeys.indent] as int? ?? 0;
      final node = nodes.first;

      while (stack.isNotEmpty && stack.last.indent >= indent) {
        _closeOne(stack, topLevel);
      }

      stack.add(
        _OpenList(
          indent,
          node.type,
          Map<String, dynamic>.from(node.attributes),
        ),
      );
    }

    while (stack.isNotEmpty) {
      _closeOne(stack, topLevel);
    }

    final root = Node(type: PageBlockKeys.type, children: topLevel);
    _trimTrailingEmptyParagraph(root);

    return Document(root: root);
  }

  /// Closes the top of [stack], materializing its node and attaching it to
  /// its parent (or to [topLevel] when it has none).
  void _closeOne(List<_OpenList> stack, List<Node> topLevel) {
    final closed = stack.removeLast();
    final node = closed.materialize();
    if (stack.isEmpty) {
      topLevel.add(node);
    } else {
      stack.last.children.add(node);
    }
  }

  /// Converts a Quill delta given as JSON (a list of operation maps) into a
  /// novident [Document].
  Document fromJson(List<dynamic> json) => parse(quill.Delta.fromJson(json));

  /// `flutter_quill_delta_easy_parser` emits a trailing empty paragraph for
  /// the document's terminating `\n`; novident has no such concept (the
  /// encoder never emits it), so strip it to keep the round-trip stable.
  void _trimTrailingEmptyParagraph(Node root) {
    while (root.children.isNotEmpty) {
      final last = root.children.last;
      if (!_isEmptyParagraph(last)) {
        break;
      }
      last.unlink();
    }
  }

  bool _isEmptyParagraph(Node node) {
    if (node.type != ParagraphBlockKeys.type) {
      return false;
    }
    final delta = node.delta;
    final isEmpty =
        delta == null || delta.isEmpty || delta.toPlainText().isEmpty;
    if (!isEmpty) {
      return false;
    }
    return !node.attributes.keys.any(
      (key) => key == blockComponentAlign || key == blockComponentTextDirection,
    );
  }
}

/// A list item being assembled while its nested children are still unknown.
///
/// The stack-based list reconstruction defers materializing a list node until
/// its subtree is complete, so children can be attached via the [Node]
/// constructor (O(1) per child) instead of `Node.insert` (O(n) re-index).
class _OpenList {
  _OpenList(this.indent, this.type, this.attributes);

  final int indent;
  final String type;
  final Map<String, dynamic> attributes;
  final List<Node> children = <Node>[];

  Node materialize() => Node(
        type: type,
        attributes: attributes,
        children: children,
      );
}
