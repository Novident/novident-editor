import 'package:example/common/nodes/file.dart';
import 'package:example/common/store/document_content_store.dart';
import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:novident_editor/novident_editor.dart';
import 'package:novident_split_view/novident_split_view.dart';

import 'document_session.dart';
import 'my_editor.dart';
import 'vim_mode_chip.dart';
import 'word_count_chip.dart';
import 'zen_editor_view.dart';

/// A self-contained editor pane for the split view.
///
/// Every pane owns its own [DocumentSession] (editor, scroll, focus and
/// vim state), but the document content lives in the
/// [DocumentContentProvider] (keyed by node id): edits are written there,
/// the provider notifies, and every pane showing the same document re-reads
/// it — duplicated panes stay in sync for free, with no extra wiring.
class EditorPane extends StatefulWidget {
  final File file;
  final bool isFocused;
  final FocusedEditorNotifier toolbarNotifier;
  final NovidentStylesConfig? styles;

  const EditorPane({
    required this.file,
    required this.isFocused,
    required this.toolbarNotifier,
    this.styles,
    super.key,
  });

  @override
  State<EditorPane> createState() => _EditorPaneState();
}

class _EditorPaneState extends State<EditorPane> {
  late DocumentSession _session;

  @override
  void initState() {
    super.initState();
    _session = _createSession();
    // Notify the toolbar after the first frame so it picks up the
    // editor state even when the pane gains focus asynchronously
    // (e.g. via SplitController.open / focusPane).
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) _notifyToolbar();
    });
  }

  DocumentSession _createSession() {
    return DocumentSession(nodeId: widget.file.id)
      ..addListener(_onSessionChanged);
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _session.syncFromStore(DocumentContentProvider.of(context));
  }

  @override
  void didUpdateWidget(covariant EditorPane oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.file.id != widget.file.id) {
      _session.dispose();
      _session = _createSession()
        ..syncFromStore(DocumentContentProvider.of(context));
    }
    if (oldWidget.isFocused != widget.isFocused) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) _notifyToolbar();
      });
    }
  }

  @override
  void dispose() {
    _session.dispose();
    super.dispose();
  }

  void _sessionChanged() {
    if (_session.isReady && widget.isFocused) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) _notifyToolbar();
      });
    }
  }

  void _notifyToolbar() {
    if (widget.isFocused && _session.isReady) {
      widget.toolbarNotifier.value = _session.editorState;
    } else if (!widget.isFocused &&
        widget.toolbarNotifier.value == _session.editorState) {
      widget.toolbarNotifier.value = null;
    }
  }

  void _onSessionChanged() {
    _sessionChanged();
    if (mounted) setState(() {});
  }

  /// Leading icon of the library's [PaneHeader]: the title, the close
  /// button and the focused tint come for free (SplitViewScope).
  Widget _buildLeadingIcon() {
    return Icon(
      CupertinoIcons.doc_text_fill,
      size: 14,
      color: widget.isFocused ? const Color(0xFF448AFF) : Colors.grey.shade600,
    );
  }

  void _openZenMode() {
    Navigator.of(context).push(
      MaterialPageRoute<void>(
        builder: (_) => ZenEditorView(file: widget.file),
      ),
    );
  }

  /// Slim status bar at the bottom of the sheet: vim mode on the left,
  /// the zen mode toggle on the right.
  Widget _buildStatusBar() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12),
      height: 30,
      decoration: const BoxDecoration(
        border: Border(top: BorderSide(color: Color(0x14000000))),
      ),
      child: Row(
        children: <Widget>[
          VimModeChip(controller: _session.vimController),
          const Spacer(),
          WordCountChip(service: _session.wordCounter),
          const SizedBox(width: 10),
          IconButton(
            padding: EdgeInsets.zero,
            constraints: const BoxConstraints.tightFor(width: 26, height: 26),
            iconSize: 15,
            tooltip: 'Zen mode',
            icon: Icon(
              CupertinoIcons.moon_stars,
              color: Colors.grey.shade600,
            ),
            onPressed: _openZenMode,
          ),
        ],
      ),
    );
  }

  /// White "sheet of paper" centered over the gray workspace.
  Widget _buildPage() {
    return Center(
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 750),
        child: Container(
          margin: const EdgeInsets.fromLTRB(16, 0, 16, 0),
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
                  children: <Widget>[
                    Expanded(
                      child: Padding(
                        padding: const EdgeInsets.only(top: 15),
                        child: MyEditor(
                          session: _session,
                          styles: widget.styles,
                        ),
                      ),
                    ),
                    _buildStatusBar(),
                  ],
                ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    if (widget.isFocused && _session.isReady) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) _notifyToolbar();
      });
    }
    return PaneHeader(
      // Drag the header to move this pane anywhere (center = swap).
      draggable: true,
      leading: _buildLeadingIcon(),
      title: Text(widget.file.name),
      child: _buildPage(),
    );
  }
}
