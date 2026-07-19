import 'package:novident_editor/novident_editor.dart';

final quoteMobileToolbarItem = MobileToolbarItem.action(
  itemIconBuilder: (context, __, ___) => NovidentMobileIcon(
    afMobileIcons: NovidentMobileIcons.quote,
    color: MobileToolbarTheme.of(context).iconColor,
  ),
  actionHandler: (context, editorState) async {
    final selection = editorState.selection;
    if (selection == null) {
      return;
    }
    final node = editorState.getNodeAtPath(selection.start.path);
    if (node == null) {
      return;
    }
    final isQuote = node.type == QuoteBlockKeys.type;
    editorState.formatNode(
      selection,
      (node) => node.copyWith(
        type: isQuote ? ParagraphBlockKeys.type : QuoteBlockKeys.type,
        attributes: {
          ParagraphBlockKeys.delta: (node.delta ?? Delta()).toJson(),
        },
      ),
    );
  },
);
