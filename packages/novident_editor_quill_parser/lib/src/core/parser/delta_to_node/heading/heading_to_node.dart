import 'package:flutter_quill_delta_easy_parser/flutter_quill_delta_easy_parser.dart'
    hide Document;
import 'package:novident_editor_core/novident_editor_core.dart';
import 'package:novident_editor_document/novident_editor_document.dart';
import '../../../../../novident_editor_quill_parser.dart';
import 'package:novident_editor_quill_parser/src/utils/quill_rich_text_keys.dart';

class HeadingToNode extends QuillDeltaToNode {
  @override
  List<Node> toNodes(Paragraph paragraph) {
    final level = paragraph.blockAttributes?[QuillRichTextKeys.heading] as int? ??
        1;
    return <Node>[
      buildNode(
        paragraph,
        HeadingBlockKeys.type,
        extra: {HeadingBlockKeys.level: level},
      ),
    ];
  }
}
