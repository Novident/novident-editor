import 'package:dart_quill_delta/dart_quill_delta.dart' as quill;
import 'package:flutter_test/flutter_test.dart';
import 'package:novident_editor_core/novident_editor_core.dart';
import 'package:novident_editor_document/novident_editor_document.dart';
import 'package:novident_editor_quill_parser/novident_editor_quill_parser.dart';

Node _node(
  String type,
  String? text, {
  Map<String, dynamic> attributes = const {},
  Iterable<Node> children = const [],
}) {
  final data = <String, dynamic>{...attributes};
  if (text != null) {
    data['delta'] = (Delta()..insert(text)).toJson();
  }
  return Node(
    type: type,
    attributes: data,
    children: children,
  );
}

Node _deltaNode(
  String type,
  Delta delta, {
  Map<String, dynamic> attributes = const {},
  Iterable<Node> children = const [],
}) {
  return Node(
    type: type,
    attributes: {...attributes, 'delta': delta.toJson()},
    children: children,
  );
}

Node _page(Iterable<Node> children) {
  return Node(type: 'page', children: children);
}

void main() {
  final encoder = QuillDeltaFromNovident();

  List<Map<String, dynamic>> encode(Iterable<Node> nodes) =>
      encoder.parse(nodes).toJson().cast<Map<String, dynamic>>();

  group('paragraph', () {
    test('plain text', () {
      expect(
        encode([_node('paragraph', 'Hello')]),
        [
          {'insert': 'Hello'},
          {'insert': '\n'},
        ],
      );
    });

    test('empty paragraph emits only the newline', () {
      expect(
        encode([_node('paragraph', '')]),
        [
          {'insert': '\n'},
        ],
      );
    });

    test('plain paragraphs stay as separate blocks', () {
      expect(
        encode([
          _node('paragraph', 'Hello'),
          _node('paragraph', 'World'),
        ]),
        [
          {'insert': 'Hello'},
          {'insert': '\n'},
          {'insert': 'World'},
          {'insert': '\n'},
        ],
      );
    });

    test('alignment is preserved as a block attribute', () {
      expect(
        encode([
          _node(
            'paragraph',
            'Right',
            attributes: {blockComponentAlign: 'right'},
          ),
        ]),
        [
          {'insert': 'Right'},
          {
            'insert': '\n',
            'attributes': {'align': 'right'},
          },
        ],
      );
    });

    test('rtl text direction is preserved', () {
      expect(
        encode([
          _node(
            'paragraph',
            'שלום',
            attributes: {blockComponentTextDirection: 'rtl'},
          ),
        ]),
        [
          {'insert': 'שלום'},
          {
            'insert': '\n',
            'attributes': {'direction': 'rtl'},
          },
        ],
      );
    });

    test('auto text direction is ignored', () {
      expect(
        encode([
          _node(
            'paragraph',
            'Hello',
            attributes: {blockComponentTextDirection: 'auto'},
          ),
        ]),
        [
          {'insert': 'Hello'},
          {'insert': '\n'},
        ],
      );
    });
  });

  group('inline attributes', () {
    test('bold, italic, underline, code map directly', () {
      final delta = Delta()
        ..insert('x', attributes: {
          RichTextKeys.bold: true,
          RichTextKeys.italic: true,
          RichTextKeys.underline: true,
          RichTextKeys.code: true,
        });
      expect(
        encode([_deltaNode('paragraph', delta)]),
        [
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
        ],
      );
    });

    test('strikethrough maps to strike', () {
      final delta = Delta()
        ..insert('x', attributes: {RichTextKeys.strikethrough: true});
      expect(
        encode([_deltaNode('paragraph', delta)]),
        [
          {
            'insert': 'x',
            'attributes': {'strike': true},
          },
          {'insert': '\n'},
        ],
      );
    });

    test('href maps to link', () {
      final delta = Delta()
        ..insert('x', attributes: {RichTextKeys.href: 'https://example.com'});
      expect(
        encode([_deltaNode('paragraph', delta)]),
        [
          {
            'insert': 'x',
            'attributes': {'link': 'https://example.com'},
          },
          {'insert': '\n'},
        ],
      );
    });

    test('font_family and font_size map to font and size', () {
      final delta = Delta()
        ..insert('x', attributes: {
          RichTextKeys.fontFamily: 'serif',
          RichTextKeys.fontSize: 15,
        });
      expect(
        encode([_deltaNode('paragraph', delta)]),
        [
          {
            'insert': 'x',
            'attributes': {'font': 'serif', 'size': '15'},
          },
          {'insert': '\n'},
        ],
      );
    });

    test('font_color maps to color with hex conversion', () {
      final delta = Delta()
        ..insert('x', attributes: {RichTextKeys.textColor: '0xFF336699'});
      expect(
        encode([_deltaNode('paragraph', delta)]),
        [
          {
            'insert': 'x',
            'attributes': {'color': '#336699'},
          },
          {'insert': '\n'},
        ],
      );
    });

    test('bg_color maps to background with hex conversion', () {
      final delta = Delta()
        ..insert('x', attributes: {RichTextKeys.backgroundColor: '0xFFAA3366'});
      expect(
        encode([_deltaNode('paragraph', delta)]),
        [
          {
            'insert': 'x',
            'attributes': {'background': '#AA3366'},
          },
          {'insert': '\n'},
        ],
      );
    });

    test('internal attributes are dropped', () {
      final delta = Delta()
        ..insert('x', attributes: {
          RichTextKeys.proofState: 'error',
          RichTextKeys.findBackgroundColor: '0xFF000000',
          RichTextKeys.autoComplete: 'value',
        });
      expect(
        encode([_deltaNode('paragraph', delta)]),
        [
          {'insert': 'x'},
          {'insert': '\n'},
        ],
      );
    });
  });

  group('heading', () {
    test('level maps to header', () {
      expect(
        encode([
          _node(
            'heading',
            'Title',
            attributes: {HeadingBlockKeys.level: 2},
          ),
        ]),
        [
          {'insert': 'Title'},
          {
            'insert': '\n',
            'attributes': {'header': 2},
          },
        ],
      );
    });

    test('missing level defaults to 1', () {
      expect(
        encode([_node('heading', 'Title')]),
        [
          {'insert': 'Title'},
          {
            'insert': '\n',
            'attributes': {'header': 1},
          },
        ],
      );
    });
  });

  group('quote', () {
    test('maps to blockquote', () {
      expect(
        encode([_node('quote', 'To be or not to be')]),
        [
          {'insert': 'To be or not to be'},
          {
            'insert': '\n',
            'attributes': {'blockquote': true},
          },
        ],
      );
    });
  });

  group('lists', () {
    test('bulleted list', () {
      expect(
        encode([_node('bulleted_list', 'First')]),
        [
          {'insert': 'First'},
          {
            'insert': '\n',
            'attributes': {'list': 'bullet'},
          },
        ],
      );
    });

    test('numbered list', () {
      expect(
        encode([_node('numbered_list', 'One')]),
        [
          {'insert': 'One'},
          {
            'insert': '\n',
            'attributes': {'list': 'ordered'},
          },
        ],
      );
    });

    test('todo list checked', () {
      expect(
        encode([
          _node('todo_list', 'Done', attributes: {'checked': true}),
        ]),
        [
          {'insert': 'Done'},
          {
            'insert': '\n',
            'attributes': {'list': 'checked'},
          },
        ],
      );
    });

    test('todo list unchecked', () {
      expect(
        encode([
          _node('todo_list', 'Pending', attributes: {'checked': false}),
        ]),
        [
          {'insert': 'Pending'},
          {
            'insert': '\n',
            'attributes': {'list': 'unchecked'},
          },
        ],
      );
    });

    test('nested bulleted list adds indent levels', () {
      expect(
        encode([
          _node(
            'bulleted_list',
            'Parent',
            children: [
              _node(
                'bulleted_list',
                'Child',
                children: [
                  _node('bulleted_list', 'Grandchild'),
                ],
              ),
            ],
          ),
        ]),
        [
          {'insert': 'Parent'},
          {
            'insert': '\n',
            'attributes': {'list': 'bullet'},
          },
          {'insert': 'Child'},
          {
            'insert': '\n',
            'attributes': {'list': 'bullet', 'indent': 1},
          },
          {'insert': 'Grandchild'},
          {
            'insert': '\n',
            'attributes': {'list': 'bullet', 'indent': 2},
          },
        ],
      );
    });

    test('mixed nested list types preserve their own list value', () {
      expect(
        encode([
          _node(
            'bulleted_list',
            'Parent',
            children: [_node('numbered_list', 'Child')],
          ),
        ]),
        [
          {'insert': 'Parent'},
          {
            'insert': '\n',
            'attributes': {'list': 'bullet'},
          },
          {'insert': 'Child'},
          {
            'insert': '\n',
            'attributes': {'list': 'ordered', 'indent': 1},
          },
        ],
      );
    });
  });

  group('image', () {
    test('embed with url and dimensions', () {
      expect(
        encode([
          _node(
            'image',
            null,
            attributes: {
              'url': 'https://example.com/pic.png',
              'width': 400.0,
              'height': 300.0,
            },
          ),
        ]),
        [
          {
            'insert': {'image': 'https://example.com/pic.png'},
            'attributes': {'width': '400.0', 'height': '300.0'},
          },
          {'insert': '\n'},
        ],
      );
    });

    test('embed without dimensions omits attributes', () {
      expect(
        encode([
          _node(
            'image',
            null,
            attributes: {'url': 'https://example.com/pic.png'},
          ),
        ]),
        [
          {
            'insert': {'image': 'https://example.com/pic.png'},
          },
          {'insert': '\n'},
        ],
      );
    });
  });

  group('document entry points', () {
    test('fromDocument converts a full document', () {
      final document = Document(
        root: _page([
          _node(
            'heading',
            'Title',
            attributes: {HeadingBlockKeys.level: 1},
          ),
          _node('paragraph', 'Body'),
        ]),
      );

      expect(
        encoder.fromDocument(document).toJson(),
        [
          {'insert': 'Title'},
          {
            'insert': '\n',
            'attributes': {'header': 1},
          },
          {'insert': 'Body'},
          {'insert': '\n'},
        ],
      );
    });

    test('fromJson converts the Document.fromJson shape', () {
      final json = {
        'document': {
          'type': 'page',
          'children': [
            {
              'type': 'paragraph',
              'data': {
                'delta': [
                  {'insert': 'Hello'},
                ],
              },
            },
          ],
        },
      };

      expect(
        encoder.fromJson(json).toJson(),
        [
          {'insert': 'Hello'},
          {'insert': '\n'},
        ],
      );
    });
  });

  group('unsupported block types', () {
    test('divider throws', () {
      expect(
        () => encode([_node('divider', null)]),
        throwsUnsupportedError,
      );
    });

    test('table throws', () {
      expect(
        () => encode([_node('table', null)]),
        throwsUnsupportedError,
      );
    });
  });

  group('QuillDeltaFromNovident', () {
    test('returns a dart_quill_delta Delta', () {
      final result = encoder.parse([_node('paragraph', 'x')]);
      expect(result, isA<quill.Delta>());
    });
  });
}
