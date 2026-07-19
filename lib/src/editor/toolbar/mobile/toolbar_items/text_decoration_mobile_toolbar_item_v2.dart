import 'package:novident_editor/novident_editor.dart';
import 'package:flutter/material.dart';

final textDecorationMobileToolbarItemV2 = MobileToolbarItem.withMenu(
  itemIconBuilder: (context, __, ___) => NovidentMobileIcon(
    afMobileIcons: NovidentMobileIcons.textDecoration,
    color: MobileToolbarTheme.of(context).iconColor,
  ),
  itemMenuBuilder: (_, editorState, __) {
    final selection = editorState.selection;
    if (selection == null) {
      return const SizedBox.shrink();
    }
    return _TextDecorationMenu(editorState, selection);
  },
);

class _TextDecorationMenu extends StatefulWidget {
  const _TextDecorationMenu(
    this.editorState,
    this.selection,
  );

  final EditorState editorState;
  final Selection selection;

  @override
  State<_TextDecorationMenu> createState() => _TextDecorationMenuState();
}

class _TextDecorationMenuState extends State<_TextDecorationMenu> {
  final textDecorations = [
    // BIUS
    TextDecorationUnit(
      icon: NovidentMobileIcons.bold,
      label: NovidentEditorL10n.current.bold,
      name: NovidentRichTextKeys.bold,
    ),
    TextDecorationUnit(
      icon: NovidentMobileIcons.italic,
      label: NovidentEditorL10n.current.italic,
      name: NovidentRichTextKeys.italic,
    ),
    TextDecorationUnit(
      icon: NovidentMobileIcons.underline,
      label: NovidentEditorL10n.current.underline,
      name: NovidentRichTextKeys.underline,
    ),
    TextDecorationUnit(
      icon: NovidentMobileIcons.strikethrough,
      label: NovidentEditorL10n.current.strikethrough,
      name: NovidentRichTextKeys.strikethrough,
    ),

    // Code
    TextDecorationUnit(
      icon: NovidentMobileIcons.code,
      label: NovidentEditorL10n.current.embedCode,
      name: NovidentRichTextKeys.code,
    ),
  ];

  @override
  Widget build(BuildContext context) {
    final style = MobileToolbarTheme.of(context);

    final bius = textDecorations.map((currentDecoration) {
      // Check current decoration is active or not
      final selection = widget.selection;
      final nodes = widget.editorState.getNodesInSelection(selection);
      final bool isSelected;
      if (selection.isCollapsed) {
        isSelected = widget.editorState.toggledStyle.containsKey(
          currentDecoration.name,
        );
      } else {
        isSelected = nodes.allSatisfyInSelection(selection, (delta) {
          return delta.everyAttributes(
            (attributes) => attributes[currentDecoration.name] == true,
          );
        });
      }

      return MobileToolbarItemMenuBtn(
        icon: NovidentMobileIcon(
          afMobileIcons: currentDecoration.icon,
          color: MobileToolbarTheme.of(context).iconColor,
        ),
        label: Text(currentDecoration.label),
        isSelected: isSelected,
        onPressed: () {
          setState(() {
            widget.editorState.toggleAttribute(
              currentDecoration.name,
              selectionExtraInfo: {
                selectionExtraInfoDoNotAttachTextService: true,
              },
            );
          });
        },
      );
    }).toList();

    return GridView(
      shrinkWrap: true,
      padding: EdgeInsets.zero,
      gridDelegate: buildMobileToolbarMenuGridDelegate(
        mobileToolbarStyle: style,
        crossAxisCount: 2,
      ),
      children: bius,
    );
  }
}
