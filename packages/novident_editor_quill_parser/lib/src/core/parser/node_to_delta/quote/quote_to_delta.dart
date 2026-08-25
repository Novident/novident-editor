import 'package:dart_quill_delta/dart_quill_delta.dart';
import 'package:novident_editor_core/novident_editor_core.dart';
import 'package:novident_editor_document/novident_editor_document.dart';
import '../../../../../novident_editor_quill_parser.dart';
import 'package:novident_editor_quill_parser/src/utils/quill_attribute_mapper.dart';
import 'package:novident_editor_quill_parser/src/utils/quill_rich_text_keys.dart';

class QuoteToDelta extends NodeToQuill {
  @override
  List<Operation> toQuill(Node node, {Map<String, dynamic>? extra}) {
    final blockAttributes = toQuillCommonBlockAttributes(node) ??
        <String, dynamic>{};
    blockAttributes[QuillRichTextKeys.quote] = true;

    return <Operation>[
      ...buildInlineOperations(node),
      Operation.insert('\n', blockAttributes),
    ];
  }

  @override
  bool validate(Node node) =>
      node.type == QuoteBlockKeys.type && node.delta != null;
}
