import 'package:novident_editor/novident_editor.dart';

const _kBulletedListItemId = 'editor.bulleted_list';

final ToolbarItem bulletedListItem = ToolbarItem(
  id: _kBulletedListItemId,
  group: 3,
  isActive: showInTextTypeEvenWithoutSelection,
  builder: (context, editorState, highlightColor, iconColor, tooltipBuilder) {
    final selection = editorState.selection;
    if (selection == null) {
      return SVGIconItemWidget(
        iconName: 'toolbar/bulleted_list',
        isHighlight: false,
        highlightColor: highlightColor,
        iconColor: iconColor,
        onPressed: () {},
      );
    }
    final node = editorState.getNodeAtPath(selection.start.path)!;
    final isHighlight = node.type == 'bulleted_list';
    final child = SVGIconItemWidget(
      iconName: 'toolbar/bulleted_list',
      isHighlight: isHighlight,
      highlightColor: highlightColor,
      iconColor: iconColor,
      onPressed: () => editorState.formatNode(
        selection,
        (node) => node.copyWith(
          type: isHighlight ? 'paragraph' : 'bulleted_list',
        ),
      ),
    );

    if (tooltipBuilder != null) {
      return tooltipBuilder(
        context,
        _kBulletedListItemId,
        NovidentEditorL10n.current.bulletedList,
        child,
      );
    }

    return child;
  },
);
