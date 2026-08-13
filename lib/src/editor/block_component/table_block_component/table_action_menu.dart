import 'package:novident_editor/novident_editor.dart';
import 'package:novident_editor/src/editor/toolbar/desktop/items/utils/overlay_util.dart';
import 'package:flutter/material.dart';

/// The runtime information handed to a [TableActionMenuItem] when it is
/// pressed.
class TableActionMenuContext {
  const TableActionMenuContext({
    required this.buildContext,
    required this.node,
    required this.editorState,
    required this.position,
    required this.dir,
    required this.dismiss,
    this.top,
    this.bottom,
    this.left,
  });

  /// The build context of the menu overlay.
  final BuildContext buildContext;

  /// The table node that owns the menu.
  final Node node;

  final EditorState editorState;

  /// The row or column index the menu was opened for.
  final int position;

  /// Whether the menu was opened for a row or a column.
  final TableDirection dir;

  /// Closes the menu overlay.
  final VoidCallback dismiss;

  /// The anchor of the menu overlay, useful to position secondary overlays
  /// (e.g. a color picker) next to the menu.
  final double? top;
  final double? bottom;
  final double? left;
}

/// A single entry of the table context (action) menu.
///
/// Pass a custom list of items to `TableBlockComponentBuilder.actionMenuItems`
/// and `TableCellBlockComponentBuilder.actionMenuItems` to add, remove or
/// reorder entries without replacing the whole menu:
///
/// ```dart
/// final items = [
///   ...defaultTableActionMenuItems,
///   TableActionMenuItem(
///     name: 'Toggle horizontal scroll',
///     icon: Icons.swap_horiz,
///     onPressed: (menuContext) {
///       final enabled = menuContext.node
///               .attributes[TableBlockKeys.enableHorizontalScroll] as bool? ??
///           true;
///       TableActions.setEnableHorizontalScroll(
///         menuContext.node,
///         menuContext.editorState,
///         enable: !enabled,
///       );
///       menuContext.dismiss();
///     },
///   ),
/// ];
/// ```
class TableActionMenuItem {
  const TableActionMenuItem({
    required this.name,
    required this.icon,
    required this.onPressed,
    this.direction,
    this.visible,
    this.builder,
  });

  /// The label of the entry.
  final String name;

  /// The icon of the entry.
  final IconData icon;

  /// Invoked when the entry is tapped.
  ///
  /// Call [TableActionMenuContext.dismiss] to close the menu.
  final void Function(TableActionMenuContext menuContext) onPressed;

  /// The direction this item acts on.
  ///
  /// - [TableDirection.col] / [TableDirection.row]: the item operates on a
  ///   column or row respectively. Only shown in handlers and menus matching
  ///   that direction.
  /// - `null`: the item is direction-agnostic (e.g. border properties) and
  ///   shown for both directions.
  final TableDirection? direction;

  /// Optional predicate to hide the entry for specific tables or positions.
  /// Defaults to always visible.
  final bool Function(Node node, int position)? visible;

  /// Optional builder that allows create custom widget forms
  final Widget Function(
    BuildContext context, {
    required IconData icon,
    required String tooltip,
    required VoidCallback onTap,
    required bool enabled,
  })? builder;
}

/// Adds a column before the current one.
final TableActionMenuItem tableActionAddColumnBeforeItem = TableActionMenuItem(
  name: NovidentEditorL10n.current.colAddBefore,
  icon: Icons.first_page,
  direction: TableDirection.col,
  onPressed: (menuContext) {
    final styles = NovidentEditorStyles.maybeOf(menuContext.buildContext);
    final resolved = styles?.resolveStyleForNode(menuContext.node);
    final tableStyleDef = resolved is NovidentTableStyleDefinition
        ? resolved
        : kDefaultTableStyle;
    TableActions.add(
      menuContext.node,
      menuContext.position,
      menuContext.editorState,
      TableDirection.col,
      tableStyleDef,
    );
    menuContext.dismiss();
  },
);

