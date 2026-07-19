import 'package:novident_editor/novident_editor.dart';

import 'typedef_util.dart';

extension DocumentExtension on Document {
  Document addParagraphs(
    int count, {
    TextBuilder? builder,
    String? initialText,
    NodeDecorator? decorator,
  }) {
    return addNodes(
      count,
      'paragraph',
      builder: builder,
      initialText: initialText,
      decorator: decorator,
    );
  }

  Document addParagraph({
    TextBuilder? builder,
    String? initialText,
    NodeDecorator? decorator,
  }) {
    return addParagraphs(
      1,
      builder: builder,
      initialText: initialText,
      decorator: decorator,
    );
  }

  Document addNodes(
    int count,
    String type, {
    TextBuilder? builder,
    String? initialText,
    NodeDecorator? decorator,
  }) {
    final builder0 = builder ??
        (index) => Delta()
          ..insert(initialText ?? '🔥 $index. Welcome to Novident Editor!');
    final decorator0 = decorator ?? (index, node) {};
    final children = List.generate(count, (index) {
      final node = Node(type: type);
      decorator0(index, node);
      node.updateAttributes({
        'delta': builder0(index).toJson(),
      });
      return node;
    });
    return this
      ..insert(
        [root.children.length],
        children,
      );
  }

  Document addNode(
    String type, {
    TextBuilder? builder,
    String? initialText,
    NodeDecorator? decorator,
  }) {
    return addNodes(
      1,
      type,
      builder: builder,
      initialText: initialText,
      decorator: decorator,
    );
  }
}
