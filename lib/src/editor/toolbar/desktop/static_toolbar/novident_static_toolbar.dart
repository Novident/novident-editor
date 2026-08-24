import 'package:collection/collection.dart';
import 'package:flutter/material.dart';
import 'package:novident_editor/novident_editor.dart';

const _kDefaultBackgroundColor = Color(0xFFF5F5F5);
const _kDefaultActiveColor = Color(0xFF00BCF0);
const _kDefaultIconColor = Color(0xFF424242);
const _kDefaultHeight = 36.0;

const _kContainerKey = Key('novident_static_toolbar_container');
const _kItemPrefixKey = 'novident_static_toolbar_item';

class NovidentStaticToolbarStyle {
  const NovidentStaticToolbarStyle({
    this.backgroundColor = _kDefaultBackgroundColor,
    this.toolbarActiveColor = _kDefaultActiveColor,
    this.toolbarIconColor = _kDefaultIconColor,
  });

  final Color backgroundColor;
  final Color toolbarActiveColor;
  final Color? toolbarIconColor;
}

class NovidentStaticToolbar extends StatefulWidget {
  const NovidentStaticToolbar({
    super.key,
    required this.items,
    required this.editorState,
    this.stylesConfig,
    this.style = const NovidentStaticToolbarStyle(),
    this.height = _kDefaultHeight,
    this.tooltipBuilder,
    this.showWhenNoSelection = false,
  });

  final List<ToolbarItem> items;
  final EditorState? editorState;
  final NovidentStylesConfig? stylesConfig;
  final NovidentStaticToolbarStyle style;
  final double height;
  final ToolbarTooltipBuilder? tooltipBuilder;

  /// When `true`, toolbar items render even when there is no text selection.
  /// Defaults to `false` (backward-compatible behavior).
  final bool showWhenNoSelection;

  @override
  State<NovidentStaticToolbar> createState() => _NovidentStaticToolbarState();
}

class _NovidentStaticToolbarState extends State<NovidentStaticToolbar> {
  EditorState? get editorState => widget.editorState;

  @override
  void initState() {
    super.initState();
    editorState?.selectionNotifier.addListener(_onSelectionChanged);
    editorState?.toggledStyleNotifier.addListener(_onSelectionChanged);
  }

  @override
  void didUpdateWidget(covariant NovidentStaticToolbar oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.editorState != oldWidget.editorState) {
      oldWidget.editorState?.selectionNotifier
          .removeListener(_onSelectionChanged);
      oldWidget.editorState?.toggledStyleNotifier
          .removeListener(_onSelectionChanged);
      widget.editorState?.selectionNotifier.addListener(_onSelectionChanged);
      widget.editorState?.toggledStyleNotifier.addListener(_onSelectionChanged);
    }
  }

  @override
  void dispose() {
    editorState?.selectionNotifier.removeListener(_onSelectionChanged);
    editorState?.toggledStyleNotifier.removeListener(_onSelectionChanged);
    super.dispose();
  }

  void _onSelectionChanged() {
    if (mounted) setState(() {});
  }

  @override
  Widget build(BuildContext context) {
    Widget child = Container(
      height: widget.height,
      decoration: BoxDecoration(
        color: widget.style.backgroundColor,
        border: const Border(
          bottom: BorderSide(color: Color(0x1F000000)),
        ),
      ),
      child: _StaticToolbarRow(
        items: widget.items,
        editorState: editorState,
        activeColor: widget.style.toolbarActiveColor,
        iconColor: widget.style.toolbarIconColor,
        tooltipBuilder: widget.tooltipBuilder,
        showWhenNoSelection: widget.showWhenNoSelection,
      ),
    );

    if (widget.stylesConfig != null) {
      child = NovidentEditorStyles(
        config: widget.stylesConfig!,
        child: child,
      );
    }

    return child;
  }
}

class _StaticToolbarRow extends StatelessWidget {
  const _StaticToolbarRow({
    required this.items,
    required this.editorState,
    required this.activeColor,
    required this.iconColor,
    required this.tooltipBuilder,
    required this.showWhenNoSelection,
  });

  final List<ToolbarItem> items;
  final EditorState? editorState;
  final Color activeColor;
  final Color? iconColor;
  final ToolbarTooltipBuilder? tooltipBuilder;
  final bool showWhenNoSelection;

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      child: Row(
        key: _kContainerKey,
        mainAxisSize: MainAxisSize.min,
        children: _buildChildren(),
      ),
    );
  }

  List<Widget> _buildChildren() {
    final groups = items.splitBetween(
      (first, second) => first.group != second.group,
    );

    final widgets = <Widget>[];
    for (final group in groups) {
      if (widgets.isNotEmpty) {
        widgets.add(_buildDivider());
      }
      for (final item in group) {
        if (item.id == placeholderItemId) {
          widgets.add(_buildDivider());
          continue;
        }
        widgets.add(
          _StaticToolbarItem(
            item: item,
            editorState: editorState,
            activeColor: activeColor,
            iconColor: iconColor,
            tooltipBuilder: tooltipBuilder,
            showWhenNoSelection: showWhenNoSelection,
          ),
        );
      }
    }

    return widgets;
  }

  Widget _buildDivider() {
    return const Padding(
      padding: EdgeInsets.symmetric(vertical: 8, horizontal: 5),
      child: SizedBox(
        width: 1,
        child: DecoratedBox(
          decoration: BoxDecoration(color: Color(0x1F000000)),
        ),
      ),
    );
  }
}

class _StaticToolbarItem extends StatelessWidget {
  const _StaticToolbarItem({
    required this.item,
    required this.editorState,
    required this.activeColor,
    required this.iconColor,
    required this.tooltipBuilder,
    required this.showWhenNoSelection,
  });

  final ToolbarItem item;
  final EditorState? editorState;
  final Color activeColor;
  final Color? iconColor;
  final ToolbarTooltipBuilder? tooltipBuilder;
  final bool showWhenNoSelection;

  @override
  Widget build(BuildContext context) {
    if (editorState == null) {
      return const SizedBox(width: 34, height: 34);
    }
    if (editorState!.selection == null && !showWhenNoSelection) {
      return const SizedBox(width: 34, height: 34);
    }

    return Center(
      key: Key('${_kItemPrefixKey}_${item.id}'),
      child: item.builder!(
        context,
        editorState!,
        activeColor,
        iconColor,
        tooltipBuilder,
      ),
    );
  }
}
