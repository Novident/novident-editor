import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:novident_editor/novident_editor.dart';

void main() {
  const baseStyle = TextStyle(fontSize: 16, color: Colors.black);
  const config = TextStyleConfiguration();
  const delegate = DefaultNovidentTextSpanPipeline();
  const pipeline = ZenSpanPipeline(delegate);

  Node paragraph() => Node(type: 'paragraph');

  Future<BuildContext> pumpScope(
    WidgetTester tester, {
    required bool dimmed,
    ZenModeConfiguration configuration = const ZenModeConfiguration(),
    double unfocusedOpacity = 0.35,
  }) async {
    late BuildContext buildContext;
    await tester.pumpWidget(
      MaterialApp(
        home: ZenModeScope(
          dimmed: dimmed,
          unfocusedOpacity: unfocusedOpacity,
          configuration: configuration,
          child: Builder(
            builder: (context) {
              buildContext = context;
              return const SizedBox.shrink();
            },
          ),
        ),
      ),
    );
    return buildContext;
  }

  group('ZenSpanPipeline.resolveStyle', () {
    test('delegates to the effective pipeline when no scope is present', () {
      final style = pipeline.resolveStyle(
        {RichTextKeys.textColor: '#FF0000'},
        baseStyle,
        config,
        node: paragraph(),
      );
      // the attribute color is applied by the delegate (no dimming).
      expect(style.color, isNot(Colors.black));
    });

    testWidgets('does not dim when the block is not dimmed', (tester) async {
      final context = await pumpScope(tester, dimmed: false);
      final style = pipeline.resolveStyle(
        {RichTextKeys.textColor: '#FF0000'},
        baseStyle,
        config,
        node: paragraph(),
        context: context,
      );
      expect(style.color, isNot(Colors.black.withValues(alpha: 0.35)));
    });

    testWidgets('dims the textColor of a dimmed block', (tester) async {
      final context = await pumpScope(tester, dimmed: true);
      final style = pipeline.resolveStyle(
        {RichTextKeys.textColor: '#FF0000'},
        baseStyle,
        config,
        node: paragraph(),
        context: context,
      );
      expect(style.color, Colors.black.withValues(alpha: 0.35));
    });

    testWidgets('dims plain text without a textColor attribute',
        (tester) async {
      final context = await pumpScope(tester, dimmed: true);
      final style = pipeline.resolveStyle(
        null,
        baseStyle,
        config,
        node: paragraph(),
        context: context,
      );
      expect(style.color, Colors.black.withValues(alpha: 0.35));
    });

    testWidgets('does not dim when ignoreTextColor is false', (tester) async {
      final context = await pumpScope(
        tester,
        dimmed: true,
        configuration: const ZenModeConfiguration(ignoreTextColor: false),
      );
      final style = pipeline.resolveStyle(
        {RichTextKeys.textColor: '#FF0000'},
        baseStyle,
        config,
        node: paragraph(),
        context: context,
      );
      expect(style.color, isNot(Colors.black.withValues(alpha: 0.35)));
    });

    testWidgets('neutralizes the highlight of a dimmed block', (tester) async {
      final context = await pumpScope(tester, dimmed: true);
      final style = pipeline.resolveStyle(
        {RichTextKeys.backgroundColor: '#FFFF00'},
        baseStyle,
        config,
        node: paragraph(),
        context: context,
      );
      expect(style.backgroundColor, Colors.transparent);
    });

    testWidgets('keeps the find & replace highlight', (tester) async {
      final context = await pumpScope(tester, dimmed: true);
      final style = pipeline.resolveStyle(
        {RichTextKeys.findBackgroundColor: '#FF00FF'},
        baseStyle,
        config,
        node: paragraph(),
        context: context,
      );
      expect(style.backgroundColor, isNot(Colors.transparent));
    });

    testWidgets('does not override the transparent ghost text', (tester) async {
      final context = await pumpScope(tester, dimmed: true);
      final style = pipeline.resolveStyle(
        {RichTextKeys.transparent: true, RichTextKeys.textColor: '#FF0000'},
        baseStyle,
        config,
        node: paragraph(),
        context: context,
      );
      expect(style.color, isNot(Colors.black.withValues(alpha: 0.35)));
    });
  });

  group('ZenSpanPipeline delegation', () {
    test('transformText delegates to the effective pipeline', () {
      final insert = TextInsert('hola');
      expect(
        pipeline.transformText(insert, 'hola', caps: true, smallCaps: false),
        'HOLA',
      );
    });

    test('emitSpans delegates to the effective pipeline', () {
      final spans = pipeline.emitSpans(
        SpanEmitContext(
          node: paragraph(),
          insert: TextInsert('hola'),
          displayText: 'hola',
          style: baseStyle,
          offset: 0,
          textStyleConfiguration: config,
        ),
      );
      expect(spans, hasLength(1));
      expect((spans.single as TextSpan).text, 'hola');
    });
  });
}
