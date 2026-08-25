import 'package:flutter_quill_delta_easy_parser/flutter_quill_delta_easy_parser.dart'
    hide Document;
import 'package:novident_editor_core/novident_editor_core.dart';
import 'package:novident_editor_document/novident_editor_document.dart';
import '../../../../../novident_editor_quill_parser.dart';

class OrderedListToNode extends QuillDeltaToNode {
  @override
  List<Node> toNodes(Paragraph paragraph) =>
      <Node>[buildNode(paragraph, NumberedListBlockKeys.type)];
}
