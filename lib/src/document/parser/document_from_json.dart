import 'package:novident_editor/src/document/delta/delta.dart';
import 'package:novident_editor/src/document/document.dart';

class DocumentParser {
  const DocumentParser._();
  static Document fromUniversalJson(List<Map<String, dynamic>> json) {
    return Document.empty();
  }

  static Document fromDelta(Delta delta) {
    return Document.empty();
  }

  static Document fromMarkdown(String markdown) {
    return Document.empty();
  }
}
