import 'dart:io';
import 'package:example/common/controller/tree_controller.dart';
import 'package:example/common/constants/default_files_nodes.dart';
import 'package:example/common/nodes/root.dart';
import 'package:example/common/store/document_content_store.dart';
import 'package:example/widgets/views/android_view.dart';
import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:novident_editor/novident_editor.dart'
    show NovidentEditorLocalizations;
import 'package:novident_split_view/novident_split_view.dart';
import 'widgets/views/desktop_view.dart';

void main() {
  runApp(const MyApp());
}

class MyApp extends StatefulWidget {
  const MyApp({super.key});

  @override
  State<MyApp> createState() => _MyAppState();
}

class _MyAppState extends State<MyApp> {
  final TreeController _controller = TreeController(
    root: Root(
      children: defaultNodes,
    ),
  );

  /// Split view weights (pane sizes) live above the MaterialApp so they
  /// survive navigation and rebuilds. Feed [SplitViewWeights.new] with
  /// persisted values to restore pane sizes between sessions.
  final SplitViewWeights _splitWeights = SplitViewWeights();

  /// Single source of truth for every document's content (node id →
  /// content). Panes sharing a document read/write here and stay in
  /// sync automatically.
  final DocumentContentStore _documentContents = DocumentContentStore(
    initialContents: defaultDocumentContents,
  );

  @override
  Widget build(BuildContext context) {
    return SplitViewProvider(
      weights: _splitWeights,
      child: DocumentContentProvider(
        store: _documentContents,
        child: MaterialApp(
          title: 'Novident',
          theme: ThemeData(
            colorScheme: ColorScheme.fromSeed(seedColor: Colors.blueGrey),
            useMaterial3: true,
          ),
          debugShowCheckedModeBanner: false,
          localizationsDelegates: const [
            NovidentEditorLocalizations.delegate,
            GlobalMaterialLocalizations.delegate,
            GlobalWidgetsLocalizations.delegate,
            GlobalCupertinoLocalizations.delegate,
          ],
          debugShowMaterialGrid: false,
          home: MiddlewareView(controller: _controller),
        ),
      ),
    );
  }
}

class MiddlewareView extends StatelessWidget {
  final TreeController controller;
  const MiddlewareView({
    super.key,
    required this.controller,
  });

  @override
  Widget build(BuildContext context) {
    if (Platform.isAndroid || Platform.isIOS || Platform.isFuchsia) {
      return AndroidTreeViewExample(controller: controller);
    }
    return DesktopTreeViewExample(controller: controller);
  }
}
