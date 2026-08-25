import 'package:dart_quill_delta/dart_quill_delta.dart';
import 'package:novident_editor_document/novident_editor_document.dart';

import '../quill_attribute_mapper.dart';

extension TextInsertToOperation on TextInsert {
  /// Converts a novident [TextInsert] into a Quill [Operation], translating
  /// the inline attribute names (and color encoding) in the process.
  Operation get toQuillOperation {
    return Operation.insert(
      data,
      toQuillInlineAttributes(attributes),
    );
  }
}
