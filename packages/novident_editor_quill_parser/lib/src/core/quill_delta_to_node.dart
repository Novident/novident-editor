import 'package:flutter_quill_delta_easy_parser/flutter_quill_delta_easy_parser.dart'
    hide Document;
import 'package:novident_editor_core/novident_editor_core.dart';
import 'package:novident_editor_document/novident_editor_document.dart';

import 'package:novident_editor_quill_parser/src/utils/quill_attribute_mapper.dart';
import 'package:novident_editor_quill_parser/src/utils/quill_rich_text_keys.dart';

import 'parser/delta_to_node/nodes.dart';

/// Converts a Quill [Paragraph] (a block of the AST produced by
/// `flutter_quill_delta_easy_parser`) into one or more novident block [Node]s.
///
/// This is the mirror of [NodeToQuill] on the decoding side: where the
/// encoder turns a novident node into a flat list of Quill operations, this
/// turns each parsed Quill block back into a node. Block-level formatting
/// (`header`, `list`, `blockquote`, …) is carried by
/// [Paragraph.blockAttributes], which [DeltaToNode.getExact] inspects to pick
/// the right converter.
abstract class QuillDeltaToNode {
  const QuillDeltaToNode();

  /// Returns the converter responsible for [paragraph]'s block type.
  ///
  /// Throws an [UnsupportedError] for embeds that have no novident
  /// equivalent (anything that is not an `image`).
  factory QuillDeltaToNode.getExact(Paragraph paragraph) {
    if (paragraph.isEmbed) {
      final embed = paragraph.lines.first.fragments.first.getEmbedValue();
      if (embed.containsKey(QuillRichTextKeys.image)) {
        return ImageToNode();
      }
      throw UnsupportedError(
        'Unsupported embed: ${embed.keys.toList()}',
      );
    }

    final attributes = paragraph.blockAttributes;
    if (attributes == null || attributes.isEmpty) {
      return ParagraphToNode();
    }

    final header = attributes[QuillRichTextKeys.heading];
    if (header is int) {
      return HeadingToNode();
    }

    final list = attributes[QuillRichTextKeys.list];
    if (list is String) {
      switch (list) {
        case QuillRichTextKeys.unordered:
          return BulletedListToNode();
        case QuillRichTextKeys.ordered:
          return OrderedListToNode();
        case QuillRichTextKeys.checkedList:
        case QuillRichTextKeys.unCheckedList:
          return TodoListToNode();
      }
    }

    if (attributes[QuillRichTextKeys.quote] == true) {
      return QuoteToNode();
    }

    // `code-block` (and any other unknown block attribute) has no novident
    // block equivalent — best-effort fallback to a plain paragraph.
    return ParagraphToNode();
  }

  /// Produces the novident nodes for [paragraph].
  ///
  /// Most converters emit a single node, but plain-text paragraphs may hold
  /// several Quill lines (the AST groups consecutive unformatted blocks into
  /// one paragraph) and therefore expand to one node per line.
  List<Node> toNodes(Paragraph paragraph);

  /// Builds the novident [Delta] from [lines]' text fragments, mapping
  /// inline attribute keys and colors back to novident.
  ///
  /// Embeds and newline fragments are skipped (embeds are handled by their
  /// own converter; a block's terminating `\n` is implicit in novident).
  Delta buildDeltaFromLines(Iterable<Line> lines) {
    final delta = Delta();
    for (final line in lines) {
      for (final fragment in line.fragments) {
        if (!fragment.isText) {
          continue;
        }
        final text = fragment.getTextValue();
        if (text.isEmpty || text == '\n') {
          continue;
        }
        delta.insert(
          text,
          attributes: toNovidentInlineAttributes(fragment.attributes),
        );
      }
    }
    return delta;
  }

  /// Builds the block-level attributes shared by every text block (`align`
  /// and `textDirection`) from [paragraph]'s Quill block attributes.
  Map<String, dynamic> buildCommonAttributes(Paragraph paragraph) {
    final attributes = paragraph.blockAttributes;
    if (attributes == null) {
      return const <String, dynamic>{};
    }

    final result = <String, dynamic>{};
    final align = attributes[QuillRichTextKeys.align] as String?;
    if (align != null && align.isNotEmpty) {
      result[blockComponentAlign] = align;
    }

    final direction = attributes[QuillRichTextKeys.direction] as String?;
    if (direction == 'rtl') {
      result[blockComponentTextDirection] = blockComponentTextDirectionRTL;
    } else if (direction == 'ltr') {
      result[blockComponentTextDirection] = blockComponentTextDirectionLTR;
    }

    return result;
  }

  /// Builds a text [Node] of [type] from [paragraph]'s delta plus the shared
  /// block attributes, merged with any block-specific [extra] attributes
  /// (`level`, `checked`, …).
  Node buildNode(
    Paragraph paragraph,
    String type, {
    Map<String, dynamic> extra = const <String, dynamic>{},
  }) {
    return Node(
      type: type,
      attributes: <String, dynamic>{
        blockComponentDelta: buildDeltaFromLines(paragraph.lines).toJson(),
        ...buildCommonAttributes(paragraph),
        ...extra,
      },
    );
  }

  /// Builds a plain paragraph [Node] from a single [Line].
  Node buildParagraphFromLine(Line line) {
    return Node(
      type: ParagraphBlockKeys.type,
      attributes: <String, dynamic>{
        blockComponentDelta: buildDeltaFromLines(<Line>[line]).toJson(),
      },
    );
  }
}
