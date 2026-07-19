import 'package:example/common/controller/tree_controller.dart';
import 'package:example/common/store/document_content_store.dart';
import 'package:flutter/material.dart';
import 'package:novident_editor/novident_editor.dart' hide Node;
import 'package:novident_nodes/novident_nodes.dart';

import '../../common/nodes/file.dart';
import '../drawer/tree_view_drawer.dart';
import '../editor/document_session.dart';
import '../editor/my_editor.dart';

class AndroidTreeViewExample extends StatefulWidget {
  final TreeController controller;
  const AndroidTreeViewExample({
    super.key,
    required this.controller,
  });

  @override
  State<AndroidTreeViewExample> createState() => _AndroidTreeViewExampleState();
}

class _AndroidTreeViewExampleState extends State<AndroidTreeViewExample> {
  late final TreeController? treeController;
  bool _isFirst = true;
  bool _showNoFileToWatch = false;
  File? _lastNode;
  DocumentSession? _session;
  DocumentContentStore? _store;

  @override
  void initState() {
    treeController = widget.controller;
    super.initState();
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _store = DocumentContentProvider.of(context);
    final DocumentContentStore? store = _store;
    if (store != null) {
      _session?.syncFromStore(store);
    }
  }

  @override
  void dispose() {
    _session?.dispose();
    super.dispose();
  }

  /// Replaces the session when the watched document changes.
  ///
  /// Note: on mobile the vim emulation is disabled — its normal mode
  /// would suppress the soft keyboard input.
  void _openSession(File node) {
    _session?.dispose();
    _session = DocumentSession(
      nodeId: node.id,
      vimConfiguration: const VimModeConfiguration(enabled: false),
    )..addListener(_onSessionChanged);
    final DocumentContentStore? store = _store;
    if (store != null) {
      _session!.syncFromStore(store);
    }
  }

  void _onSessionChanged() {
    if (mounted) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) setState(() {});
      });
    }
  }

  void _onRemoveCurrentSelection() {
    _lastNode = null;
    _showNoFileToWatch = true;
    if (mounted) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        setState(() {});
      });
    }
  }

  void _handleFirstLoad() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      // Find the last node to show an example of how works this feature
      if (_isFirst) {
        _isFirst = false;
        _lastNode = treeController?.root.children.lastOrNull as File?;
        if (treeController != null && _lastNode != null) {
          widget.controller.selectNode(_lastNode);
          _openSession(_lastNode!);
        }
      }
    });
  }

  void _handleOnChangeSelection(Node? node) {
    if (_lastNode?.details == node?.details) return;
    if (node != null && node is! File) {
      _showNoFileToWatch = true;
      WidgetsBinding.instance.addPostFrameCallback((_) {
        setState(() {});
      });
      return;
    }
    _lastNode = node as File?;
    if (_lastNode != null) {
      _openSession(_lastNode!);
      if (_showNoFileToWatch) {
        _showNoFileToWatch = false;
      }
      WidgetsBinding.instance.addPostFrameCallback((_) {
        setState(() {});
      });
    }
  }

  Widget _buildEditor() {
    final DocumentSession? session = _session;
    if (session == null || !session.isReady) {
      return const SizedBox.expand();
    }
    return Column(
      children: [
        Expanded(
          child: Padding(
            padding: const EdgeInsets.only(left: 13, right: 13, top: 10),
            child: MyEditor(
              session: session,
              padding: const EdgeInsets.symmetric(
                horizontal: 8,
                vertical: 12,
              ),
            ),
          ),
        ),
        MobileToolbar(
          editorState: session.editorState,
          toolbarItems: [
            textDecorationMobileToolbarItem,
            headingMobileToolbarItem,
            todoListMobileToolbarItem,
            listMobileToolbarItem,
            linkMobileToolbarItem,
            quoteMobileToolbarItem,
            codeMobileToolbarItem,
          ],
        ),
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    final Size size = MediaQuery.sizeOf(context);
    _handleFirstLoad();
    return Scaffold(
      appBar: AppBar(
        backgroundColor: Theme.of(context).colorScheme.inversePrimary,
        title: Text(_lastNode?.name ?? 'No name'),
      ),
      drawer: TreeViewDrawer(
        controller: widget.controller,
      ),
      body: ValueListenableBuilder(
          valueListenable: widget.controller.selection,
          builder: (ctx, value, _) {
            if (value == null) {
              _onRemoveCurrentSelection();
            } else {
              _handleOnChangeSelection(value);
            }
            return _showNoFileToWatch
                ? SizedBox(
                    width: size.width * 0.90,
                    height: size.height * 0.90,
                    child: const Center(
                      child: Text(
                        'There\'s no File to watch...',
                        style: TextStyle(
                          fontSize: 28,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                    ),
                  )
                : _buildEditor();
          }),
    );
  }
}
