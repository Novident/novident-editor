import 'package:dart_quill_delta/dart_quill_delta.dart';
import 'package:novident_editor_core/novident_editor_core.dart';
import 'package:novident_editor_document/novident_editor_document.dart';
import '../../../../../novident_editor_quill_parser.dart';
import 'package:novident_editor_quill_parser/src/utils/quill_attribute_mapper.dart';

class ParagraphToDelta extends NodeToQuill {
  @override
  List<Operation> toQuill(Node node, {Map<String, dynamic>? extra}) {
    return <Operation>[
      ...buildInlineOperations(node),
      Operation.insert('\n', toQuillCommonBlockAttributes(node)),
    ];
  }

  @override
  bool validate(Node node) =>
      node.type == ParagraphBlockKeys.type && node.delta != null;
}
