import 'package:novident_editor/novident_editor.dart';

final codeMobileToolbarItem = MobileToolbarItem.action(
  itemIconBuilder: (context, __, ___) => NovidentMobileIcon(
    afMobileIcons: NovidentMobileIcons.code,
    color: MobileToolbarTheme.of(context).iconColor,
  ),
  actionHandler: (_, editorState) => editorState.toggleAttribute(
    NovidentRichTextKeys.code,
  ),
);