/// Adds a row before the current one.
final TableActionMenuItem tableActionAddRowBeforeItem = TableActionMenuItem(
  name: NovidentEditorL10n.current.rowAddBefore,
  icon: Icons.vertical_align_top,
  direction: TableDirection.row,
  onPressed: (menuContext) {
    final styles = NovidentEditorStyles.maybeOf(menuContext.buildContext);
    final resolved = styles?.resolveStyleForNode(menuContext.node);
    final tableStyleDef = resolved is NovidentTableStyleDefinition
        ? resolved
        : kDefaultTableStyle;
    TableActions.add(
      menuContext.node,
      menuContext.position,
      menuContext.editorState,
      TableDirection.row,
      tableStyleDef,
    );
    menuContext.dismiss();
  },
);

/// Adds a column after the current one.
final TableActionMenuItem tableActionAddColumnAfterItem = TableActionMenuItem(
  name: NovidentEditorL10n.current.colAddAfter,
  icon: Icons.last_page,
  direction: TableDirection.col,
  onPressed: (menuContext) {
    final styles = NovidentEditorStyles.maybeOf(menuContext.buildContext);
    final resolved = styles?.resolveStyleForNode(menuContext.node);
    final tableStyleDef = resolved is NovidentTableStyleDefinition
        ? resolved
        : kDefaultTableStyle;
    TableActions.add(
      menuContext.node,
      menuContext.position + 1,
      menuContext.editorState,
      TableDirection.col,
      tableStyleDef,
    );
    menuContext.dismiss();
  },
);

/// Adds a row after the current one.
final TableActionMenuItem tableActionAddRowAfterItem = TableActionMenuItem(
  name: NovidentEditorL10n.current.rowAddAfter,
  icon: Icons.vertical_align_bottom,
  direction: TableDirection.row,
  onPressed: (menuContext) {
    final styles = NovidentEditorStyles.maybeOf(menuContext.buildContext);
    final resolved = styles?.resolveStyleForNode(menuContext.node);
    final tableStyleDef = resolved is NovidentTableStyleDefinition
        ? resolved
        : kDefaultTableStyle;
    TableActions.add(
      menuContext.node,
      menuContext.position + 1,
      menuContext.editorState,
      TableDirection.row,
      tableStyleDef,
    );
    menuContext.dismiss();
  },
);

/// Removes the current column.
final TableActionMenuItem tableActionRemoveColumnItem = TableActionMenuItem(
  name: NovidentEditorL10n.current.colRemove,
  icon: Icons.delete,
  direction: TableDirection.col,
  onPressed: (menuContext) {
    TableActions.delete(
      menuContext.node,
      menuContext.position,
      menuContext.editorState,
      TableDirection.col,
    );
    menuContext.dismiss();
  },
);

/// Removes the current row.
final TableActionMenuItem tableActionRemoveRowItem = TableActionMenuItem(
  name: NovidentEditorL10n.current.rowRemove,
  icon: Icons.delete,
  direction: TableDirection.row,
  onPressed: (menuContext) {
    TableActions.delete(
      menuContext.node,
      menuContext.position,
      menuContext.editorState,
      TableDirection.row,
    );
    menuContext.dismiss();
  },
);

/// Duplicates the current column.
final TableActionMenuItem tableActionDuplicateColumnItem = TableActionMenuItem(
  name: NovidentEditorL10n.current.colDuplicate,
  icon: Icons.content_copy,
  direction: TableDirection.col,
  onPressed: (menuContext) {
    TableActions.duplicate(
      menuContext.node,
      menuContext.position,
      menuContext.editorState,
      TableDirection.col,
    );
    menuContext.dismiss();
  },
);

/// Duplicates the current row.
final TableActionMenuItem tableActionDuplicateRowItem = TableActionMenuItem(
  name: NovidentEditorL10n.current.rowDuplicate,
  icon: Icons.content_copy,
  direction: TableDirection.row,
  onPressed: (menuContext) {
    TableActions.duplicate(
      menuContext.node,
      menuContext.position,
      menuContext.editorState,
      TableDirection.row,
    );
    menuContext.dismiss();
  },
);

