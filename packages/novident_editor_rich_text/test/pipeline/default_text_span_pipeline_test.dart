import 'package:flutter/material.dart' hide RichText;
import 'package:flutter_test/flutter_test.dart';
import 'package:novident_editor_core/novident_editor_core.dart';
import 'package:novident_editor_document/novident_editor_document.dart';
import 'package:novident_editor_rich_text/novident_editor_rich_text.dart';

void main() {
  const pipeline = DefaultNovidentTextSpanPipeline();

  const baseStyle = TextStyle(
    fontSize: 16,
    fontFamily: 'Roboto',
    color: Colors.black,
  );

  const config = TextStyleConfiguration();

  Node paragraph() => Node(type: 'paragraph');

  TextInsert insertOf(String text, {Attributes? attributes}) =>
      TextInsert(text, attributes: attributes);

  group('phase 1: resolveStyle', () {
    test('null attributes returns the base style', () {
      expect(pipeline.resolveStyle(null, baseStyle, config), baseStyle);
    });

    test('bold, italic, underline, strikethrough', () {
      final style = pipeline.resolveStyle({
        RichTextKeys.bold: true,
        RichTextKeys.italic: true,
        RichTextKeys.underline: true,
        RichTextKeys.strikethrough: true,
      }, baseStyle, config);
      expect(style.fontWeight, FontWeight.bold);
      expect(style.fontStyle, FontStyle.italic);
      expect(
        style.decoration,
        TextDecoration.combine([
          TextDecoration.underline,
          TextDecoration.lineThrough,
        ]),
      );
    });

    test('href uses the text style configuration', () {
      final style = pipeline.resolveStyle({
        RichTextKeys.href: 'https://example.com',
      }, baseStyle, config);
      expect(style.color, config.href.color);
      expect(style.decoration, TextDecoration.underline);
    });

    test('code uses the text style configuration', () {
      final style = pipeline.resolveStyle({
        RichTextKeys.code: true,
      }, baseStyle, config);
      expect(style.color, config.code.color);
      expect(style.backgroundColor, config.code.backgroundColor);
    });

    test('code combined after href overrides the color (legacy order)', () {
      final style = pipeline.resolveStyle({
        RichTextKeys.href: 'https://example.com',
        RichTextKeys.code: true,
      }, baseStyle, config);
      expect(style.color, config.code.color);
      expect(style.backgroundColor, config.code.backgroundColor);
    });

    test('background colors and text color', () {
      final style = pipeline.resolveStyle({
        RichTextKeys.backgroundColor: '#FF0000',
        RichTextKeys.textColor: '#00FF00',
      }, baseStyle, config);
      expect(style.backgroundColor, isNotNull);
      expect(style.color, isNotNull);
    });

    test('font family and size', () {
      final style = pipeline.resolveStyle({
        RichTextKeys.fontFamily: 'Arial',
        RichTextKeys.fontSize: 24.0,
      }, baseStyle, config);
      expect(style.fontFamily, 'Arial');
      expect(style.fontSize, 24.0);
    });

    test('autoComplete and transparent', () {
      final autoComplete = pipeline.resolveStyle(
        {RichTextKeys.autoComplete: true},
        baseStyle,
        config,
      );
      expect(autoComplete.color, config.autoComplete.color);

      final transparent = pipeline.resolveStyle(
        {RichTextKeys.transparent: true},
        baseStyle,
        config,
      );
      expect(transparent.color, Colors.transparent);
    });

    test('combined attributes stack on the base', () {
      final style = pipeline.resolveStyle({
        RichTextKeys.bold: true,
        RichTextKeys.fontSize: 20.0,
      }, baseStyle, config);
      expect(style.fontWeight, FontWeight.bold);
      expect(style.fontSize, 20.0);
      expect(style.fontFamily, 'Roboto'); // preserved from base
    });
  });

  group('phase 2: transformText', () {
    test('caps uppercases', () {
      expect(
        pipeline.transformText(insertOf('camión'), 'camión',
            caps: true, smallCaps: false),
        'CAMIÓN',
      );
    });

    test('smallCaps lowercases', () {
      expect(
        pipeline.transformText(insertOf('CAMIÓN'), 'CAMIÓN',
            caps: false, smallCaps: true),
        'camión',
      );
    });

    test('no flags keeps the text as-is', () {
      expect(
        pipeline.transformText(insertOf('CaMiÓn'), 'CaMiÓn',
            caps: false, smallCaps: false),
        'CaMiÓn',
      );
    });

    test('length is preserved for document offsets', () {
      const text = 'Mixto Ñandú';
      final transformed = pipeline.transformText(insertOf(text), text,
          caps: true, smallCaps: false);
      expect(transformed.length, text.length);
    });
  });

  group('phase 3: emitSpans', () {
    SpanEmitContext ctx(
      String displayText, {
      Attributes? attributes,
      int offset = 0,
      NovidentTextSpanDecorator? spanDecorator,
      TextSpanDecoratorForAttribute? attributeDecorator,
    }) {
      return SpanEmitContext(
        node: paragraph(),
        insert: insertOf(displayText, attributes: attributes),
        displayText: displayText,
        style: baseStyle,
        offset: offset,
        textStyleConfiguration: config,
        textSpanDecorator: spanDecorator,
        textSpanDecoratorForAttribute: attributeDecorator,
      );
    }

    test('emits a single span without decorators', () {
      final spans = pipeline.emitSpans(ctx('hola'));
      expect(spans, hasLength(1));
      expect(spans.single, isA<TextSpan>());
      expect((spans.single as TextSpan).text, 'hola');
      expect((spans.single as TextSpan).style, baseStyle);
    });

    testWidgets('applies the per-attribute decorator with before/after', (
      tester,
    ) async {
      late BuildContext buildContext;
      await tester.pumpWidget(
        MaterialApp(
          home: Builder(
            builder: (context) {
              buildContext = context;
              return const SizedBox.shrink();
            },
          ),
        ),
      );

      final decorated = <TextSpan>[];
      final context = SpanEmitContext(
        buildContext: buildContext,
        node: paragraph(),
        insert: insertOf('hola'),
        displayText: 'hola',
        style: baseStyle,
        offset: 7,
        textStyleConfiguration: config,
        textSpanDecorator: (span) =>
            TextSpan(text: 'X${span.text}', style: span.style),
        textSpanDecoratorForAttribute:
            (context, node, index, insert, before, after) {
          decorated.add(after);
          return after;
        },
      );

      final spans = pipeline.emitSpans(context);
      expect(spans, hasLength(1));
      expect(decorated, hasLength(1));
      // 'after' is the whole-span decorator applied to 'before'.
      expect(decorated.single.text, 'Xhola');
    });
  });

  group('phase 4: paintSelectionContrast', () {
    SelectionContrastContext ctx(
      List<InlineSpan> spans, {
      int insertOffset = 0,
      int selStart = 0,
      int selEnd = 0,
      bool hasSelection = true,
      TextStyle textStyle = baseStyle,
    }) {
      return SelectionContrastContext(
        node: paragraph(),
        insert: insertOf('text'),
        spans: spans,
        insertOffset: insertOffset,
        selStart: selStart,
        selEnd: selEnd,
        textStyle: textStyle,
        textStyleConfiguration: config,
        selectionColor: Colors.blue,
        hasSelection: hasSelection,
      );
    }

    List<InlineSpan> textSpans(String text) => [
          TextSpan(text: text, style: baseStyle),
        ];

    test('without selection returns the spans untouched', () {
      final spans = textSpans('hola');
      final result = pipeline.paintSelectionContrast(
        ctx(spans, hasSelection: false),
      );
      expect(result, hasLength(1));
      expect(result.single, same(spans.single));
    });

    test('full selection produces a single contrast span', () {
      final result = pipeline.paintSelectionContrast(
        ctx(textSpans('hola'), selEnd: 4),
      );
      expect(result, hasLength(1));
      expect((result.single as TextSpan).text, 'hola');
      expect((result.single as TextSpan).style?.color, Colors.white);
    });

    test('middle selection splits into three pieces', () {
      final result = pipeline.paintSelectionContrast(
        ctx(textSpans('hola mundo'), selStart: 2, selEnd: 7),
      );
      expect(result, hasLength(3));
      expect((result[0] as TextSpan).text, 'ho');
      expect((result[0] as TextSpan).style?.color, Colors.black);
      expect((result[1] as TextSpan).text, 'la mu');
      expect((result[1] as TextSpan).style?.color, Colors.white);
      expect((result[2] as TextSpan).text, 'ndo');
      expect((result[2] as TextSpan).style?.color, Colors.black);
    });

    test('selection outside the span leaves it untouched', () {
      final spans = textSpans('hola');
      final result = pipeline.paintSelectionContrast(
        ctx(spans, insertOffset: 10, selStart: 0, selEnd: 3),
      );
      expect(result, hasLength(1));
      expect(result.single, same(spans.single));
    });

    test('spell-check split spans: selection only re-styles the second span',
        () {
      // Simulates phase 3 output of a spell-check pipeline: one valid
      // piece + one marked (error) piece of the same insert.
      final spans = <InlineSpan>[
        const TextSpan(
          text: 'hola ',
          style: TextStyle(color: Colors.black),
        ),
        const TextSpan(
          text: 'wrld',
          style: TextStyle(
            color: Colors.red,
            decoration: TextDecoration.underline,
            decorationStyle: TextDecorationStyle.wavy,
          ),
        ),
      ];
      final result = pipeline.paintSelectionContrast(
        ctx(spans, selStart: 5, selEnd: 9),
      );
      expect(result, hasLength(2));
      // First span untouched.
      expect(result[0], same(spans[0]));
      // Second span fully selected: contrast color applied, wavy preserved.
      final second = result[1] as TextSpan;
      expect(second.text, 'wrld');
      expect(second.style?.color, Colors.white);
      expect(second.style?.decoration, TextDecoration.underline);
      expect(second.style?.decorationStyle, TextDecorationStyle.wavy);
    });

    test('spell-check split spans: partial selection preserves segment styles',
        () {
      final spans = <InlineSpan>[
        const TextSpan(text: 'hola ', style: TextStyle(color: Colors.black)),
        const TextSpan(
          text: 'wrld',
          style: TextStyle(
            color: Colors.red,
            decoration: TextDecoration.underline,
            decorationStyle: TextDecorationStyle.wavy,
          ),
        ),
      ];
      final result = pipeline.paintSelectionContrast(
        ctx(spans, selStart: 6, selEnd: 8),
      );
      // 'hola wrld' offsets: valid piece 0..5, error piece 5..9 ('wrld').
      // Selection 6..8 → 'w' normal + 'rl' contrast + 'd' normal.
      expect(result, hasLength(4));
      expect(result[0], same(spans[0]));
      final before = result[1] as TextSpan;
      final selected = result[2] as TextSpan;
      final after = result[3] as TextSpan;
      expect(before.text, 'w');
      expect(before.style?.color, Colors.red);
      expect(selected.text, 'rl');
      expect(selected.style?.color, Colors.white);
      expect(selected.style?.decoration, TextDecoration.underline);
      expect(after.text, 'd');
      expect(after.style?.color, Colors.red);
    });

    test('WidgetSpans are never split', () {
      final widgetSpan = const WidgetSpan(child: SizedBox(width: 24));
      final spans = <InlineSpan>[
        widgetSpan,
        TextSpan(text: 'hola', style: baseStyle),
      ];
      final result = pipeline.paintSelectionContrast(
        ctx(spans, selStart: 0, selEnd: 4),
      );
      expect(result, hasLength(2));
      expect(result[0], same(widgetSpan));
      expect((result[1] as TextSpan).style?.color, Colors.white);
    });

    test('spans with children are passed through untouched', () {
      final nested = TextSpan(
        style: baseStyle,
        children: const [TextSpan(text: 'a'), TextSpan(text: 'b')],
      );
      final result = pipeline.paintSelectionContrast(
        ctx([nested], selStart: 0, selEnd: 2),
      );
      expect(result, hasLength(1));
      expect(result.single, same(nested));
    });

    test('selection color blends determine the contrast color', () {
      // Dark selection over a white background → white text.
      final dark = pipeline.paintSelectionContrast(
        ctx(textSpans('ab'), selEnd: 2, textStyle: baseStyle),
      );
      expect((dark.single as TextSpan).style?.color, Colors.white);

      // Light (yellowish) selection → dark text.
      final light = SelectionContrastContext(
        node: paragraph(),
        insert: insertOf('ab'),
        spans: textSpans('ab'),
        insertOffset: 0,
        selStart: 0,
        selEnd: 2,
        textStyle: baseStyle,
        textStyleConfiguration: config,
        selectionColor: const Color(0xFFFFF59D),
        hasSelection: true,
      );
      final result = pipeline.paintSelectionContrast(light);
      expect((result.single as TextSpan).style?.color, Colors.black);
    });
  });

  group('phase 5: buildPlaceholder', () {
    test('without indent produces the placeholder text span', () {
      final span = pipeline.buildPlaceholder(
        PlaceholderContext(
          node: paragraph(),
          placeholderText: 'Escribe algo...',
          baseTextStyle: baseStyle,
        ),
      );
      expect(span.children, isNotNull);
      final children = span.children!;
      expect(children, hasLength(1));
      expect((children.single as TextSpan).text, 'Escribe algo...');
    });

    test('with indent prepends a WidgetSpan', () {
      final span = pipeline.buildPlaceholder(
        PlaceholderContext(
          node: paragraph(),
          placeholderText: ' ',
          baseTextStyle: baseStyle,
          textShift: 1,
          firstLineIndentWidth: 32,
        ),
      );
      final children = span.children!;
      expect(children, hasLength(2));
      expect(children.first, isA<WidgetSpan>());
      expect((children.first as WidgetSpan).child, isA<SizedBox>());
      expect((children[1] as TextSpan).text, ' ');
    });
  });

  group('phase 6: adjustSpan', () {
    test('span with a style is returned untouched', () {
      final span = TextSpan(text: 'hola', style: baseStyle);
      expect(
        pipeline.adjustSpan(
          AdjustSpanContext(
              node: paragraph(), span: span, baseTextStyle: baseStyle),
        ),
        same(span),
      );
    });

    test('span without style and children is returned untouched', () {
      final span = TextSpan(children: const [TextSpan(text: 'hola')]);
      // children exist but no style/height → returned as-is.
      final result = pipeline.adjustSpan(
        AdjustSpanContext(
            node: paragraph(), span: span, baseTextStyle: baseStyle),
      );
      expect(result, same(span));
    });

    test('parentless style with measurable children gets the base style', () {
      final span = TextSpan(
        children: [
          TextSpan(
            text: 'hola',
            style: const TextStyle(height: 1.5, fontSize: 16),
          ),
        ],
      );
      final result = pipeline.adjustSpan(
        AdjustSpanContext(
          node: paragraph(),
          span: span,
          baseTextStyle: baseStyle,
        ),
      );
      expect(result.style, baseStyle);
    });

    test('heading nodes get the legacy height/fontSize style', () {
      final span = TextSpan(
        children: [
          TextSpan(
            text: 'H',
            style: const TextStyle(height: 2.0, fontSize: 24),
          ),
        ],
      );
      final result = pipeline.adjustSpan(
        AdjustSpanContext(
          node: Node(type: HeadingBlockKeys.type),
          span: span,
          baseTextStyle: baseStyle,
        ),
      );
      expect(result.style, isNotNull);
      expect(result.style!.height, 2.0);
      expect(result.style!.fontSize, 24);
    });
  });
}
