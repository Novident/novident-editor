import 'package:example/common/nodes/directory.dart';
import 'package:example/common/nodes/file.dart';
import 'package:example/common/store/document_content_store.dart';
import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:novident_editor/novident_editor.dart';

import '../editor/document_session.dart';
import '../editor/my_editor.dart';

/// White "sheet of paper" centered over the gray workspace —
/// same visual design as [EditorPane._buildPage].
const Color _kWorkspaceBackground = Color(0xFFECECEC);

/// Scrollable column of editor sheets — one per [File] node inside
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

  /// One editor sheet — same design as [EditorPane._buildPage].
  Widget _buildFileSheet(BuildContext context, File file) {
    return _FileSheet(key: ValueKey(file.id), file: file);
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      color: _kWorkspaceBackground,
      child: SingleChildScrollView(
        padding: const EdgeInsets.symmetric(vertical: 12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: _files.map((f) => _buildFileSheet(context, f)).toList(),
        ),
      ),
    );
  }
}

/// One editor sheet per file.
///
/// Uses [DocumentSession] (same pattern as [EditorPane]) but without
/// vim/word count/zen mode. The editor grows vertically via
/// [DynamicHeightConfig].
class _FileSheet extends StatefulWidget {
  final File file;

  const _FileSheet({super.key, required this.file});

  @override
  State<_FileSheet> createState() => _FileSheetState();
}

class _FileSheetState extends State<_FileSheet> {
  late DocumentSession _session;

  @override
  void initState() {
    super.initState();
    _session = DocumentSession(nodeId: widget.file.id)
      ..addListener(_onSessionChanged);
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _session.syncFromStore(DocumentContentProvider.of(context));
  }

  @override
  void didUpdateWidget(covariant _FileSheet oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.file.id != widget.file.id) {
      _session.dispose();
      _session = DocumentSession(nodeId: widget.file.id)
        ..addListener(_onSessionChanged)
        ..syncFromStore(DocumentContentProvider.of(context));
    }
  }

  @override
  void dispose() {
    _session.dispose();
    super.dispose();
  }

  void _onSessionChanged() {
    if (mounted) setState(() {});
  }

  @override
  Widget build(BuildContext context) => _buildPage(context);

  Icon _buildLeadingIcon() {
    return Icon(
      CupertinoIcons.doc_text_fill,
      size: 14,
      color: Colors.grey.shade600,
    );
  }

  /// White "sheet of paper" centered over the gray workspace —
  /// identical structure to [EditorPane._buildPage].
  Widget _buildPage(BuildContext context) {
    return Center(
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 750),
        child: Container(
          margin: const EdgeInsets.fromLTRB(16, 0, 16, 12),
          clipBehavior: Clip.antiAlias,
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(3),
            boxShadow: const <BoxShadow>[
              BoxShadow(
                color: Color(0x33000000),
                blurRadius: 14,
                offset: Offset(0, 4),
              ),
              BoxShadow(
                color: Color(0x14000000),
                blurRadius: 3,
                offset: Offset(0, 1),
              ),
            ],
          ),
          child: !_session.isReady
              ? const SizedBox.expand()
              : Column(
                  mainAxisSize: MainAxisSize.min,
                  children: <Widget>[
                    Padding(
                      padding: const EdgeInsets.fromLTRB(16, 15, 16, 0),
                      child: Row(
                        children: <Widget>[
                          _buildLeadingIcon(),
                          const SizedBox(width: 8),
                          Expanded(
                            child: Text(
                              widget.file.name,
                              style: const TextStyle(
                                fontSize: 13,
                                fontWeight: FontWeight.w500,
                                color: Colors.black87,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  Padding(
                    padding: const EdgeInsets.only(top: 8),
                    child: MyEditor(
                      session: _session,
                      padding: const EdgeInsets.symmetric(
                        horizontal: 32,
                        vertical: 0,
                      ),
                      dynamicHeightConfig: const DynamicHeightConfig(
                        minHeight: 80,
                      ),
                    ),
                  ),
                  _buildSheetStatusBar(context),
                  ],
                ),
        ),
      ),
    );
  }

  /// Slim status bar — close button on the right.
  Widget _buildSheetStatusBar(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12),
      height: 30,
      decoration: const BoxDecoration(
        border: Border(top: BorderSide(color: Color(0x14000000))),
      ),
      child: Row(
        children: <Widget>[
          const Spacer(),
          IconButton(
            padding: EdgeInsets.zero,
            constraints: const BoxConstraints.tightFor(width: 26, height: 26),
            iconSize: 15,
            tooltip: 'Cerrar modo múltiple',
            icon: Icon(
              CupertinoIcons.xmark_circle,
              color: Colors.grey.shade600,
            ),
            onPressed: () {
              final store = DocumentContentProvider.of(context);
              store.multiEditDirectoryId.value = null;
            },
          ),
        ],
      ),
    );
  }
}
