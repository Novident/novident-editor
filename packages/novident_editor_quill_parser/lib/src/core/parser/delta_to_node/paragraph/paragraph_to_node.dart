import 'package:flutter_quill_delta_easy_parser/flutter_quill_delta_easy_parser.dart'
    hide Document;
import 'package:novident_editor_core/novident_editor_core.dart';
import 'package:novident_editor_document/novident_editor_document.dart';
import '../../../../../novident_editor_quill_parser.dart';

class ParagraphToNode extends QuillDeltaToNode {
  @override
  List<Node> toNodes(Paragraph paragraph) {
    // A plain paragraph (no block attributes) may group several Quill lines;
    // each line is its own novident block.
    final hasBlockAttributes = paragraph.blockAttributes?.isNotEmpty ?? false;
    if (hasBlockAttributes) {
      return <Node>[buildNode(paragraph, ParagraphBlockKeys.type)];
    }
    return <Node>[
      for (final line in paragraph.lines) buildParagraphFromLine(line),
    ];
  }
}