/// Opens the background color picker for the current column.
final TableActionMenuItem tableActionColumnBackgroundColorItem =
    TableActionMenuItem(
  name: NovidentEditorL10n.current.backgroundColor,
  icon: Icons.format_color_fill,
  direction: TableDirection.col,
  onPressed: (menuContext) {
    final table = TableNode(node: menuContext.node);
    final cell = table.getCell(menuContext.position, 0);
    _showColorMenu(
      menuContext.buildContext,
      (color) {
        TableActions.setBgColor(
          menuContext.node,
          menuContext.position,
          menuContext.editorState,
          color,
          TableDirection.col,
        );
      },
      top: menuContext.top,
      bottom: menuContext.bottom,
      left: menuContext.left,
      selectedColorHex: cell.attributes[TableCellBlockKeys.colBackgroundColor],
    );
    menuContext.dismiss();
  },
);

/// Opens the background color picker for the current row.
final TableActionMenuItem tableActionRowBackgroundColorItem =
    TableActionMenuItem(
  name: NovidentEditorL10n.current.backgroundColor,
  icon: Icons.format_color_fill,
  direction: TableDirection.row,
  onPressed: (menuContext) {
    final table = TableNode(node: menuContext.node);
    final cell = table.getCell(0, menuContext.position);
    _showColorMenu(
      menuContext.buildContext,
      (color) {
        TableActions.setBgColor(
          menuContext.node,
          menuContext.position,
          menuContext.editorState,
          color,
          TableDirection.row,
        );
      },
      top: menuContext.top,
      bottom: menuContext.bottom,
      left: menuContext.left,
      selectedColorHex: cell.attributes[TableCellBlockKeys.rowBackgroundColor],
    );
    menuContext.dismiss();
  },
);

/// Clears the content of the current column.
final TableActionMenuItem tableActionClearColumnItem = TableActionMenuItem(
  name: NovidentEditorL10n.current.colClear,
  icon: Icons.clear,
  direction: TableDirection.col,
  onPressed: (menuContext) {
    TableActions.clear(
      menuContext.node,
      menuContext.position,
      menuContext.editorState,
      TableDirection.col,
    );
    menuContext.dismiss();
  },
);

/// Clears the content of the current row.
final TableActionMenuItem tableActionClearRowItem = TableActionMenuItem(
  name: NovidentEditorL10n.current.rowClear,
  icon: Icons.clear,
  direction: TableDirection.row,
  onPressed: (menuContext) {
    TableActions.clear(
      menuContext.node,
      menuContext.position,
      menuContext.editorState,
      TableDirection.row,
    );
    menuContext.dismiss();
  },
);

/// Opens the border properties submenu (width presets + border color) for
/// the whole table. Built with English labels — use
/// [buildTableActionBorderPropertiesItem] to localize them.
final TableActionMenuItem tableActionBorderPropertiesItem =
    buildTableActionBorderPropertiesItem();

/// Builds a [TableActionMenuItem] that opens the border properties submenu.
///
/// The submenu contains:
///  * a row of border width presets ([widthOptions]) plus a reset button
///    that falls back to [TableStyle.borderWidth], and
///  * a color entry that opens a [ColorPicker] bound to
///    [TableActions.setBorderColor].
///
/// The labels default to English — pass your own strings to localize the
/// entry.
TableActionMenuItem buildTableActionBorderPropertiesItem({
  String name = 'Border properties',
  String widthLabel = 'Width',
  String colorLabel = 'Border color',
  List<double> widthOptions = const [1, 2, 3, 4],
  IconData icon = Icons.border_all,
}) {
  return TableActionMenuItem(
    name: name,
    icon: icon,
    onPressed: (menuContext) {
      // insert the submenu before dismissing the current overlay, so the
      // build context used to resolve the root overlay is still mounted.
      showTableBorderPropertiesMenu(
        menuContext,
        widthLabel: widthLabel,
        colorLabel: colorLabel,
        widthOptions: widthOptions,
      );
      menuContext.dismiss();
    },
  );
}

