import 'package:novident_editor/novident_editor.dart';
import 'package:flutter/material.dart';

final styleMobileToolbarItem = MobileToolbarItem.withMenu(
  itemIconBuilder: (context, _, __) {
    final config = NovidentEditorStyles.maybeOf(context)?.config;
    if (config == null || config.registry.styles.isEmpty) {
      return const SizedBox.shrink();
    }
    return NovidentMobileIcon(
      afMobileIcons: NovidentMobileIcons.heading,
      color: MobileToolbarTheme.of(context).iconColor,
    );
  },
  itemMenuBuilder: (_, editorState, __) {
    final selection = editorState.selection;
    if (selection == null) return const SizedBox.shrink();
    return _StyleMenu(selection: selection, editorState: editorState);
  },
);

class _StyleMenu extends StatefulWidget {
  const _StyleMenu({required this.selection, required this.editorState});

  final Selection selection;
  final EditorState editorState;

  @override
  State<_StyleMenu> createState() => _StyleMenuState();
}

class _StyleMenuState extends State<_StyleMenu> {
  @override
  Widget build(BuildContext context) {
    final config = NovidentEditorStyles.of(context).config;
    final allStyles = config.registry.styles.values.toList();
    if (allStyles.isEmpty) return const SizedBox.shrink();

    final node = widget.editorState
        .getNodeAtPath(widget.selection.start.path);
    if (node == null) return const SizedBox.shrink();
    final currentStyleRef =
        node.attributes[blockComponentStyleRef] as String?;

    final style = MobileToolbarTheme.of(context);
    final size = MediaQuery.sizeOf(context);

    final entries = <_StyleMenuEntry>[
      _StyleMenuEntry(
        id: '',
        name: NovidentEditorL10n.current.noStyle,
        isSelected: currentStyleRef == null,
      ),
      ...allStyles.map(
        (s) => _StyleMenuEntry(
          id: s.id,
          name: s.name,
          isSelected: s.id == currentStyleRef,
        ),
      ),
    ];

    final columnCount = (entries.length / 4).ceil().clamp(1, 3);
    final itemWidth =
        (size.width - (columnCount + 1) * style.buttonSpacing) / columnCount;

    final btnList = entries.map((entry) {
      return ConstrainedBox(
        constraints: BoxConstraints.tightFor(width: itemWidth),
        child: MobileToolbarItemMenuBtn(
          label: Text(
            entry.name,
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
            style: TextStyle(
              fontSize: 11,
              fontWeight:
                  entry.isSelected ? FontWeight.bold : FontWeight.normal,
            ),
          ),
          isSelected: entry.isSelected,
          onPressed: () {
            setState(() {
              widget.editorState.updateNode(
                widget.selection,
                (node) => node.copyWith(
                  attributes: {
                    ...node.attributes,
                    if (entry.id.isNotEmpty)
                      blockComponentStyleRef: entry.id
                    else
                      blockComponentStyleRef: null,
                  },
                ),
              );
            });
          },
        ),
      );
    }).toList();

    return ConstrainedBox(
      constraints: BoxConstraints.tightFor(width: size.width),
      child: Wrap(
        spacing: style.buttonSpacing,
        runSpacing: style.buttonSpacing,
        children: btnList,
      ),
    );
  }
}

class _StyleMenuEntry {
  final String id;
  final String name;
  final bool isSelected;

  const _StyleMenuEntry({
    required this.id,
    required this.name,
    required this.isSelected,
  });
}
