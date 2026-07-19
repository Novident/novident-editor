import 'package:novident_editor/novident_editor.dart';

class ImageNodeParser extends NodeParser {
  const ImageNodeParser();

  @override
  String get id => ImageBlockKeys.type;

  @override
  String transform(Node node, DocumentMarkdownEncoder? encoder) {
    return '![](${node.attributes[ImageBlockKeys.url]})';
  }
}
