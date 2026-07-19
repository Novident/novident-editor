import 'package:novident_editor/novident_editor.dart';
import 'package:novident_editor/src/editor/util/platform_extension.dart';
import 'package:flutter/foundation.dart';

String shortcutTooltips(
  String? macOSString,
  String? windowsString,
  String? linuxString,
) {
  if (kIsWeb) return '';
  if (PlatformExtension.isMacOS && macOSString != null) {
    return '\n$macOSString';
  } else if (PlatformExtension.isWindows && windowsString != null) {
    return '\n$windowsString';
  } else if (PlatformExtension.isLinux && linuxString != null) {
    return '\n$linuxString';
  }
  return '';
}

String getTooltipText(String id) {
  switch (id) {
    case 'underline':
      return '${NovidentEditorL10n.current.underline}${shortcutTooltips('⌘ + U', 'CTRL + U', 'CTRL + U')}';
    case 'bold':
      return '${NovidentEditorL10n.current.bold}${shortcutTooltips('⌘ + B', 'CTRL + B', 'CTRL + B')}';
    case 'italic':
      return '${NovidentEditorL10n.current.italic}${shortcutTooltips('⌘ + I', 'CTRL + I', 'CTRL + I')}';
    case 'strikethrough':
      return '${NovidentEditorL10n.current.strikethrough}${shortcutTooltips('⌘ + SHIFT + S', 'CTRL + SHIFT + S', 'CTRL + SHIFT + S')}';
    case 'code':
      return '${NovidentEditorL10n.current.embedCode}${shortcutTooltips('⌘ + E', 'CTRL + E', 'CTRL + E')}';
    case 'align_left':
      return NovidentEditorL10n.current.textAlignLeft;
    case 'align_center':
      return NovidentEditorL10n.current.textAlignCenter;
    case 'align_right':
      return NovidentEditorL10n.current.textAlignRight;
    case 'text_direction_auto':
      return NovidentEditorL10n.current.auto;
    case 'text_direction_ltr':
      return NovidentEditorL10n.current.ltr;
    case 'text_direction_rtl':
      return NovidentEditorL10n.current.rtl;
    default:
      return '';
  }
}
