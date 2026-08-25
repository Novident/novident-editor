import 'package:flutter_quill_delta_easy_parser/flutter_quill_delta_easy_parser.dart'
    hide Document;
import 'package:novident_editor_core/novident_editor_core.dart';
import 'package:novident_editor_document/novident_editor_document.dart';
import 'package:novident_editor_quill_parser/src/utils/quill_rich_text_keys.dart';

import '../../../../../novident_editor_quill_parser.dart';

class ImageToNode extends QuillDeltaToNode {
  @override
  List<Node> toNodes(Paragraph paragraph) {
    final fragment = paragraph.lines.first.fragments.first;
    final embed = fragment.getEmbedValue();

    final attributes = <String, dynamic>{
      ImageBlockKeys.url: embed[QuillRichTextKeys.image],
    };

    final width =
        _parseDimension(fragment.attributes?[QuillRichTextKeys.width]);
    if (width != null) {
      attributes[ImageBlockKeys.width] = width;
    }

    final height =
        _parseDimension(fragment.attributes?[QuillRichTextKeys.height]);
    if (height != null) {
      attributes[ImageBlockKeys.height] = height;
    }

    return <Node>[Node(type: ImageBlockKeys.type, attributes: attributes)];
  }

  double? _parseDimension(Object? value) {
    if (value == null) {
      return null;
    }
    return double.tryParse('$value');
  }
}
