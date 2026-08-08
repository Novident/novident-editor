import 'package:flutter/material.dart' hide RichText;
import 'package:flutter_test/flutter_test.dart';
import 'package:novident_editor_core/novident_editor_core.dart';
import 'package:novident_editor_document/novident_editor_document.dart';
import 'package:novident_editor_rich_text/novident_editor_rich_text.dart';
import 'package:novident_editor_selection/novident_editor_selection.dart';

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

  group('Selection text color inversion', () {
    testWidgets('inverts text color on light selection background', (
      WidgetTester tester,
    ) async {
      // 1. Create a paragraph node with "Hello World".
      final node = Node(type: 'paragraph');
      final delta = Delta()..insert('Hello World');
      node.updateAttributes({'delta': delta.toJson()});

      // 2. Create a selection covering only "Hello" (offsets 0..5).
      final selectionNotifier = ValueNotifier<Selection?>(
        Selection(
          start: Position(path: <int>[], offset: 0),
          end: Position(path: <int>[], offset: 5),
        ),
      );
      final config = _StandaloneConfig(selectionNotifier: selectionNotifier);

      // 3. Pump with a light selection (yellow → white text).
      await tester.pumpWidget(
        MaterialApp(
          home: _TestSelector(
            node: node,
            editorConfig: config,
            selectionColor: Colors.yellow,
          ),
        ),
      );
      await tester.pump();

      // 4. Find the RichText widget and inspect its TextSpan tree.
      final richTexts = find.byType(RichText);
      expect(richTexts, findsOneWidget);
      final richText = tester.widget<RichText>(richTexts.first);
      final textSpan = richText.text as TextSpan;

      // Flatten TextSpan children.
      final spans = <TextSpan>[];
      void walk(InlineSpan span) {
        if (span is TextSpan) {
          spans.add(span);
          span.children?.forEach(walk);
        }
      }
      walk(textSpan);

      // 5. Collect spans that have text (skip WidgetSpan for indent).
      final textSpans =
          spans.where((s) => (s.text ?? '').isNotEmpty).toList();
      expect(
        textSpans.length,
        greaterThanOrEqualTo(2),
        reason: 'Expected at least 2 text spans after splitting at selection',
      );

      // Selected "Hello" should have contrast color (white on yellow).
      // Unselected " World" should keep the default color (black).
      final helloSpan = textSpans.firstWhere(
        (s) => s.text == 'Hello',
        orElse: () => throw Exception('No "Hello" span found'),
      );
      final worldSpan = textSpans.firstWhere(
        (s) => s.text == ' World',
        orElse: () => throw Exception('No " World" span found'),
      );

      expect(
        helloSpan.style?.color,
        Colors.white,
        reason: 'Selected text "Hello" should have contrast color '
            'against yellow selection background',
      );
      expect(
        worldSpan.style?.color ?? Colors.black,
        Colors.black,
        reason: 'Unselected text " World" should keep its original color',
      );
    });

    testWidgets('keeps text color when no selection', (
      WidgetTester tester,
    ) async {
      // No selection at all — text should be rendered as one span.
      final node = Node(type: 'paragraph');
      node.updateAttributes({
        'delta': (Delta()..insert('Hello World')).toJson(),
      });
      final selectionNotifier = ValueNotifier<Selection?>(null);
      final config = _StandaloneConfig(selectionNotifier: selectionNotifier);

      await tester.pumpWidget(
        MaterialApp(
          home: _TestSelector(
            node: node,
            editorConfig: config,
            selectionColor: Colors.blue,
          ),
        ),
      );
      await tester.pump();

      final richText = tester.widget<RichText>(find.byType(RichText).first);
      final textSpan = richText.text as TextSpan;

      final spans = <TextSpan>[];
      void walk(InlineSpan span) {
        if (span is TextSpan) {
          spans.add(span);
          span.children?.forEach(walk);
        }
      }

      walk(textSpan);

      final textSpans = spans.where((s) => (s.text ?? '').isNotEmpty).toList();
      expect(
        textSpans.length,
        1,
        reason: 'Without selection the text should be a single span',
      );
      expect(textSpans.first.text, 'Hello World');
    });
  });
}

class _StandaloneConfig implements RichTextEditorConfig {
  _StandaloneConfig({ValueNotifier<Selection?>? selectionNotifier})
      : selectionNotifier =
            selectionNotifier ?? ValueNotifier<Selection?>(null);
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
  final ValueNotifier<Selection?> selectionNotifier;
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

/// Minimal [StatefulWidget] that hosts a [NovidentRichText] with itself as
/// the [SelectableMixin] delegate, needed only for widget testing.
class _TestSelector extends StatefulWidget {
  const _TestSelector({
    required this.node,
    required this.editorConfig,
    required this.selectionColor,
  });

  final Node node;
  final RichTextEditorConfig editorConfig;
  final Color selectionColor;

  @override
  State<_TestSelector> createState() => _TestSelectorState();
}

class _TestSelectorState extends State<_TestSelector>
    with DefaultSelectableMixin, SelectableMixin<_TestSelector> {
  @override
  final forwardKey = GlobalKey();
  @override
  final containerKey = GlobalKey();
  @override
  final blockComponentKey = GlobalKey();

  @override
  Widget build(BuildContext context) {
    return NovidentRichText(
      key: forwardKey,
      delegate: this,
      node: widget.node,
      editorConfig: widget.editorConfig,
      selectionColor: widget.selectionColor,
    );
  }
}
