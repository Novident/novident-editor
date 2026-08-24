import 'package:novident_editor/novident_editor.dart';

const _kTextColorItemId = 'editor.textColor';

ToolbarItem buildTextColorItem({
  List<ColorOption>? colorOptions,
}) {
  return ToolbarItem(
    id: _kTextColorItemId,
    group: 4,
    isActive: showInTextTypeEvenWithoutSelection,
    builder: (context, editorState, highlightColor, iconColor, tooltipBuilder) {
      final selection = editorState.selection;
      if (selection == null) {
        return SVGIconItemWidget(
          iconName: 'toolbar/text_color',
          isHighlight: false,
          highlightColor: highlightColor,
          iconColor: iconColor,
          onPressed: () {},
        );
      }
      final textColorHex =
          activeAttributeValue(editorState, selection, RichTextKeys.textColor)
              as String?;
      final isHighlight = textColorHex != null;

      final child = SVGIconItemWidget(
        iconName: 'toolbar/text_color',
        isHighlight: isHighlight,
        highlightColor: highlightColor,
        iconColor: iconColor,
        onPressed: () {
          bool showClearButton;
          if (selection.isCollapsed) {
            showClearButton = textColorHex != null;
          } else {
            final nodes = editorState.getNodesInSelection(selection);
            showClearButton = false;
            nodes.allSatisfyInSelection(
              selection,
              (delta) {
                if (!showClearButton) {
                  showClearButton = delta.whereType<TextInsert>().any(
                    (element) {
                      return element.attributes?[RichTextKeys.textColor] !=
                          null;
                    },
                  );
                }
                return true;
              },
            );
          }
          showColorMenu(
            context,
            editorState,
            selection,
            currentColorHex: textColorHex,
            isTextColor: true,
            textColorOptions: colorOptions,
            showClearButton: showClearButton,
          );
        },
      );

      if (tooltipBuilder != null) {
        return tooltipBuilder(
          context,
          _kTextColorItemId,
          NovidentEditorL10n.current.textColor,
          child,
        );
      }

      return child;
    },
  );
}
