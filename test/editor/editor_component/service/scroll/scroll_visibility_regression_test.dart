/// Red de seguridad de regresión para la migración
/// ScrollablePositionedList -> scroll_spy.
///
/// Estos tests SIEMPRE deben pasar. Si fallan, rompimos algo en el pipeline de
/// scroll/visibilidad del editor.
///
/// Cubren: correctitud del rango visible, offset, saltos programáticos,
/// errores (documento vacío, mutación/dispose durante scroll, índices fuera de
/// rango) y rendimiento (coalescing a 1 notificación por frame, trabajo
/// acotado por items montados).
///
/// NOTA DE MIGRACIÓN: el test marcado con `PORT-TO-SCROLL-SPY` usa
/// `itemPositionsListener` (API que la Fase 1 elimina). Debe portarse al
/// equivalente scroll_spy (`visibleIds`/`visibleRange`) en la misma fase que se
/// elimine la API. Los demás tests usan solo la API pública de
/// `EditorScrollController` y deben pasar sin modificación antes y después.
import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:novident_editor/novident_editor.dart';
import 'package:novident_editor/src/editor/editor_component/service/selection/shared.dart';

import '../../../../new/util/document_util.dart';

void main() {
  group('Scroll visibility regression', () {
    testWidgets('empty document renders without crash and reports no range',
        (tester) async {
      final h = _ScrollRegressionHarness(tester);
      await h.start(paragraphs: 0);

      expect(tester.takeException(), isNull);
      expect(h.scrollController.visibleRangeNotifier.value, (-1, -1));

      await h.dispose();
    });

    testWidgets('visible range starts at the first node at the top',
        (tester) async {
      final h = _ScrollRegressionHarness(tester);
      await h.start(paragraphs: 50);

      final (min, max) = h.scrollController.visibleRangeNotifier.value;
      expect(min, 0, reason: 'at the top the first node must be visible');
      expect(max, greaterThanOrEqualTo(0));
      expect(max, lessThan(50));

      await h.dispose();
    });

    testWidgets('visible range ends at the last node at the bottom',
        (tester) async {
      final h = _ScrollRegressionHarness(tester);
      await h.start(paragraphs: 50);

      h.scrollController.jumpToBottom();
      await tester.pump();
      await tester.pump();

      final (min, max) = h.scrollController.visibleRangeNotifier.value;
      expect(max, 49, reason: 'at the bottom the last node must be visible');
      expect(min, lessThanOrEqualTo(49));

      await h.dispose();
    });

    testWidgets('visible range is a contiguous interval within document bounds',
        (tester) async {
      final h = _ScrollRegressionHarness(tester);
      await h.start(paragraphs: 50);

      // Scroll al 50% del máximo real (los offsets absolutos dependen de la
      // altura de los bloques, que varía con el estilo del editor).
      h.scrollController.scrollOffsetController.jumpTo(
        offset: h.maxScrollExtent * 0.5,
      );
      await tester.pump();
      await tester.pump();

      final (min, max) = h.scrollController.visibleRangeNotifier.value;
      expect(min, greaterThanOrEqualTo(0));
      expect(max, lessThan(50));
      expect(min, lessThanOrEqualTo(max));

      await h.dispose();
    });

    testWidgets('header and footer are excluded from the visible range',
        (tester) async {
      final h = _ScrollRegressionHarness(tester);
      await h.start(paragraphs: 50, header: true, footer: true);

      // At the top: the header occupies list index 0; the range must still
      // start at node 0 (not the header) and never exceed the last node.
      final (minTop, maxTop) = h.scrollController.visibleRangeNotifier.value;
      expect(minTop, 0);
      expect(maxTop, lessThan(50));

      h.scrollController.jumpToBottom();
      await tester.pump();
      await tester.pump();

      final (minBottom, maxBottom) =
          h.scrollController.visibleRangeNotifier.value;
      expect(maxBottom, 49, reason: 'footer must not leak into the range');
      expect(minBottom, lessThanOrEqualTo(49));

      await h.dispose();
    });

    testWidgets('offsetNotifier tracks the real scroll offset', (tester) async {
      final h = _ScrollRegressionHarness(tester);
      await h.start(paragraphs: 50);

      h.scrollController.scrollOffsetController.jumpTo(offset: 200);
      await tester.pump();

      expect(h.scrollController.offsetNotifier.value, closeTo(200, 1.0));

      await h.dispose();
    });

    testWidgets('animateTo clamps negative offsets to zero', (tester) async {
      final h = _ScrollRegressionHarness(tester);
      await h.start(paragraphs: 50);

      await h.scrollController.animateTo(
        offset: -100,
        duration: const Duration(milliseconds: 100),
      );
      await tester.pumpAndSettle();

      expect(h.scrollController.offsetNotifier.value, closeTo(0, 1.0));

      await h.dispose();
    });

    testWidgets('jumpTo(index) brings the index into the visible range',
        (tester) async {
      final h = _ScrollRegressionHarness(tester);
      await h.start(paragraphs: 50);

      h.scrollController.jumpTo(offset: 30);
      await tester.pump();
      await tester.pump();

      final (min, max) = h.scrollController.visibleRangeNotifier.value;
      expect(min, lessThanOrEqualTo(30));
      expect(max, greaterThanOrEqualTo(30));

      await h.dispose();
    });

    testWidgets('getVisibleNodes returns nodes bounded by the visible range',
        (tester) async {
      final h = _ScrollRegressionHarness(tester);
      await h.start(paragraphs: 50);

      h.scrollController.scrollOffsetController.jumpTo(
        offset: h.maxScrollExtent * 0.5,
      );
      await tester.pump();
      await tester.pump();

      final (min, max) = h.scrollController.visibleRangeNotifier.value;
      final nodes = h.editorState.getVisibleNodes(h.scrollController);
      final children = h.editorState.document.root.children;
      final indices = nodes.map(children.indexOf).toList();

      // getVisibleNodes aplica el slack min-1 (issue #3651).
      final expectedMin = (min - 1).clamp(0, 49);
      expect(indices, isNotEmpty);
      expect(indices.first, greaterThanOrEqualTo(expectedMin));
      expect(indices.last, lessThanOrEqualTo(max));
      expect(indices, orderedEquals(indices.toList()..sort()));

      await h.dispose();
    });

    testWidgets('visible range advances monotonically while scrolling down',
        (tester) async {
      final h = _ScrollRegressionHarness(tester);
      await h.start(paragraphs: 50);

      var lastMin = h.scrollController.visibleRangeNotifier.value.$1;
      final maxExtent = h.maxScrollExtent;
      for (var fraction = 0.1; fraction <= 0.9; fraction += 0.1) {
        h.scrollController.scrollOffsetController.jumpTo(
          offset: maxExtent * fraction,
        );
        await tester.pump();
        await tester.pump();

        final (min, max) = h.scrollController.visibleRangeNotifier.value;
        expect(min, greaterThanOrEqualTo(lastMin),
            reason: 'scrolling down must never move the range upward');
        expect(max, lessThan(50));
        lastMin = min;
      }

      await h.dispose();
    });

    testWidgets('PERF: at most one visible-range notification per frame',
        (tester) async {
      final h = _ScrollRegressionHarness(tester);
      await h.start(paragraphs: 50);

      var notifications = 0;
      h.scrollController.visibleRangeNotifier.addListener(() {
        notifications++;
      });

      // Reset: el listener se adjuntó después de los pumps iniciales.
      notifications = 0;
      final maxExtent = h.maxScrollExtent;
      for (var fraction = 0.1; fraction <= 0.9; fraction += 0.1) {
        h.scrollController.scrollOffsetController.jumpTo(
          offset: maxExtent * fraction,
        );
        await tester.pump();
        // El post-frame callback coalesce: a lo sumo 1 notificación por frame.
        expect(notifications, lessThanOrEqualTo(1),
            reason: 'visible range must coalesce to at most one '
                'notification per frame (fraction $fraction)');
        notifications = 0;
        await tester.pump();
        notifications = 0;
      }

      await h.dispose();
    });

    testWidgets(
        'PERF: published positions are bounded by mounted items, '
        'not document size', (tester) async {
      // PORT-TO-SCROLL-SPY: este test usa itemPositionsListener, API que la
      // Fase 1 elimina. Portar al equivalente scroll_spy (visibleIds) en la
      // misma fase. El invariante NO cambia: el trabajo por frame del pipeline
      // de visibilidad debe estar acotado por items montados, nunca por el
      // tamaño del documento.
      final h = _ScrollRegressionHarness(tester);
      await h.start(paragraphs: 500, viewport: const Size(800, 400));

      h.scrollController.scrollOffsetController.jumpTo(
        offset: h.maxScrollExtent * 0.5,
      );
      await tester.pump();
      await tester.pump();

      final positions =
          h.scrollController.itemPositionsListener.itemPositions.value;
      expect(positions.length, lessThanOrEqualTo(50),
          reason: 'positions published per frame must be bounded by mounted '
              'items, not the 500-node document');

      await h.dispose();
    });

    testWidgets('document mutation while scrolled does not crash',
        (tester) async {
      final h = _ScrollRegressionHarness(tester);
      await h.start(paragraphs: 50);

      h.scrollController.scrollOffsetController.jumpTo(
        offset: h.maxScrollExtent * 0.5,
      );
      await tester.pump();
      await tester.pump();

      // Insert a node at the top: shifts every index.
      h.editorState.document.insert([0], [paragraphNode()]);
      await tester.pump();
      await tester.pump();

      expect(tester.takeException(), isNull);
      final (min, max) = h.scrollController.visibleRangeNotifier.value;
      expect(min, greaterThanOrEqualTo(0));
      expect(max, lessThan(51));

      await h.dispose();
    });

    testWidgets('dispose while scrolled does not crash', (tester) async {
      final h = _ScrollRegressionHarness(tester);
      await h.start(paragraphs: 50);

      h.scrollController.scrollOffsetController.jumpTo(
        offset: h.maxScrollExtent * 0.5,
      );
      await tester.pump();
      await tester.pump();

      // Ciclo de vida correcto: el widget se desmonta ANTES de disponer el
      // controller (el widget es el dueño del ciclo de vida del scroll).
      await tester.pumpWidget(const SizedBox());
      h.scrollController.dispose();
      await tester.pump();

      expect(tester.takeException(), isNull);

      await h.dispose();
    });

    testWidgets('jumpTo with out-of-range index clamps without crashing',
        (tester) async {
      final h = _ScrollRegressionHarness(tester);
      await h.start(paragraphs: 50);

      h.scrollController.jumpTo(offset: 9999);
      await tester.pump();
      await tester.pump();

      expect(tester.takeException(), isNull);
      final (min, max) = h.scrollController.visibleRangeNotifier.value;
      expect(min, greaterThanOrEqualTo(0));
      expect(max, lessThan(50));

      await h.dispose();
    });
  });
}

