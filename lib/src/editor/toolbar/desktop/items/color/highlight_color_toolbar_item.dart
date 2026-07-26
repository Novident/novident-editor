import 'package:novident_editor/novident_editor.dart';

const _kHighlightColorItemId = 'editor.highlightColor';

ToolbarItem buildHighlightColorItem({List<ColorOption>? colorOptions}) {
  return ToolbarItem(
    id: _kHighlightColorItemId,
    group: 4,
    isActive: showInTextTypeEvenWithoutSelection,
    builder: (context, editorState, highlightColor, iconColor, tooltipBuilder) {
      final selection = editorState.selection;
      if (selection == null) {
        return SVGIconItemWidget(
          iconName: 'toolbar/highlight_color',
          isHighlight: false,
          highlightColor: highlightColor,
          iconColor: iconColor,
          onPressed: () {},
        );
      }
      String? highlightColorHex;

      final nodes = editorState.getNodesInSelection(selection);
      final isHighlight = nodes.allSatisfyInSelection(selection, (delta) {
        if (delta.everyAttributes((attr) => attr.isEmpty)) {
          return false;
        }

        return delta.everyAttributes((attributes) {
          highlightColorHex = attributes[NovidentRichTextKeys.backgroundColor];
          return highlightColorHex != null;
        });
      });

      final child = SVGIconItemWidget(
        iconName: 'toolbar/highlight_color',
        isHighlight: isHighlight,
        highlightColor: highlightColor,
        iconColor: iconColor,
        onPressed: () {
          bool showClearButton = false;
          nodes.allSatisfyInSelection(selection, (delta) {
            if (!showClearButton) {
              showClearButton = delta.whereType<TextInsert>().any(
                (element) {
                  return element
                          .attributes?[NovidentRichTextKeys.backgroundColor] !=
                      null;
                },
              );
            }
            return true;
          });
          showColorMenu(
            context,
            editorState,
            selection,
            currentColorHex: highlightColorHex,
            isTextColor: false,
            highlightColorOptions: colorOptions,
            showClearButton: showClearButton,
          );
        },
      );

      if (tooltipBuilder != null) {
        return tooltipBuilder(
          context,
          _kHighlightColorItemId,
          NovidentEditorL10n.current.highlightColor,
          child,
        );
      }

      return child;
    },
  );
}
