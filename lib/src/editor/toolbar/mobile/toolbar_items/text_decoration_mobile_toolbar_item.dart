import 'package:novident_editor/novident_editor.dart';
import 'package:flutter/material.dart';

final textDecorationMobileToolbarItem = MobileToolbarItem.withMenu(
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
    TextDecorationUnit(
      icon: NovidentMobileIcons.bold,
      label: NovidentEditorL10n.current.bold,
      name: RichTextKeys.bold,
    ),
    TextDecorationUnit(
      icon: NovidentMobileIcons.italic,
      label: NovidentEditorL10n.current.italic,
      name: RichTextKeys.italic,
    ),
    TextDecorationUnit(
      icon: NovidentMobileIcons.underline,
      label: NovidentEditorL10n.current.underline,
      name: RichTextKeys.underline,
    ),
    TextDecorationUnit(
      icon: NovidentMobileIcons.strikethrough,
      label: NovidentEditorL10n.current.strikethrough,
      name: RichTextKeys.strikethrough,
    ),
  ];
  @override
  Widget build(BuildContext context) {
    final style = MobileToolbarTheme.of(context);
    final btnList = List.generate(textDecorations.length, (index) {
      final currentDecoration = textDecorations[index];
      // Check current decoration is active or not
      final selection = widget.selection;
      final isSelected = activeAttributeValue(
            widget.editorState,
            selection,
            currentDecoration.name,
          ) ==
          true;

      return MobileToolbarItemMenuBtn(
        icon: NovidentMobileIcon(
          afMobileIcons: currentDecoration.icon,
          color: MobileToolbarTheme.of(context).iconColor,
        ),
        label: Text(currentDecoration.label),
        isSelected: isSelected,
        onPressed: () {
          setState(() {
            widget.editorState.toggleAttribute(currentDecoration.name);
          });
        },
      );
    });

    return GridView(
      shrinkWrap: true,
      padding: EdgeInsets.zero,
      gridDelegate: buildMobileToolbarMenuGridDelegate(
        mobileToolbarStyle: style,
        crossAxisCount: 2,
      ),
      children: btnList,
    );
  }
}

class TextDecorationUnit {
  TextDecorationUnit({
    required this.icon,
    required this.label,
    required this.name,
  });
  final NovidentMobileIcons icon;
  final String label;
  final String name;
}