/// Shows the border properties submenu (border width presets + border
/// color picker) anchored at the position of [menuContext].
void showTableBorderPropertiesMenu(
  TableActionMenuContext menuContext, {
  String widthLabel = 'Width',
  String colorLabel = 'Border color',
  List<double> widthOptions = const [1, 2, 3, 4],
}) {
  OverlayEntry? overlay;

  void dismissOverlay() {
    overlay?.remove();
    overlay = null;
  }

  overlay = FullScreenOverlayEntry(
    top: menuContext.top,
    bottom: menuContext.bottom,
    left: menuContext.left,
    builder: (context) {
      return basicOverlay(
        context,
        width: 240,
        height: 2 * 36.0 + 12,
        children: [
          _borderWidthRow(
            context,
            menuContext,
            widthLabel,
            widthOptions,
            dismissOverlay,
          ),
          _menuItem(context, colorLabel, Icons.border_color, () {
            // open the color picker before removing this overlay; see the
            // note in [buildTableActionBorderPropertiesItem].
            _showColorMenu(
              context,
              (color) {
                TableActions.setBorderColor(
                  menuContext.node,
                  menuContext.editorState,
                  color: color,
                );
              },
              title: colorLabel,
              top: menuContext.top,
              bottom: menuContext.bottom,
              left: menuContext.left,
              selectedColorHex:
                  menuContext.node.attributes[TableBlockKeys.borderColor],
            );
            dismissOverlay();
          }),
        ],
      );
    },
  ).build();
  Overlay.of(menuContext.buildContext, rootOverlay: true).insert(overlay!);
}

Widget _borderWidthRow(
  BuildContext context,
  TableActionMenuContext menuContext,
  String label,
  List<double> widthOptions,
  VoidCallback dismiss,
) {
  final rawWidth = menuContext.node.attributes[TableBlockKeys.borderWidth];
  final currentWidth =
      double.tryParse(rawWidth.toString()) ?? TableDefaults.borderWidth;
  final textColor = Theme.of(context).textTheme.labelLarge?.color;

  return SizedBox(
    height: 36,
    child: Row(
      children: [
        const SizedBox(width: 8),
        Expanded(
          child: Text(
            label,
            softWrap: false,
            maxLines: 1,
            overflow: TextOverflow.fade,
            style: TextStyle(color: textColor),
          ),
        ),
        ...widthOptions.map(
          (width) => _borderWidthChip(
            context,
            label: width == width.roundToDouble()
                ? width.toInt().toString()
                : width.toString(),
            selected: width == currentWidth,
            onTap: () {
              TableActions.setBorderWidth(
                menuContext.node,
                menuContext.editorState,
                width: width,
              );
              dismiss();
            },
          ),
        ),
        // reset: remove the override and fall back to the style value.
        _borderWidthChip(
          context,
          label: null,
          selected: false,
          onTap: () {
            TableActions.setBorderWidth(
              menuContext.node,
              menuContext.editorState,
              width: null,
            );
            dismiss();
          },
        ),
        const SizedBox(width: 4),
      ],
    ),
  );
}

Widget _borderWidthChip(
  BuildContext context, {
  required String? label,
  required bool selected,
  required VoidCallback onTap,
}) {
  final theme = Theme.of(context);
  return Padding(
    padding: const EdgeInsets.symmetric(horizontal: 2),
    child: InkWell(
      borderRadius: BorderRadius.circular(6),
      onTap: onTap,
      child: Container(
        width: 28,
        height: 28,
        alignment: Alignment.center,
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(6),
          border: selected
              ? Border.all(color: theme.colorScheme.primary, width: 1.5)
              : Border.all(color: theme.dividerColor),
        ),
        child: label != null
            ? Text(
                label,
                style: TextStyle(
                  fontSize: 13,
                  color: theme.textTheme.labelLarge?.color,
                ),
              )
            : Icon(
                Icons.format_clear,
                size: 16,
                color: theme.iconTheme.color,
              ),
      ),
    ),
  );
}

