import 'package:novident_editor_core/novident_editor_core.dart';
import 'package:novident_editor_document/novident_editor_document.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:novident_editor_selection/novident_editor_selection.dart';

class BlockSelectionContainer extends StatelessWidget {
  const BlockSelectionContainer({
    super.key,
    required this.node,
    required this.delegate,
    required this.listenable,
    required this.host,
    this.renderer,
    this.remoteSelection,
    this.cursorColor = Colors.black,
    this.selectionColor = Colors.blue,
    this.blockColor = Colors.blue,
    this.supportTypes = const [
      BlockSelectionType.cursor,
      BlockSelectionType.selection,
    ],
    this.selectionAboveBlock = false,
    required this.child,
  });

  // get the cursor rect, selection rects or block rect from the delegate
  final SelectableMixin delegate;

  /// Host providing editor-level state for selection rendering.
  final BlockSelectionHost host;

  /// Custom selection/cursor renderer. Defaults to [DefaultSelectionRenderer].
  final SelectionRenderer? renderer;

  // get the selection from the listenable
  final ValueListenable<Selection?> listenable;

  // remote selection
  final ValueListenable<List<RemoteSelection>>? remoteSelection;

  // the color of the cursor
  final Color cursorColor;

  // the color of the selection
  final Color selectionColor;

  // the color of the background of the block
  final Color blockColor;

  // the node of the block
  final Node node;

  final List<BlockSelectionType> supportTypes;

  // the selection area should above the block component
  final bool selectionAboveBlock;

  final Widget child;

  @override
  Widget build(BuildContext context) {
    final supportedTypes = supportTypes
        .where(
          (element) => element != BlockSelectionType.cursor,
        )
        .toList();
    final blockSelectionArea = BlockSelectionArea(
      node: node,
      delegate: delegate,
      listenable: listenable,
      host: host,
      renderer: renderer ?? const DefaultSelectionRenderer(),
      cursorColor: cursorColor,
      selectionColor: selectionColor,
      blockColor: blockColor,
      supportTypes: supportedTypes,
    );
    return Stack(
      clipBehavior: Clip.none,
      // In RTL mode, if the alignment is topStart,
      //  the selection will be on the opposite side of the block component.
      alignment: Directionality.of(context) == TextDirection.ltr
          ? AlignmentDirectional.topStart
          : AlignmentDirectional.topEnd,
      children: [
        if (remoteSelection != null)
          RemoteBlockSelectionsArea(
            node: node,
            delegate: delegate,
            remoteSelections: remoteSelection!,
            supportTypes: supportedTypes,
          ),
        // block selection or selection area
        if (!selectionAboveBlock) blockSelectionArea,
        child,
        // block selection or selection area
        if (selectionAboveBlock) blockSelectionArea,
        // cursor
        // remote cursor
        if (supportTypes.contains(BlockSelectionType.cursor) &&
            remoteSelection != null)
          RemoteBlockSelectionsArea(
            node: node,
            delegate: delegate,
            remoteSelections: remoteSelection!,
            supportTypes: const [BlockSelectionType.cursor],
          ),
        // local cursor
        if (supportTypes.contains(BlockSelectionType.cursor))
          BlockSelectionArea(
            node: node,
            host: host,
            delegate: delegate,
            listenable: listenable,
            cursorColor: cursorColor,
            selectionColor: selectionColor,
            blockColor: blockColor,
            supportTypes: const [BlockSelectionType.cursor],
          ),
      ],
    );
  }
}
