import 'package:novident_editor/novident_editor.dart';

const _kParagraphItemId = 'editor.paragraph';

final ToolbarItem paragraphItem = ToolbarItem(
  id: _kParagraphItemId,
  group: 1,
  isActive: showInSingleSelectionEvenWithoutSelection,
  builder: (context, editorState, highlightColor, iconColor, tooltipBuilder) {
    final selection = editorState.selection;
    if (selection == null) {
      return SVGIconItemWidget(
        iconName: 'toolbar/text',
        isHighlight: false,
        highlightColor: highlightColor,
        iconColor: iconColor,
        onPressed: () {},
      );
    }
    final node = editorState.getNodeAtPath(selection.start.path)!;
    final isHighlight = node.type == 'paragraph';
    final delta = (node.delta ?? Delta()).toJson();
    final child = SVGIconItemWidget(
      iconName: 'toolbar/text',
      isHighlight: isHighlight,
      highlightColor: highlightColor,
      iconColor: iconColor,
      onPressed: () => editorState.formatNode(
        selection,
        (node) => node.copyWith(
          type: ParagraphBlockKeys.type,
          attributes: {
            blockComponentDelta: delta,
            blockComponentBackgroundColor:
                node.attributes[blockComponentBackgroundColor],
            blockComponentTextDirection:
                node.attributes[blockComponentTextDirection],
          },
        ),
      ),
    );

    if (tooltipBuilder != null) {
      return tooltipBuilder(
        context,
        _kParagraphItemId,
        NovidentEditorL10n.current.text,
        child,
      );
    }

    return child;
  },
);
