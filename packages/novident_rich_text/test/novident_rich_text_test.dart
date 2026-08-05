import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:novident_core/novident_core.dart';
import 'package:novident_editor_document/novident_editor_document.dart';
import 'package:novident_rich_text/novident_rich_text.dart';
import 'package:novident_selection/novident_selection.dart';

void main() {
  group('RichTextAttributes', () {
    test('bold, italic, underline', () {
      final attrs = <String, dynamic>{
        RichTextKeys.bold: true,
        RichTextKeys.italic: true,
      };
      expect(attrs.bold, isTrue);
      expect(attrs.italic, isTrue);
      expect(attrs.underline, isFalse);
      expect(attrs.strikethrough, isFalse);
      expect(attrs.code, isFalse);
    });

    test('color parsing', () {
      final attrs = <String, dynamic>{
        RichTextKeys.textColor: '#FF0000',
      };
      expect(attrs.color, isNotNull);
    });

    test('backgroundColor parsing', () {
      final attrs = <String, dynamic>{
        RichTextKeys.backgroundColor: '0xFFFFEB3B',
      };
      expect(attrs.backgroundColor, isNotNull);
    });

    test('href and fontFamily', () {
      final attrs = <String, dynamic>{
        RichTextKeys.href: 'https://example.com',
        RichTextKeys.fontFamily: 'Roboto',
      };
      expect(attrs.href, 'https://example.com');
      expect(attrs.fontFamily, 'Roboto');
    });

    test('fontSize', () {
      final attrs = <String, dynamic>{
        RichTextKeys.fontSize: 18.0,
      };
      expect(attrs.fontSize, 18.0);
    });

    test('autoComplete and transparent', () {
      final attrs = <String, dynamic>{
        RichTextKeys.autoComplete: true,
        RichTextKeys.transparent: true,
      };
      expect(attrs.autoComplete, isTrue);
      expect(attrs.transparent, isTrue);
    });

    test('findBackgroundColor', () {
      final attrs = <String, dynamic>{
        RichTextKeys.findBackgroundColor: '#00FF00',
      };
      expect(attrs.findBackgroundColor, isNotNull);
    });
  });

  group('DefaultSelectableMixin', () {
    test('exists and can be mixed in', () {
      // Compile-time check: if this test compiles, DefaultSelectableMixin
      // is properly exported from the package and can be used.
      expect(DefaultSelectableMixin, isNotNull);
    });
  });

  group('RichTextEditorConfig', () {
    test('can be implemented standalone', () {
      final config = _StandaloneConfig();
      expect(config.textScaleFactor, 1.0);
      expect(config.enableAutoComplete, false);
      expect(config.selectionNotifier, isA<ValueNotifier<Selection?>>());
    });
  });

  group('Node selection extensions', () {
    test('findParent walks up tree', () {
      final child = Node(type: 'paragraph');
      final parent = Node(type: 'table', children: [child]);
      final found = child.findParent((n) => n.type == 'table');
      expect(found, equals(parent));
    });

    test('findParent returns self if matches', () {
      final node = Node(type: 'table');
      final found = node.findParent((n) => n.type == 'table');
      expect(found, equals(node));
    });

    test('findParent returns null if no match', () {
      final node = Node(type: 'paragraph');
      final found = node.findParent((n) => n.type == 'table');
      expect(found, isNull);
    });
  });
}

class _StandaloneConfig implements RichTextEditorConfig {
  @override
  double get textScaleFactor => 1.0;
  @override
  double? get firstLineIndentFallback => null;
  @override
  TextSpanDecoratorForAttribute? get textSpanDecorator => null;
  @override
  NovidentTextSpanOverlayBuilder? get textSpanOverlayBuilder => null;
  @override
  TextStyleConfiguration get textStyleConfiguration =>
      const TextStyleConfiguration();
  @override
  bool get enableAutoComplete => false;
  @override
  NovidentAutoCompleteTextProvider? get autoCompleteTextProvider => null;
  @override
  final selectionNotifier = ValueNotifier<Selection?>(null);
  @override
  final remoteSelections = ValueNotifier<List<RemoteSelection>>([]);
  @override
  bool isBlockSelectionMode() => false;
  @override
  CursorAppearance? customizeCursor(
          {required Node node,
          required Selection? selection,
          required Position position}) =>
      null;
  @override
  EdgeInsets? blockSelectionMargin(Node node) => null;
  @override
  String? selectionDragModeValue() => null;
  @override
  SelectionRenderer? get selectionRenderer => DefaultSelectionRenderer();
}
