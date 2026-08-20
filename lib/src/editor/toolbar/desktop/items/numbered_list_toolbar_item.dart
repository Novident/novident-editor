import 'package:novident_editor/novident_editor.dart';

const _kNumberedListItemId = 'editor.numbered_list';

final ToolbarItem numberedListItem = ToolbarItem(
  id: _kNumberedListItemId,
  group: 3,
  isActive: showInTextTypeEvenWithoutSelection,
  builder: (context, editorState, highlightColor, iconColor, tooltipBuilder) {
    final selection = editorState.selection;
    if (selection == null) {
      return SVGIconItemWidget(
        iconName: 'toolbar/numbered_list',
        isHighlight: false,
        highlightColor: highlightColor,
        iconColor: iconColor,
        onPressed: () {},
      );
    }
    final node = editorState.getNodeAtPath(selection.start.path)!;
    final isHighlight = node.type == 'numbered_list';
    final child = SVGIconItemWidget(
      iconName: 'toolbar/numbered_list',
      isHighlight: isHighlight,
      highlightColor: highlightColor,
      iconColor: iconColor,
      onPressed: () => editorState.formatNode(
        selection,
        (node) => node.copyWith(
          type: isHighlight ? 'paragraph' : 'numbered_list',
        ),
      ),
    );

    if (tooltipBuilder != null) {
      return tooltipBuilder(
        context,
        _kNumberedListItemId,
        NovidentEditorL10n.current.numberedList,
        child,
      );
    }

    return child;
  },
);
