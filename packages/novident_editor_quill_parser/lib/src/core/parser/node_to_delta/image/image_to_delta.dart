import 'package:dart_quill_delta/dart_quill_delta.dart';
import 'package:novident_editor_core/novident_editor_core.dart';
import 'package:novident_editor_document/novident_editor_document.dart';
import '../../../../../novident_editor_quill_parser.dart';
import 'package:novident_editor_quill_parser/src/utils/quill_rich_text_keys.dart';

class ImageToDelta extends NodeToQuill {
  @override
  List<Operation> toQuill(Node node, {Map<String, dynamic>? extra}) {
    final url = node.attributes[ImageBlockKeys.url];
    final attributes = <String, dynamic>{};

    final width = node.attributes[ImageBlockKeys.width];
    if (width != null) {
      attributes[QuillRichTextKeys.width] = '$width';
    }

    final height = node.attributes[ImageBlockKeys.height];
    if (height != null) {
      attributes[QuillRichTextKeys.height] = '$height';
    }

    return <Operation>[
      Operation.insert(
        <String, dynamic>{QuillRichTextKeys.image: url},
        attributes.isEmpty ? null : attributes,
      ),
      Operation.insert('\n'),
    ];
  }

  @override
  bool validate(Node node) => node.type == ImageBlockKeys.type;
}
