import 'package:dart_quill_delta/dart_quill_delta.dart';
import 'package:novident_editor_core/novident_editor_core.dart';
import 'package:novident_editor_document/novident_editor_document.dart';
import '../../../../../novident_editor_quill_parser.dart';
import 'package:novident_editor_quill_parser/src/utils/quill_attribute_mapper.dart';
import 'package:novident_editor_quill_parser/src/utils/quill_rich_text_keys.dart';

class TodoToDelta extends NodeToQuill {
  @override
  List<Operation> toQuill(Node node, {Map<String, dynamic>? extra}) {
    final indent = extra?[QuillRichTextKeys.indent] as int?;
    final checked = node.attributes[TodoListBlockKeys.checked] == true;
    final blockAttributes = toQuillCommonBlockAttributes(node) ??
        <String, dynamic>{};
    blockAttributes[QuillRichTextKeys.list] = checked
        ? QuillRichTextKeys.checkedList
        : QuillRichTextKeys.unCheckedList;
    if (indent != null) {
      blockAttributes[QuillRichTextKeys.indent] = indent;
    }

    return <Operation>[
      ...buildInlineOperations(node),
      Operation.insert('\n', blockAttributes),
      ...buildNestedListOperations(node, indent),
    ];
  }

  @override
  bool validate(Node node) =>
      node.type == TodoListBlockKeys.type && node.delta != null;
}
