import 'package:example/common/constants/contents/readme_document.dart'
    show kReadmeStripedTable, kReadmePlainTable, kReadmeAccentTable;
import 'package:flutter/material.dart';
import 'package:novident_editor/novident_editor.dart';

/// Workspace colors (shared by the desktop, mobile and zen views).
const Color kWorkspaceBackground = Color(0xFFECECEC);

/// Vim emulation is disabled on mobile: its normal mode would suppress
/// the soft keyboard input.
const VimModeConfiguration kMobileVimConfiguration = VimModeConfiguration(
  enabled: false,
);

/// Toolbar shown above the editor on desktop (top of the editor column).
final List<ToolbarItem> kDesktopToolbarItems = <ToolbarItem>[
  styleToolbarItem,
  buildFontSizeItem(),
  buildFontFamilyItem(fontFamilies: getDefaultFonts()),
  ...markdownFormatItems,
  quoteItem,
  bulletedListItem,
  numberedListItem,
  linkItem,
  ...alignmentItems,
];

/// Toolbar shown above the soft keyboard on mobile (bottom of the
/// editor column).
///
/// Same feature set as [kDesktopToolbarItems] expressed through the
/// mobile item system: style, text decoration, headings, todo lists,
/// lists, link, quote and code. Font size, font family and alignment
/// have no mobile counterpart widgets yet, so they are omitted.
final List<MobileToolbarItem> kMobileToolbarItems = <MobileToolbarItem>[
  styleMobileToolbarItem,
  textDecorationMobileToolbarItem,
  headingMobileToolbarItem,
  todoListMobileToolbarItem,
  listMobileToolbarItem,
  linkMobileToolbarItem,
  quoteMobileToolbarItem,
  codeMobileToolbarItem,
];

/// Editor styles shared by every editor surface of the app (desktop
/// panes, the mobile editor and their toolbars).
final NovidentStylesConfig kEditorStyles = NovidentStylesConfig(
  defaultStyle: kDefaultBaseStyle,
  registry: NovidentStyleRegistry({
    ...kDefaultStyleRegistry.styles,
    kReadmeStripedTable.id: kReadmeStripedTable,
    kReadmePlainTable.id: kReadmePlainTable,
    kReadmeAccentTable.id: kReadmeAccentTable,
  }),
  defaultStylesByType: <String, NovidentStyleDefinition>{
    'table': kDefaultTableStyle,
  },
);

final NovidentStyleDefinition kDefaultBaseStyle = NovidentStyleDefinition(
  id: '__novident_base__',
  name: 'Base',
  fontSize: 12.0,
  fontFamily: getDefaultFont(),
  textColor: Colors.black,
  spacing: NovidentStyleSpacing(lineHeight: 1.0),
  indent: NovidentStyleIndent.defaultLineFilter(),
);
