import 'package:flutter/material.dart' hide RichText;
import 'package:flutter_test/flutter_test.dart';
import 'package:novident_editor/novident_editor.dart';

class _FakeChecker implements NovidentSpellChecker {
  const _FakeChecker();

  @override
  bool isValid(String word) => true;

  @override
  List<SpellCheckIssue> check(String text) => const [];

  @override
  List<String> suggest(String word) => const [];

  @override
  Future<List<String>> suggestAsync(String word) async => suggest(word);

  @override
  void addWord(String word) {}

  @override
  void forgetWord(String word) {}

  @override
  String? get language => 'es';
}

void main() {
  const baseStyle = TextStyle(fontSize: 16, color: Colors.black);

  SpanEmitContext emitContext({
    required String text,
    Attributes? attributes,
    TextStyle style = baseStyle,
    TextSpanDecoratorForAttribute? attributeDecorator,
    NovidentTextSpanDecorator? spanDecorator,
  }) {
    return SpanEmitContext(
      node: Node(type: 'paragraph'),
      insert: TextInsert(text, attributes: attributes),
      displayText: text,
      style: style,
      offset: 0,
      textStyleConfiguration: const TextStyleConfiguration(),
      textSpanDecoratorForAttribute: attributeDecorator,
      textSpanDecorator: spanDecorator,
    );
  }

  SelectionContrastContext contrastContext({
    required List<InlineSpan> spans,
    int selStart = 0,
    int selEnd = 0,
  }) {
    return SelectionContrastContext(
      node: Node(type: 'paragraph'),
      insert: TextInsert('hola'),
      spans: spans,
      insertOffset: 0,
      selStart: selStart,
      selEnd: selEnd,
      textStyle: baseStyle,
      textStyleConfiguration: const TextStyleConfiguration(),
      selectionColor: Colors.blue,
      hasSelection: true,
    );
  }

  group('SpellCheckSpanPipeline.emitSpans', () {
    const pipeline = SpellCheckSpanPipeline();

    test('unmarked inserts follow the default behavior', () {
      final spans = pipeline.emitSpans(emitContext(text: 'hola'));
      expect(spans, hasLength(1));
      final span = spans.single as TextSpan;
      expect(span.style?.decoration, isNot(TextDecoration.underline));
      expect(span.style?.color, baseStyle.color);
    });

    test('marked inserts get the red wavy underline', () {
      final spans = pipeline.emitSpans(
        emitContext(
          text: 'wrld',
          attributes: {RichTextKeys.proofState: proofStateError},
        ),
      );
      expect(spans, hasLength(1));
      final span = spans.single as TextSpan;
      expect(span.text, 'wrld');
      expect(span.style?.decoration, TextDecoration.underline);
      expect(span.style?.decorationStyle, TextDecorationStyle.wavy);
      expect(span.style?.decorationColor, Colors.red);
    });

    test('original text color is preserved on marked spans', () {
      const blue = TextStyle(color: Colors.blue, fontWeight: FontWeight.bold);
      final spans = pipeline.emitSpans(
        emitContext(
          text: 'wrld',
          attributes: {RichTextKeys.proofState: proofStateError},
          style: blue,
        ),
      );
      final span = spans.single as TextSpan;
      expect(span.style?.color, Colors.blue);
      expect(span.style?.fontWeight, FontWeight.bold);
      expect(span.style?.decorationStyle, TextDecorationStyle.wavy);
    });

    test('proofState values other than "error" are ignored', () {
      for (final value in ['valid', '', null, 42]) {
        final spans = pipeline.emitSpans(
          emitContext(
            text: 'hola',
            attributes: {
              if (value != null) RichTextKeys.proofState: value,
            },
          ),
        );
        final span = spans.single as TextSpan;
        expect(
          span.style?.decoration,
          isNot(TextDecoration.underline),
          reason: 'value $value must not mark the span',
        );
      }
    });

    testWidgets('legacy decorators still apply on top of the mark', (
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

      // Legacy semantics: the whole-span decorator is applied as the
      // 'after' argument of the per-attribute decorator (see
      // DefaultNovidentTextSpanPipeline.emitSpans).
      final spans = pipeline.emitSpans(
        SpanEmitContext(
          buildContext: buildContext,
          node: Node(type: 'paragraph'),
          insert: TextInsert(
            'wrld',
            attributes: {
              RichTextKeys.proofState: proofStateError,
            },
          ),
          displayText: 'wrld',
          style: baseStyle,
          offset: 0,
          textStyleConfiguration: const TextStyleConfiguration(),
          textSpanDecorator: (span) =>
              TextSpan(text: '(${span.text})', style: span.style),
          textSpanDecoratorForAttribute: (_, __, ___, ____, before, after) =>
              after,
        ),
      );
      final span = spans.single as TextSpan;
      expect(span.text, '(wrld)');
      expect(span.style?.decorationStyle, TextDecorationStyle.wavy);
    });

    test('custom misspelled style is merged over the span', () {
      const pipeline = SpellCheckSpanPipeline(
        misspelledStyle: TextStyle(
          color: Colors.orange,
          backgroundColor: Colors.yellow,
        ),
      );
      final spans = pipeline.emitSpans(
        emitContext(
          text: 'wrld',
          attributes: {RichTextKeys.proofState: proofStateError},
        ),
      );
      final span = spans.single as TextSpan;
      expect(span.style?.color, Colors.orange);
      expect(span.style?.backgroundColor, Colors.yellow);
    });

    testWidgets('non-TextSpan results are passed through untouched', (
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

      const pipeline = SpellCheckSpanPipeline();
      final widgetSpan = const WidgetSpan(child: SizedBox(width: 8));
      final spans = pipeline.emitSpans(
        SpanEmitContext(
          buildContext: buildContext,
          node: Node(type: 'paragraph'),
          insert: TextInsert(
            'hola',
            attributes: {
              RichTextKeys.proofState: proofStateError,
            },
          ),
          displayText: 'hola',
          style: baseStyle,
          offset: 0,
          textStyleConfiguration: const TextStyleConfiguration(),
          textSpanDecoratorForAttribute: (_, __, ___, ____, before, after) =>
              widgetSpan,
        ),
      );
      expect(spans, hasLength(1));
      expect(spans.single, same(widgetSpan));
    });
  });

  group('SpellCheckSpanPipeline + selection contrast', () {
    const pipeline = SpellCheckSpanPipeline();

    test('selected marked span keeps the wavy underline with contrast color',
        () {
      final emitted = pipeline.emitSpans(
        emitContext(
          text: 'wrld',
          attributes: {RichTextKeys.proofState: proofStateError},
        ),
      );
      final result = pipeline.paintSelectionContrast(
        contrastContext(spans: emitted, selEnd: 4),
      );
      expect(result, hasLength(1));
      final span = result.single as TextSpan;
      // Contrast applied…
      expect(span.style?.color, Colors.white);
      // …mark preserved.
      expect(span.style?.decoration, TextDecoration.underline);
      expect(span.style?.decorationStyle, TextDecorationStyle.wavy);
      expect(span.style?.decorationColor, Colors.white);
    });

    test('partially selected marked span keeps the mark outside the selection',
        () {
      final emitted = pipeline.emitSpans(
        emitContext(
          text: 'wrld',
          attributes: {RichTextKeys.proofState: proofStateError},
        ),
      );
      final result = pipeline.paintSelectionContrast(
        contrastContext(spans: emitted, selStart: 1, selEnd: 3),
      );
      expect(result, hasLength(3));
      final before = result[0] as TextSpan;
      final selected = result[1] as TextSpan;
      final after = result[2] as TextSpan;
      expect(before.text, 'w');
      expect(before.style?.color, Colors.black);
      expect(before.style?.decorationStyle, TextDecorationStyle.wavy);
      expect(selected.text, 'rl');
      expect(selected.style?.color, Colors.white);
      expect(selected.style?.decorationStyle, TextDecorationStyle.wavy);
      expect(after.text, 'd');
      expect(after.style?.color, Colors.black);
      expect(after.style?.decorationStyle, TextDecorationStyle.wavy);
    });
  });

  group('EditorState wiring', () {
    test('spanPipeline is null without a spell checker', () {
      final state = EditorState.blank();
      state.editorStyle = const EditorStyle.desktop();
      expect(state.spanPipeline, isNull);
    });

    test('spanPipeline is a SpellCheckSpanPipeline with a checker', () {
      final state = EditorState.blank();
      state.editorStyle = EditorStyle.desktop(
        spellChecker: const _FakeChecker(),
      );
      expect(state.spanPipeline, isA<SpellCheckSpanPipeline>());
    });

    test('custom misspelled style flows from EditorStyle to the pipeline', () {
      final state = EditorState.blank();
      const customStyle = TextStyle(
        color: Colors.purple,
        decoration: TextDecoration.underline,
        decorationStyle: TextDecorationStyle.dashed,
      );
      state.editorStyle = EditorStyle.desktop(
        spellChecker: const _FakeChecker(),
        spellCheckMisspelledStyle: customStyle,
      );
      final pipeline = state.spanPipeline! as SpellCheckSpanPipeline;
      expect(pipeline.misspelledStyle, customStyle);
    });
  });
}
