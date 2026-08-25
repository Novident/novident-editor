import 'package:novident_editor/novident_editor.dart';
import 'package:flutter/material.dart';

class BackgroundColorOptionsWidgets extends StatefulWidget {
  const BackgroundColorOptionsWidgets(
    this.editorState,
    this.selection, {
    this.backgroundColorOptions,
    super.key,
  });

  final Selection selection;
  final EditorState editorState;
  final List<ColorOption>? backgroundColorOptions;

  @override
  State<BackgroundColorOptionsWidgets> createState() =>
      _BackgroundColorOptionsWidgetsState();
}

class _BackgroundColorOptionsWidgetsState
    extends State<BackgroundColorOptionsWidgets> {
  @override
  Widget build(BuildContext context) {
    final style = MobileToolbarTheme.of(context);
    final colorOptions =
        widget.backgroundColorOptions ?? generateHighlightColorOptions();
    final selection = widget.selection;
    final activeColor = activeAttributeValue(
      widget.editorState,
      selection,
      RichTextKeys.backgroundColor,
    ) as String?;
    final hasTextColor = activeColor != null;

    return Scrollbar(
      child: GridView(
        shrinkWrap: true,
        gridDelegate: buildMobileToolbarMenuGridDelegate(
          mobileToolbarStyle: style,
          crossAxisCount: 3,
        ),
        padding: EdgeInsets.all(style.buttonSpacing),
        children: [
          ClearColorButton(
            onPressed: () {
              if (hasTextColor) {
                setState(() {
                  widget.editorState.formatDelta(
                    selection,
                    {RichTextKeys.backgroundColor: null},
                  );
                });
              }
            },
            isSelected: !hasTextColor,
          ),
          // color option buttons
          for (final e in colorOptions)
            ColorButton(
              isBackgroundColor: true,
              colorOption: e,
              onPressed: () {
                if (activeColor != e.colorHex) {
                  setState(() {
                    formatHighlightColor(
                      widget.editorState,
                      widget.editorState.selection,
                      e.colorHex,
                    );
                  });
                }
              },
              isSelected: activeColor == e.colorHex,
            ),
        ],
      ),
    );
  }
}
