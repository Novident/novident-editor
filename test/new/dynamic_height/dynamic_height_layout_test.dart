import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:novident_editor/novident_editor.dart';
import 'package:novident_editor/src/editor/editor_component/service/layout/block_height_reporter.dart';
import 'package:novident_editor/src/editor/editor_component/service/layout/dynamic_height_config.dart';
import 'package:novident_editor/src/editor/editor_component/service/layout/dynamic_height_controller.dart';
import 'package:novident_editor/src/editor/editor_component/service/layout/dynamic_height_layout.dart';
import 'package:provider/provider.dart';

import '../../test_helper.dart';

EditorState _buildEditor({int paragraphCount = 1, String text = 'Hello'}) {
  final document = Document.blank()
    ..insert(
      [0],
      List.generate(
        paragraphCount,
        (i) => paragraphNode(text: '$text $i'),
      ),
    );
  final editorState = EditorState(document: document)
    ..editorStyle = const EditorStyle.desktop()
    ..renderer = BlockComponentRenderer(
      builders: standardBlockComponentBuilderMap,
    );
  return editorState;
}

Widget _wrapWithProviders(EditorState editorState, Widget child) {
  return Provider<EditorState>.value(
    value: editorState,
    child: child,
  );
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('DynamicHeightLayout', () {
    testWidgets('renders blocks at minHeight when content is short', (
      tester,
    ) async {
      final editorState = _buildEditor(paragraphCount: 1);

      await tester.buildAndPump(
        _wrapWithProviders(
          editorState,
          DynamicHeightLayout(
            node: editorState.document.root,
            editorState: editorState,
            config: const DynamicHeightConfig(minHeight: 80.0),
          ),
        ),
      );
      await tester.pump();

      final renderBox = tester.renderObject(
        find.byType(DynamicHeightLayout),
      ) as RenderBox;
      expect(renderBox.size.height, greaterThanOrEqualTo(80.0));
      editorState.dispose();
    });

    testWidgets('grows when more paragraphs are added', (tester) async {
      final editorState = _buildEditor(paragraphCount: 1, text: 'A');

      await tester.buildAndPump(
        _wrapWithProviders(
          editorState,
          DynamicHeightLayout(
            node: editorState.document.root,
            editorState: editorState,
            config: const DynamicHeightConfig(minHeight: 0.0),
          ),
        ),
      );
      await tester.pump();

      final initialHeight =
          (tester.renderObject(find.byType(DynamicHeightLayout)) as RenderBox)
              .size
              .height;

      editorState.document.insert([1], [
        paragraphNode(text: 'B'),
        paragraphNode(text: 'C'),
      ]);

      await tester.pump();
      await tester.pump();

      final newHeight =
          (tester.renderObject(find.byType(DynamicHeightLayout)) as RenderBox)
              .size
              .height;

      expect(newHeight, greaterThan(initialHeight));
      editorState.dispose();
    });

    testWidgets('provides DynamicHeightController via provider', (
      tester,
    ) async {
      final controller = DynamicHeightController(
        config: const DynamicHeightConfig(minHeight: 0.0),
      );
      final editorState = _buildEditor();

      await tester.buildAndPump(
        _wrapWithProviders(
          editorState,
          DynamicHeightLayout(
            node: editorState.document.root,
            editorState: editorState,
            controller: controller,
          ),
        ),
      );

      final providerWidget =
          tester.widget<DynamicHeightControllerProvider>(
        find.byType(DynamicHeightControllerProvider),
      );
      expect(providerWidget.controller, same(controller));

      controller.dispose();
      editorState.dispose();
    });

    testWidgets('notifies controller of initial block count', (tester) async {
      final controller = DynamicHeightController(
        config: const DynamicHeightConfig(minHeight: 0.0),
      );
      final editorState = _buildEditor(paragraphCount: 5);

      await tester.buildAndPump(
        _wrapWithProviders(
          editorState,
          DynamicHeightLayout(
            node: editorState.document.root,
            editorState: editorState,
            controller: controller,
          ),
        ),
      );

      expect(controller.cache.blockCount, 5);
      controller.dispose();
      editorState.dispose();
    });

    testWidgets('header and footer are rendered', (tester) async {
      final editorState = _buildEditor();

      await tester.buildAndPump(
        _wrapWithProviders(
          editorState,
          DynamicHeightLayout(
            node: editorState.document.root,
            editorState: editorState,
            config: const DynamicHeightConfig(minHeight: 0.0),
            header: const Text('HEADER', textDirection: TextDirection.ltr),
            footer: const Text('FOOTER', textDirection: TextDirection.ltr),
          ),
        ),
      );

      expect(find.text('HEADER'), findsOneWidget);
      expect(find.text('FOOTER'), findsOneWidget);
      editorState.dispose();
    });

    testWidgets('applies maxWidth constraint from editor style', (
      tester,
    ) async {
      final editorState = _buildEditor();
      editorState.editorStyle = const EditorStyle.desktop(maxWidth: 400.0);

      await tester.buildAndPump(
        _wrapWithProviders(
          editorState,
          DynamicHeightLayout(
            node: editorState.document.root,
            editorState: editorState,
            config: const DynamicHeightConfig(minHeight: 0.0),
          ),
        ),
      );

      final containers = find.descendant(
        of: find.byType(DynamicHeightLayout),
        matching: find.byWidgetPredicate(
          (w) => w is Container && w.constraints is BoxConstraints,
        ),
      );

      final container = tester.widget<Container>(containers.first);
      final constraints = container.constraints as BoxConstraints;
      expect(constraints.maxWidth, 400.0);
      editorState.dispose();
    });

    testWidgets('disposes internal controller when owning it', (tester) async {
      DynamicHeightController? capturedController;
      final editorState = _buildEditor();

      await tester.buildAndPump(
        _wrapWithProviders(
          editorState,
          DynamicHeightLayout(
            node: editorState.document.root,
            editorState: editorState,
            config: const DynamicHeightConfig(minHeight: 0.0),
          ),
        ),
      );

      final provider = tester.widget<DynamicHeightControllerProvider>(
        find.byType(DynamicHeightControllerProvider),
      );
      capturedController = provider.controller;
      expect(capturedController, isNotNull);

      await tester.buildAndPump(const SizedBox.shrink());
      await tester.pump();

      expect(capturedController!.cache.blockCount, 0);
      editorState.dispose();
    });
  });

  group('DynamicHeightLayout real-world scenarios', () {
    testWidgets('empty editor has height at least minHeight', (tester) async {
      final editorState = EditorState.blank(withInitialText: true)
        ..editorStyle = const EditorStyle.desktop()
        ..renderer = BlockComponentRenderer(
          builders: standardBlockComponentBuilderMap,
        );

      await tester.buildAndPump(
        _wrapWithProviders(
          editorState,
          DynamicHeightLayout(
            node: editorState.document.root,
            editorState: editorState,
            config: const DynamicHeightConfig(minHeight: 200.0),
          ),
        ),
      );
      await tester.pump();

      final height =
          (tester.renderObject(find.byType(DynamicHeightLayout)) as RenderBox)
              .size
              .height;

      expect(height, greaterThanOrEqualTo(200.0));
      editorState.dispose();
    });
  });
}
