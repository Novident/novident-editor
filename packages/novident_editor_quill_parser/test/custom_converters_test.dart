import 'package:dart_quill_delta/dart_quill_delta.dart' as quill;
import 'package:flutter_quill_delta_easy_parser/flutter_quill_delta_easy_parser.dart'
    as easy;
import 'package:flutter_test/flutter_test.dart';
import 'package:novident_editor_document/novident_editor_document.dart';
import 'package:novident_editor_quill_parser/novident_editor_quill_parser.dart';

/// A custom block encoded as the embed `{'my_custom': value}`.
class CustomBlockToDelta extends NodeToQuill {
  @override
  List<quill.Operation> toQuill(Node node, {Map<String, dynamic>? extra}) {
    return <quill.Operation>[
      quill.Operation.insert(
        <String, dynamic>{'my_custom': node.attributes['value']},
      ),
      quill.Operation.insert('\n'),
    ];
  }

  @override
  bool validate(Node node) => node.type == 'my_custom_block';
}

/// Decodes the embed `{'my_custom': value}` back into a custom block.
class CustomEmbedToNode extends QuillDeltaToNode {
  @override
  List<Node> toNodes(easy.Paragraph paragraph) {
    final embed = paragraph.lines.first.fragments.first.getEmbedValue();
    return <Node>[
      Node(
        type: 'my_custom_block',
        attributes: <String, dynamic>{'value': embed['my_custom']},
      ),
    ];
  }
}

class MyEncoder extends QuillDeltaFromNovident {
  @override
  NodeToQuill converterFor(Node node) {
    if (node.type == 'my_custom_block') {
      return CustomBlockToDelta();
    }
    return super.converterFor(node);
  }
}

class MyDecoder extends QuillDeltaToNovident {
  @override
  QuillDeltaToNode converterFor(easy.Paragraph paragraph) {
    if (paragraph.isEmbed) {
      final embed = paragraph.lines.first.fragments.first.getEmbedValue();
      if (embed.containsKey('my_custom')) {
        return CustomEmbedToNode();
      }
    }
    return super.converterFor(paragraph);
  }
}

void main() {
  group('encoder custom converters', () {
    test('via converters map', () {
      final encoder = QuillDeltaFromNovident(
        converters: <String, NodeToQuill>{'my_custom_block': CustomBlockToDelta()},
      );
      final delta = encoder.parse([
        Node(
          type: 'my_custom_block',
          attributes: <String, dynamic>{'value': 'hello'},
        ),
      ]);
      expect(delta.toJson(), <Object>[
        <String, dynamic>{
          'insert': <String, dynamic>{'my_custom': 'hello'},
        },
        <String, dynamic>{'insert': '\n'},
      ]);
    });

    test('via converterFor override', () {
      final encoder = MyEncoder();
      final delta = encoder.parse([
        Node(
          type: 'my_custom_block',
          attributes: <String, dynamic>{'value': 'world'},
        ),
      ]);
      expect(delta.toJson(), <Object>[
        <String, dynamic>{
          'insert': <String, dynamic>{'my_custom': 'world'},
        },
        <String, dynamic>{'insert': '\n'},
      ]);
    });

    test('still throws for truly unknown types', () {
      final encoder = QuillDeltaFromNovident();
      expect(
        () => encoder.parse([Node(type: 'unknown_type')]),
        throwsUnsupportedError,
      );
    });
  });

  group('decoder custom converters', () {
    test('via embedConverters map', () {
      final decoder = QuillDeltaToNovident(
        embedConverters: <String, QuillDeltaToNode>{'my_custom': CustomEmbedToNode()},
      );
      final document = decoder.parse(
        quill.Delta.fromJson(<Map<String, dynamic>>[
          <String, dynamic>{
            'insert': <String, dynamic>{'my_custom': 'hello'},
          },
          <String, dynamic>{'insert': '\n'},
        ]),
      );
      final node = document.root.children.single;
      expect(node.type, 'my_custom_block');
      expect(node.attributes['value'], 'hello');
    });

    test('via converterFor override', () {
      final decoder = MyDecoder();
      final document = decoder.parse(
        quill.Delta.fromJson(<Map<String, dynamic>>[
          <String, dynamic>{
            'insert': <String, dynamic>{'my_custom': 'world'},
          },
          <String, dynamic>{'insert': '\n'},
        ]),
      );
      final node = document.root.children.single;
      expect(node.type, 'my_custom_block');
      expect(node.attributes['value'], 'world');
    });

    test('still throws for unknown embeds without a custom converter', () {
      final decoder = QuillDeltaToNovident();
      expect(
        () => decoder.parse(
          quill.Delta.fromJson(<Map<String, dynamic>>[
            <String, dynamic>{
              'insert': <String, dynamic>{'unknown': 'x'},
            },
            <String, dynamic>{'insert': '\n'},
          ]),
        ),
        throwsUnsupportedError,
      );
    });
  });

  group('custom round-trip', () {
    test('custom block survives encode → decode', () {
      final encoder = MyEncoder();
      final decoder = MyDecoder();

      final delta = encoder.parse([
        Node(
          type: 'my_custom_block',
          attributes: <String, dynamic>{'value': 'round-trip'},
        ),
      ]);
      final document = decoder.parse(delta);

      final node = document.root.children.single;
      expect(node.type, 'my_custom_block');
      expect(node.attributes['value'], 'round-trip');
    });
  });
}
