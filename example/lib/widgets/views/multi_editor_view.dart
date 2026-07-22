import 'dart:async';
import 'dart:convert';

import 'package:example/common/nodes/directory.dart';
import 'package:example/common/nodes/file.dart';
import 'package:example/common/store/document_content_store.dart';
import 'package:flutter/material.dart';
import 'package:novident_editor/novident_editor.dart';

/// Scrollable column of editors — one per [File] node inside
/// a [Directory].
///
/// Activated by right-clicking a directory in the tree binder
/// and choosing "Modo múltiple".
class MultiEditorView extends StatefulWidget {
  final DocumentContentStore store;
  final Directory directory;

  const MultiEditorView({
    super.key,
    required this.store,
    required this.directory,
  });

  @override
  State<MultiEditorView> createState() => _MultiEditorViewState();
}

class _MultiEditorViewState extends State<MultiEditorView> {
  List<File> _files = [];

  @override
  void initState() {
    super.initState();
    _updateFiles();
    widget.store.addListener(_onStoreChanged);
  }

  @override
  void didUpdateWidget(covariant MultiEditorView oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.directory.id != widget.directory.id) {
      _updateFiles();
    }
  }

  @override
  void dispose() {
    widget.store.removeListener(_onStoreChanged);
    super.dispose();
  }

  void _onStoreChanged() {
    if (mounted) setState(() {});
  }

  void _updateFiles() {
    _files = widget.directory.children.whereType<File>().toList(growable: false);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text('${_nodeName(widget.directory)} — Modo múltiple'),
        actions: [
          IconButton(
            icon: const Icon(Icons.close),
            tooltip: 'Cerrar modo múltiple',
            onPressed: () => widget.store.multiEditDirectoryId.value = null,
          ),
        ],
      ),
      body: ListView.builder(
        itemCount: _files.length,
        itemBuilder: (context, index) => _FileEditorTile(
          key: ValueKey(_files[index].id),
          node: _files[index],
          store: widget.store,
        ),
      ),
    );
  }

  String _nodeName(Directory dir) => dir.name;
}

/// One editor row in the multi-editor view: filename title + divider
/// + [NovidentEditor] with dynamic height.
class _FileEditorTile extends StatefulWidget {
  final File node;
  final DocumentContentStore store;

  const _FileEditorTile({
    super.key,
    required this.node,
    required this.store,
  });

  @override
  State<_FileEditorTile> createState() => _FileEditorTileState();
}

class _FileEditorTileState extends State<_FileEditorTile> {
  late EditorState _editorState;
  StreamSubscription? _subscription;
  Timer? _saveTimer;

  @override
  void initState() {
    super.initState();
    _initEditor();
  }

  @override
  void dispose() {
    _saveTimer?.cancel();
    _subscription?.cancel();
    _editorState.dispose();
    super.dispose();
  }

  void _initEditor() {
    final content = widget.store.contentOf(widget.node.id);
    final document =
        Document.fromJson(jsonDecode(content) as Map<String, dynamic>);

    _editorState = EditorState(document: document)
      ..editorStyle = const EditorStyle.desktop(
        padding: EdgeInsets.symmetric(horizontal: 20, vertical: 2),
        textStyleConfiguration: TextStyleConfiguration(
          text: TextStyle(fontSize: 12),
        ),
      );

    _subscription = _editorState.transactionStream.listen((_) {
      _debouncedSave();
    });
  }

  void _debouncedSave() {
    _saveTimer?.cancel();
    _saveTimer = Timer(const Duration(milliseconds: 100), _save);
  }

  void _save() {
    widget.store.setContent(
      widget.node.id,
      jsonEncode(_editorState.document.toJson()),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      mainAxisSize: MainAxisSize.min,
      children: [
        const SizedBox(height: 8),
        Padding(
          padding: const EdgeInsets.only(left: 20, right: 20),
          child: Text(
            widget.node.name,
            style: const TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.w600,
              color: Colors.black54,
            ),
          ),
        ),
        const Divider(height: 1, thickness: 1),
        NovidentEditor(
          editorState: _editorState,
          dynamicHeightConfig: const DynamicHeightConfig(minHeight: 50),
          editorStyle: const EditorStyle.desktop(
            padding: EdgeInsets.symmetric(horizontal: 20, vertical: 2),
            textStyleConfiguration: TextStyleConfiguration(
              text: TextStyle(fontSize: 12),
            ),
          ),
        ),
        const SizedBox(height: 16),
      ],
    );
  }
}