/// Harness mínimo para tests de scroll con acceso al EditorScrollController.
///
/// Usa la API pública de NovidentEditor con un viewport de tamaño fijo para
/// que el comportamiento de scroll sea determinista.
class _ScrollRegressionHarness {
  _ScrollRegressionHarness(this.tester);

  final WidgetTester tester;

  late EditorState editorState;
  late EditorScrollController scrollController;

  /// Máximo scroll real del listado principal del editor.
  double get maxScrollExtent {
    final scrollable = tester.state<ScrollableState>(
      find.descendant(
        of: find.byType(NovidentEditor),
        matching: find.byType(Scrollable),
      ).first,
    );
    return scrollable.position.maxScrollExtent;
  }

  Future<void> start({
    int paragraphs = 50,
    bool header = false,
    bool footer = false,
    Size viewport = const Size(800, 400),
  }) async {
    await NovidentEditorLocalizations.load(const Locale('en'));
    editorState = EditorState.blank(withInitialText: false);
    if (paragraphs > 0) {
      editorState.document.addParagraphs(paragraphs);
    }
    scrollController = EditorScrollController(editorState: editorState);

    await tester.pumpWidget(
      MaterialApp(
        localizationsDelegates: const [
          GlobalMaterialLocalizations.delegate,
          GlobalCupertinoLocalizations.delegate,
          GlobalWidgetsLocalizations.delegate,
          NovidentEditorLocalizations.delegate,
        ],
        supportedLocales: NovidentEditorLocalizations.delegate.supportedLocales,
        home: Scaffold(
          body: Center(
            child: SizedBox(
              width: viewport.width,
              height: viewport.height,
              child: NovidentEditor(
                editorState: editorState,
                editorScrollController: scrollController,
                header: header ? const SizedBox(height: 40) : null,
                footer: footer ? const SizedBox(height: 40) : null,
              ),
            ),
          ),
        ),
      ),
    );
    // Frame 1: build del listado. Frame 2: update post-frame de posiciones.
    await tester.pump();
    await tester.pump();
  }

  /// Vacía callbacks post-frame pendientes (BlockHeightReporter, updates de
  /// posiciones) antes de que el framework desmonte el árbol.
  ///
  /// No se dispone el controller ni el editorState: el framework desmonta el
  /// árbol automáticamente al final de cada testWidgets (convención de
  /// TestableEditor).
  Future<void> dispose() async {
    await tester.pumpAndSettle();
  }
}
