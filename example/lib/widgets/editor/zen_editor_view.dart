import 'package:example/common/nodes/file.dart';
import 'package:example/common/store/document_content_store.dart';
import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:novident_editor/novident_editor.dart';

import 'document_session.dart';
import 'my_editor.dart';
import 'vim_mode_chip.dart';
import 'word_count_chip.dart';

/// Workspace colors (kept in sync with the desktop view).
const Color _kWorkspaceBackground = Color(0xFFECECEC);

/// Distraction-free writing view.
///
/// While zen mode is active everything that is not the centered editor
/// disappears: no binder, no split view, no pane headers — only the
/// sheet of paper over the workspace.
///
/// * unfocused blocks are dimmed and text colors are ignored (see
///   [ZenModeConfiguration]);
/// * the focused block stays vertically centered (typewriter scrolling);
/// * vim mode keeps working (it is enabled by default app-wide);
/// * the content is read/written through the shared
///   [DocumentContentStore], so the panes behind stay in sync.
class ZenEditorView extends StatefulWidget {
  const ZenEditorView({super.key, required this.file});

  final File file;

  @override
  State<ZenEditorView> createState() => _ZenEditorViewState();
}

class _ZenEditorViewState extends State<ZenEditorView> {
  late final DocumentSession _session;

  @override
  void initState() {
    super.initState();
    _session = DocumentSession(
      nodeId: widget.file.id,
      zenController: ZenModeController(
        configuration: const ZenModeConfiguration(
          unfocusedOpacity: 0.3,
        ),
      ),
    )..addListener(_onSessionChanged);
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _session.syncFromStore(DocumentContentProvider.of(context));
  }

  @override
  void dispose() {
    _session.dispose();
    super.dispose();
  }

  void _onSessionChanged() {
    if (mounted) {
      setState(() {});
    }
  }

  void _exitZenMode() => Navigator.of(context).pop();

  /// Same status bar language as the panes: vim mode on the left, the
  /// (active) zen toggle on the right.
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
            tooltip: 'Exit zen mode',
            icon: const Icon(
              CupertinoIcons.moon_stars_fill,
              color: Color(0xFF448AFF),
            ),
            onPressed: _exitZenMode,
          ),
        ],
      ),
    );
  }

  /// The centered sheet of paper — the only thing on screen.
  Widget _buildSheet() {
    return Center(
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 750),
        child: Container(
          margin: const EdgeInsets.fromLTRB(24, 0, 24, 0),
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
                          zenController: _session.zenController,
                          autoFocus: true,
                          padding: const EdgeInsets.symmetric(
                            horizontal: 32,
                            vertical: 7,
                          ),
                          // room to keep the last paragraphs centerable.
                          footer: const SizedBox(height: 320),
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
    return Scaffold(
      backgroundColor: _kWorkspaceBackground,
      body: Stack(
        children: <Widget>[
          _buildSheet(),
          // discreet exit affordance, out of the writing area.
          Positioned(
            top: 14,
            right: 18,
            child: Material(
              color: Colors.white,
              elevation: 2,
              shape: const CircleBorder(),
              child: IconButton(
                iconSize: 16,
                tooltip: 'Exit zen mode',
                icon: Icon(
                  CupertinoIcons.fullscreen_exit,
                  color: Colors.grey.shade700,
                ),
                onPressed: _exitZenMode,
              ),
            ),
          ),
        ],
      ),
    );
  }
}
