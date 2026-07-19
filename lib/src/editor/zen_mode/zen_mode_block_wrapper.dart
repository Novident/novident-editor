import 'package:novident_editor/novident_editor.dart';
import 'package:flutter/foundation.dart' show ValueListenable;
import 'package:flutter/material.dart';

/// Wraps a top-level block component and dims it while zen mode is enabled
/// and the block is not focused.
///
/// Designed to be created through `ZenModeController.blockWrapper`, which
/// plugs into [NovidentEditor.blockWrapper].
///
/// The widget listens to both the editor selection and the zen
/// configuration, so opacity updates don't rebuild the wrapped block —
/// [child] is passed through untouched.
class ZenModeBlockWrapper extends StatelessWidget {
  const ZenModeBlockWrapper({
    super.key,
    required this.editorState,
    required this.configuration,
    required this.node,
    required this.child,
  });

  final EditorState editorState;

  /// The zen mode configuration source, usually a `ZenModeController`.
  final ValueListenable<ZenModeConfiguration> configuration;

  /// The top-level node wrapped by this widget.
  final Node node;

  final Widget child;

  /// Returns true if the top-level [node] contains the current [selection].
  ///
  /// A top-level block is considered focused when the selection starts,
  /// ends or passes through it — including when the cursor is inside one of
  /// its nested children (e.g. an indented list item).
  static bool isTopLevelNodeFocused({
    required Node node,
    required Selection? selection,
  }) {
    if (selection == null) {
      return false;
    }
    final path = node.path;
    if (path.isEmpty) {
      return false;
    }
    final normalized = selection.normalized;
    if (normalized.start.path.isEmpty || normalized.end.path.isEmpty) {
      return false;
    }
    final index = path.first;
    return normalized.start.path.first <= index &&
        index <= normalized.end.path.first;
  }

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: Listenable.merge([
        editorState.selectionNotifier,
        configuration,
      ]),
      // the child is passed through, so selection changes only re-evaluate
      // the opacity value instead of rebuilding the whole block subtree.
      child: child,
      builder: (context, child) {
        final config = configuration.value;
        final selection = editorState.selection;
        final dimmed = config.enabled &&
            selection != null &&
            !isTopLevelNodeFocused(node: node, selection: selection);
        return AnimatedOpacity(
          opacity: dimmed ? config.unfocusedOpacity : 1.0,
          duration: config.fadeDuration,
          curve: config.fadeCurve,
          child: child,
        );
      },
    );
  }
}
