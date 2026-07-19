import 'package:flutter/material.dart';
import 'package:novident_editor/novident_editor.dart';

import 'document_session.dart';

/// The Novident Editor surface shared by every view of the app (split
/// view panes, the zen view and the mobile view).
///
/// Vim mode is always wired in (its shortcuts take precedence over the
/// standard ones); when a [ZenModeController] is provided the zen visuals
/// (block dimming, ignored colors, typewriter scrolling) are enabled too.
class MyEditor extends StatelessWidget {
  const MyEditor({
    super.key,
    required this.session,
    this.zenController,
    this.padding = const EdgeInsets.symmetric(horizontal: 32, vertical: 0),
    this.autoFocus = false,
    this.footer,
  });

  final DocumentSession session;

  /// When non-null the editor renders with the zen visuals and disables
  /// the native caret auto-scroll in favor of the typewriter centering.
  final ZenModeController? zenController;

  final EdgeInsets padding;
  final bool autoFocus;

  /// Extra space after the last block (lets the zen view center the
  /// final paragraphs).
  final Widget? footer;

  @override
  Widget build(BuildContext context) {
    return NovidentEditor(
      editorState: session.editorState,
      editorScrollController: session.scrollController,
      focusNode: session.focusNode,
      autoFocus: autoFocus,
      disableAutoScroll: false,
      editorStyle: EditorStyle.desktop(
        padding: padding,
        cursorColor: Colors.black87,
        selectionColor: const Color(0x33448AFF),
        textStyleConfiguration: const TextStyleConfiguration(
          lineHeight: 1,
          text: TextStyle(fontSize: 12, color: Colors.black87),
        ),
        textSpanDecorator: zenController?.textSpanDecorator(),
      ),
      blockWrapper: zenController?.blockWrapper,
      footer: footer,
      commandShortcutEvents: <CommandShortcutEvent>[
        // vim shortcuts must come first so they take precedence.
        ...session.vimController.commandShortcutEvents,
        ...standardCommandShortcutEvents,
      ],
      characterShortcutEvents: standardCharacterShortcutEvents,
    );
  }
}
