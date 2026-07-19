import 'dart:math' as math;

import 'package:novident_editor/novident_editor.dart';
import 'package:flutter/material.dart';

class TableActionHandler extends StatefulWidget {
  const TableActionHandler({
    super.key,
    this.visible = false,
    this.height,
    required this.node,
    required this.editorState,
    required this.position,
    required this.alignment,
    required this.transform,
    required this.dir,
    this.menuBuilder,
    this.actionMenuItems,
  });

  final bool visible;
  final Node node;
  final EditorState editorState;
  final int position;
  final Alignment alignment;
  final Matrix4 transform;
  final double? height;
  final TableDirection dir;

  final TableBlockComponentMenuBuilder? menuBuilder;

  /// The entries of the default context menu. Ignored when [menuBuilder]
  /// is provided. Defaults to [defaultTableActionMenuItems].
  final List<TableActionMenuItem>? actionMenuItems;

  @override
  State<TableActionHandler> createState() => _TableActionHandlerState();
}

class _TableActionHandlerState extends State<TableActionHandler> {
  bool _visible = false;
  bool _menuShown = false;

  @override
  Widget build(BuildContext context) {
    return Container(
      alignment: widget.alignment,
      transform: widget.transform,
      height: widget.height,
      child: Visibility(
        visible: (widget.visible || _visible || _menuShown) &&
            widget.editorState.editable,
        child: MouseRegion(
          onEnter: (_) => setState(() => _visible = true),
          onExit: (_) => setState(() => _visible = false),
          child: widget.menuBuilder != null
              ? widget.menuBuilder!(
                  widget.node,
                  widget.editorState,
                  widget.position,
                  widget.dir,
                  () => _menuShown = true,
                  () => setState(() => _menuShown = false),
                )
              : defaultMenuBuilder(
                  context,
                  widget.node,
                  widget.editorState,
                  widget.position,
                  widget.dir,
                  actionMenuItems: widget.actionMenuItems,
                ),
        ),
      ),
    );
  }
}

Widget defaultMenuBuilder(
  BuildContext context,
  Node node,
  EditorState editorState,
  int position,
  TableDirection dir, {
  List<TableActionMenuItem>? actionMenuItems,
}) {
  return Card(
    elevation: 3.0,
    child: MouseRegion(
      cursor: SystemMouseCursors.click,
      child: GestureDetector(
        onTap: () => showActionMenu(
          context,
          node,
          editorState,
          position,
          dir,
          items: actionMenuItems,
        ),
        child: dir == TableDirection.col
            ? Transform.rotate(
                angle: math.pi / 2,
                child: TableDefaults.handlerIcon,
              )
            : TableDefaults.handlerIcon,
      ),
    ),
  );
}
