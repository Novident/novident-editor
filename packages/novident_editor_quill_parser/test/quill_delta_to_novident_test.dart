import 'package:dart_quill_delta/dart_quill_delta.dart' as quill;
import 'package:flutter_test/flutter_test.dart';
import 'package:novident_editor_core/novident_editor_core.dart';
import 'package:novident_editor_document/novident_editor_document.dart';
import 'package:novident_editor_quill_parser/novident_editor_quill_parser.dart';

void main() {
  final decoder = QuillDeltaToNovident();

  Document decode(List<Map<String, dynamic>> ops) =>
      decoder.parse(quill.Delta.fromJson(ops));

  List<Node> children(Document document) => document.root.children;

  String text(Node node) => node.delta!.toPlainText();

  group('paragraph', () {
    test('plain text', () {
      final document = decode([
        {'insert': 'Hello'},
        {'insert': '\n'},
      ]);
      final nodes = children(document);
      expect(nodes, hasLength(1));
      expect(nodes[0].type, ParagraphBlockKeys.type);
      expect(text(nodes[0]), 'Hello');
    });

    test('trailing empty paragraph is trimmed', () {
      final document = decode([
        {'insert': 'A'},
        {'insert': '\n'},
        {'insert': 'B'},
        {'insert': '\n'},
      ]);
      final nodes = children(document);
      expect(nodes, hasLength(2));
      expect(text(nodes[0]), 'A');
      expect(text(nodes[1]), 'B');
    });

    test('blank line produces an empty paragraph', () {
      final document = decode([
        {'insert': 'A'},
        {'insert': '\n'},
        {'insert': '\n'},
        {'insert': 'B'},
        {'insert': '\n'},
      ]);
      final nodes = children(document);
      expect(nodes, hasLength(3));
      expect(text(nodes[0]), 'A');
      expect(text(nodes[1]), '');
      expect(text(nodes[2]), 'B');
    });

    test('alignment is preserved', () {
      final document = decode([
        {'insert': 'Right'},
        {
          'insert': '\n',
          'attributes': {'align': 'right'}
        },
      ]);
      final nodes = children(document);
      expect(nodes[0].attributes[blockComponentAlign], 'right');
    });

    test('rtl direction is preserved', () {
      final document = decode([
        {'insert': 'שלום'},
        {
          'insert': '\n',
          'attributes': {'direction': 'rtl'}
        },
      ]);
      expect(
        children(document)[0].attributes[blockComponentTextDirection],
        'rtl',
      );
    });

    test('empty delta yields an empty document', () {
      final document = decoder.parse(quill.Delta());
      expect(children(document), isEmpty);
    });
  });

  group('heading', () {
    test('level maps back', () {
      final document = decode([
        {'insert': 'Title'},
        {
          'insert': '\n',
          'attributes': {'header': 3}
        },
      ]);
      final nodes = children(document);
      expect(nodes[0].type, HeadingBlockKeys.type);
      expect(nodes[0].attributes[HeadingBlockKeys.level], 3);
      expect(text(nodes[0]), 'Title');
    });
  });

  group('quote', () {
    test('blockquote maps back', () {
      final document = decode([
        {'insert': 'To be or not to be'},
        {
          'insert': '\n',
          'attributes': {'blockquote': true}
        },
      ]);
      final nodes = children(document);
      expect(nodes[0].type, QuoteBlockKeys.type);
      expect(text(nodes[0]), 'To be or not to be');
    });
  });

  group('lists', () {
    test('bulleted', () {
      final document = decode([
        {'insert': 'First'},
        {
          'insert': '\n',
          'attributes': {'list': 'bullet'}
        },
      ]);
      expect(children(document)[0].type, BulletedListBlockKeys.type);
      expect(text(children(document)[0]), 'First');
    });

    test('numbered', () {
      final document = decode([
        {'insert': 'One'},
        {
          'insert': '\n',
          'attributes': {'list': 'ordered'}
        },
      ]);
      expect(children(document)[0].type, NumberedListBlockKeys.type);
    });

    test('todo checked', () {
      final document = decode([
        {'insert': 'Done'},
        {
          'insert': '\n',
          'attributes': {'list': 'checked'}
        },
      ]);
      final node = children(document)[0];
      expect(node.type, TodoListBlockKeys.type);
      expect(node.attributes[TodoListBlockKeys.checked], true);
    });

    test('todo unchecked', () {
      final document = decode([
        {'insert': 'Pending'},
        {
          'insert': '\n',
          'attributes': {'list': 'unchecked'}
        },
      ]);
      final node = children(document)[0];
      expect(node.type, TodoListBlockKeys.type);
      expect(node.attributes[TodoListBlockKeys.checked], false);
    });

    test('nested lists reconstruct the tree', () {
      final document = decode([
        {'insert': 'Parent'},
        {
          'insert': '\n',
          'attributes': {'list': 'bullet'}
        },
        {'insert': 'Child'},
        {
          'insert': '\n',
          'attributes': {'list': 'bullet', 'indent': 1}
        },
        {'insert': 'Grand'},
        {
          'insert': '\n',
          'attributes': {'list': 'bullet', 'indent': 2}
        },
        {'insert': 'Sibling'},
        {
          'insert': '\n',
          'attributes': {'list': 'bullet'}
        },
      ]);
      final nodes = children(document);
      expect(nodes, hasLength(2));
      expect(text(nodes[0]), 'Parent');
      expect(text(nodes[1]), 'Sibling');

      final child = nodes[0].children.single;
      expect(child.type, BulletedListBlockKeys.type);
      expect(text(child), 'Child');

      final grand = child.children.single;
      expect(text(grand), 'Grand');
    });

    test('mixed nested list types keep their own type', () {
      final document = decode([
        {'insert': 'Parent'},
        {
          'insert': '\n',
          'attributes': {'list': 'bullet'}
        },
        {'insert': 'Child'},
        {
          'insert': '\n',
          'attributes': {'list': 'ordered', 'indent': 1}
        },
      ]);
      final parent = children(document).single;
      final child = parent.children.single;
      expect(child.type, NumberedListBlockKeys.type);
      expect(text(child), 'Child');
    });
  });

  group('image', () {
    test('embed with url and dimensions', () {
      final document = decode([
        {
          'insert': {'image': 'https://example.com/pic.png'},
          'attributes': {'width': '400', 'height': '300'},
        },
        {'insert': '\n'},
      ]);
      final node = children(document).single;
      expect(node.type, ImageBlockKeys.type);
      expect(
          node.attributes[ImageBlockKeys.url], 'https://example.com/pic.png');
      expect(node.attributes[ImageBlockKeys.width], 400.0);
      expect(node.attributes[ImageBlockKeys.height], 300.0);
    });

    test('unsupported embed throws', () {
      expect(
        () => decode([
          {
            'insert': {'video': 'https://example.com/v.mp4'},
          },
          {'insert': '\n'},
        ]),
        throwsUnsupportedError,
      );
    });
  });

  group('inline attributes', () {
    test('bold, italic, underline, code map directly', () {
      final document = decode([
        {
          'insert': 'x',
          'attributes': {
            'bold': true,
            'italic': true,
            'underline': true,
            'code': true,
          },
        },
        {'insert': '\n'},
      ]);
      final op = children(document)[0].delta!.operations.single as TextInsert;
      expect(op.attributes![RichTextKeys.bold], true);
      expect(op.attributes![RichTextKeys.italic], true);
      expect(op.attributes![RichTextKeys.underline], true);
      expect(op.attributes![RichTextKeys.code], true);
    });

    test('strike maps to strikethrough', () {
      final document = decode([
        {
          'insert': 'x',
          'attributes': {'strike': true}
        },
        {'insert': '\n'},
      ]);
      final op = children(document)[0].delta!.operations.single as TextInsert;
      expect(op.attributes![RichTextKeys.strikethrough], true);
    });

    test('link maps to href', () {
      final document = decode([
        {
          'insert': 'x',
          'attributes': {'link': 'https://example.com'}
        },
        {'insert': '\n'},
      ]);
      final op = children(document)[0].delta!.operations.single as TextInsert;
      expect(op.attributes![RichTextKeys.href], 'https://example.com');
    });

    test('font and size map to font_family and font_size', () {
      final document = decode([
        {
          'insert': 'x',
          'attributes': {'font': 'serif', 'size': '15'},
        },
        {'insert': '\n'},
      ]);
      final op = children(document)[0].delta!.operations.single as TextInsert;
      expect(op.attributes![RichTextKeys.fontFamily], 'serif');
      expect(op.attributes![RichTextKeys.fontSize], 15);
    });

    test('color maps to font_color', () {
      final document = decode([
        {
          'insert': 'x',
          'attributes': {'color': '#336699'}
        },
        {'insert': '\n'},
      ]);
      final op = children(document)[0].delta!.operations.single as TextInsert;
      expect(op.attributes![RichTextKeys.textColor], '0xFF336699');
    });

    test('background maps to bg_color', () {
      final document = decode([
        {
          'insert': 'x',
          'attributes': {'background': '#AA3366'}
        },
        {'insert': '\n'},
      ]);
      final op = children(document)[0].delta!.operations.single as TextInsert;
      expect(op.attributes![RichTextKeys.backgroundColor], '0xFFAA3366');
    });
  });

  group('round-trip with QuillDeltaFromNovident', () {
    final encoder = QuillDeltaFromNovident();

    Document roundTrip(Iterable<Node> nodes) =>
        decoder.parse(encoder.parse(nodes));

    test('heading + paragraph + quote + list + todo + image', () {
      final source = [
        Node(
          type: 'heading',
          attributes: {
            'delta': (Delta()..insert('Title')).toJson(),
            'level': 1,
          },
        ),
        Node(
          type: 'paragraph',
          attributes: {
            'delta': (Delta()..insert('Body')).toJson(),
          },
        ),
        Node(
          type: 'quote',
          attributes: {
            'delta': (Delta()..insert('Quoted')).toJson(),
          },
        ),
        Node(
          type: 'bulleted_list',
          attributes: {
            'delta': (Delta()..insert('Item')).toJson(),
          },
        ),
        Node(
          type: 'todo_list',
          attributes: {
            'delta': (Delta()..insert('Task')).toJson(),
            'checked': true,
          },
        ),
      ];

      final result = children(roundTrip(source));
      expect(result, hasLength(source.length));
      expect(result[0].type, 'heading');
      expect(result[0].attributes['level'], 1);
      expect(text(result[0]), 'Title');
      expect(result[1].type, 'paragraph');
      expect(text(result[1]), 'Body');
      expect(result[2].type, 'quote');
      expect(text(result[2]), 'Quoted');
      expect(result[3].type, 'bulleted_list');
      expect(text(result[3]), 'Item');
      expect(result[4].type, 'todo_list');
      expect(result[4].attributes['checked'], true);
      expect(text(result[4]), 'Task');
    });

    test('inline formatting survives the round-trip', () {
      final source = [
        Node(
          type: 'paragraph',
          attributes: {
            'delta': (Delta()
                  ..insert('bold', attributes: {RichTextKeys.bold: true})
                  ..insert(' ')
                  ..insert('red', attributes: {
                    RichTextKeys.textColor: '0xFF336699',
                  }))
                .toJson(),
          },
        ),
      ];

      final node = children(roundTrip(source)).single;
      final delta = node.delta!;
      expect(delta.toPlainText(), 'bold red');
      final ops = delta.operations.whereType<TextInsert>().toList();
      expect(ops[0].attributes![RichTextKeys.bold], true);
      expect(ops[2].attributes![RichTextKeys.textColor], '0xFF336699');
    });
  });
}
