import 'package:novident_editor/novident_editor.dart';
import 'package:flutter/material.dart';

final styleMobileToolbarItem = MobileToolbarItem.withMenu(
  itemIconBuilder: (context, _, __) {
    return NovidentMobileIcon(
      afMobileIcons: NovidentMobileIcons.styleSolid,
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
    final styles = NovidentEditorStyles.of(context);
    final config = styles.config;
    final allStyles = config.registry.styles.values.toList();
    if (allStyles.isEmpty) return const SizedBox.shrink();

    final node = widget.editorState.getNodeAtPath(widget.selection.start.path);
    if (node == null) return const SizedBox.shrink();
    final currentStyleRef = node.attributes[blockComponentStyleRef] as String?;

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
          style: s,
        ),
      ),
    ];

    final columnCount = (entries.length / 4).ceil().clamp(1, 3);
    final itemWidth =
        (size.width - (columnCount + 1) * style.buttonSpacing) / columnCount;

    final btnList = entries.map((entry) {
      final style = entry.style == null
          ? kDefaultBaseStyle
          : styles.resolveStyle(entry.style ?? kDefaultBaseStyle);
      return ConstrainedBox(
        constraints: BoxConstraints.tightFor(width: itemWidth),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 3),
          child: MobileToolbarItemMenuBtn(
            label: Text(
              entry.name,
              maxLines: 2,
              style: _buildBaseTextStyle(style).merge(
                TextStyle(
                  fontSize: 16,
                  fontWeight:
                      entry.isSelected ? FontWeight.bold : FontWeight.normal,
                ),
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

  TextStyle _buildBaseTextStyle(NovidentStyleDefinition? resolved) {
    final TextStyle style = TextStyle(
      fontSize: kDefaultBaseStyle.fontSize,
      fontFamily: kDefaultBaseStyle.fontFamily,
      color: kDefaultBaseStyle.textColor,
    );
    if (resolved == null) return style;

    final resolvedTextStyle = TextStyle(
      fontSize: resolved.fontSize,
      fontWeight: resolved.bold ? FontWeight.bold : null,
      fontStyle: resolved.italic ? FontStyle.italic : null,
      decoration: TextDecoration.combine([
        if (resolved.overline) TextDecoration.overline,
        if (resolved.underline) TextDecoration.underline,
        if (resolved.strikethrough) TextDecoration.lineThrough,
      ]),
      fontFamily: resolved.fontFamily,
      color: resolved.textColor,
      backgroundColor: resolved.textBackgroundColor,
      decorationStyle: resolved.decorationStyle,
      letterSpacing: resolved.letterSpacing,
      wordSpacing: resolved.wordSpacing,
      fontVariations: resolved.fontVariations,
      shadows: resolved.fontShadows,
      foreground: resolved.fontForeground,
      background: resolved.fontBackground,
      fontFeatures: resolved.fontFeatures,
      decorationColor: resolved.decorationColor,
      height: resolved.spacing?.lineHeight,
    );
    return style.merge(resolvedTextStyle);
  }
}

class _StyleMenuEntry {
  const _StyleMenuEntry({
    required this.id,
    required this.name,
    required this.isSelected,
    this.style,
  });
  final String id;
  final String name;
  final bool isSelected;
  final NovidentStyleDefinition? style;
}