/// The built-in entries of the table context menu.
///
/// Copy this list to customize the menu, e.g.
/// `[...defaultTableActionMenuItems, myItem]`.
final List<TableActionMenuItem> defaultTableActionMenuItems =
    List.unmodifiable([
  tableActionAddColumnBeforeItem,
  tableActionAddRowBeforeItem,
  tableActionAddColumnAfterItem,
  tableActionAddRowAfterItem,
  tableActionRemoveColumnItem,
  tableActionRemoveRowItem,
  tableActionDuplicateColumnItem,
  tableActionDuplicateRowItem,
  tableActionColumnBackgroundColorItem,
  tableActionRowBackgroundColorItem,
  tableActionClearColumnItem,
  tableActionClearRowItem,
  tableActionBorderPropertiesItem,
]);

void showActionMenu(
  BuildContext context,
  Node node,
  EditorState editorState,
  int position,
  TableDirection dir, {
  List<TableActionMenuItem>? items,
}) {
  final Offset pos =
      (context.findRenderObject() as RenderBox).localToGlobal(Offset.zero);
  final rect = Rect.fromLTWH(
    pos.dx,
    pos.dy,
    context.size?.width ?? 0,
    context.size?.height ?? 0,
  );
  OverlayEntry? overlay;

  var (top, bottom, left) = positionFromRect(rect, editorState);
  top = top != null ? top - 35 : top;

  void dismissOverlay() {
    overlay?.remove();
    overlay = null;
  }

  final visibleItems = (items ?? defaultTableActionMenuItems)
      .where((item) {
        if (item.direction != null && item.direction != dir) return false;
        return item.visible?.call(node, position) ?? true;
      })
      .toList(growable: false);
  if (visibleItems.isEmpty) {
    return;
  }

  overlay = FullScreenOverlayEntry(
    top: top,
    bottom: bottom,
    left: left,
    builder: (context) {
      final menuContext = TableActionMenuContext(
        buildContext: context,
        node: node,
        editorState: editorState,
        position: position,
        dir: dir,
        dismiss: dismissOverlay,
        top: top,
        bottom: bottom,
        left: left,
      );
      return basicOverlay(
        context,
        width: 200,
        // 36 per entry + the vertical padding of the overlay container.
        height: visibleItems.length * 36.0 + 12,
          children: visibleItems
              .map(
                (item) => _menuItem(
                  context,
                  item.name,
                  item.icon,
                  () => item.onPressed(menuContext),
                ),
              )
              .toList(growable: false),
      );
    },
  ).build();
  Overlay.of(context, rootOverlay: true).insert(overlay!);
}

Widget _menuItem(
  BuildContext context,
  String text,
  IconData icon,
  Function() action,
) {
  return SizedBox(
    height: 36,
    child: TextButton.icon(
      onPressed: () {
        action();
      },
      icon: Icon(icon, color: Theme.of(context).iconTheme.color),
      style: buildOverlayButtonStyle(context),
      label: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Expanded(
            child: Text(
              text,
              softWrap: false,
              maxLines: 1,
              overflow: TextOverflow.fade,
              style: TextStyle(
                color: Theme.of(context).textTheme.labelLarge?.color,
              ),
            ),
          ),
        ],
      ),
    ),
  );
}

void _showColorMenu(
  BuildContext context,
  Function(String?) action, {
  double? top,
  double? bottom,
  double? left,
  String? selectedColorHex,
  String? title,
}) {
  OverlayEntry? overlay;

  void dismissOverlay() {
    overlay?.remove();
    overlay = null;
  }

  overlay = FullScreenOverlayEntry(
    top: top,
    bottom: bottom,
    left: left,
    builder: (context) {
      return ColorPicker(
        title: title ?? NovidentEditorL10n.current.highlightColor,
        selectedColorHex: selectedColorHex,
        colorOptions: generateHighlightColorOptions(),
        onSubmittedColorHex: (color, _) {
          action(color);
          dismissOverlay();
        },
        resetText: NovidentEditorL10n.current.clearHighlightColor,
        resetIconName: 'clear_highlight_color',
      );
    },
  ).build();
  Overlay.of(context, rootOverlay: true).insert(overlay!);
}
