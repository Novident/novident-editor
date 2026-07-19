<h1 align="center"><b>Novident Editor</b></h1>

<p align="center">A high-performance rich-text editor for Flutter — part of the <a href="https://github.com/Novident">Novident</a> suite.</p>

<p align="center">
    Fork of <a href="https://github.com/AppFlowy-IO/appflowy-editor"><b>AppFlowy Editor</b></a>,
    used under the <a href="LICENSE">Mozilla Public License 2.0</a>.
    See <a href="NOTICE">NOTICE</a> for attribution.
</p>

---

## What is Novident Editor?

Novident Editor is a **drop-in rich-text editor** for Flutter apps. It renders a document
tree built from composable block components — paragraphs, headings, lists, quotes, images,
tables, code blocks and more — and ships with:

- **vim emulation** (normal / insert / visual, remappable keybindings, pending operator `dd`)
- **zen mode** (typewriter centering, unfocused-block dimming, color neutralization without
  touching the document)
- **aggressive caching** throughout the document model, selection pipeline and text
  rendering — the editor stays responsive at 100k‑word documents with thousands of blocks 

---

## Quick start

```dart
import 'package:novident_editor/novident_editor.dart';
import 'package:flutter_localizations/flutter_localizations.dart';

void main() {
  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      localizationsDelegates: const [
        NovidentEditorLocalizations.delegate,
        GlobalMaterialLocalizations.delegate,
        GlobalWidgetsLocalizations.delegate,
        GlobalCupertinoLocalizations.delegate,
      ],
      home: Scaffold(
        body: NovidentEditor(
          editorState: EditorState.blank(withInitialText: true),
        ),
      ),
    );
  }
}
```

Or hydrate the editor from JSON / Markdown / Quill Delta — see
[Importing content](documentation/importing.md).

---

## Vim mode

Vim emulation is built into the package — no extra dependency. Every keybinding is
remappable at runtime, and changing bindings **does not rebuild the editor**:

```dart
final vimController = VimModeController();

NovidentEditor(
  editorState: editorState,
  commandShortcutEvents: [
    ...vimController.commandShortcutEvents,
    ...standardCommandShortcutEvents,
  ],
);

// After the editor is mounted:
vimController.attach(editorState);

// Remap any key at runtime:
vimController.configuration =
    vimController.configuration.rebind(VimCommand.moveLeft, 'a');
```

A `VimModeChip` widget is available in the example for status bars. Modes, the pending `dd` operator
and the block-cursor style are all observable via `vimController`.

You can also define your own `VimCommand` instances to extend the built-in set —
indent / outdent, custom insertions, or any editor operation.  See the full guide
at **[Vim Commands](documentation/vim-commands.md)**.

---

## Zen mode

Zen mode dims every top-level block that is **not** focused (animatable opacity),
ignores text / highlight / block-background colors (they stay in the document — disable
zen and they come back), and keeps the focused block vertically centered
(typewriter scrolling):

```dart
final zenController = ZenModeController();

NovidentEditor(
  editorState: editorState,
  editorScrollController: editorScrollController,
  blockWrapper: zenController.blockWrapper,
  editorStyle: EditorStyle.desktop(
    textSpanDecorator: zenController.textSpanDecorator(),
  ),
);
```

All colours (`font_color`, `bg_color`, block `bgColor`) are ignored **without ever
mutating the delta or the node attributes** — the visual pipeline neutralises them
while the `blockWrapper` dims the unfocused blocks. This means zen mode can be toggled
on and off with zero document churn.

---

## Word & character counter

Each `EditorState` can be connected to a `WordCountService` that debounces on
transactions and exposes `documentCounters` / `selectionCounters` through a
`ChangeNotifier`. Use a `ListenableBuilder` to build a live counter chip:

```dart
final counter = WordCountService(editorState: editorState)..register();

ListenableBuilder(
  listenable: counter,
  builder: (context, _) => Text(
    '${counter.documentCounters.wordCount} words  '
    '${counter.documentCounters.charCount} chars',
  ),
);
```

---

## Customising block components

Overriding a built-in block or adding a new one is done via
`blockComponentBuilders` — the `standardBlockComponentBuilderMap` is a
convenient base that you can spread and override:

```dart
NovidentEditor(
  editorState: editorState,
  blockComponentBuilders: {
    ...standardBlockComponentBuilderMap,
    'my_custom_type': MyCustomBlockBuilder(),
  },
);
```

See [`documentation/customizing.md`](documentation/customizing.md) for a
detailed walkthrough.

---

## License

Novident Editor is a fork of **AppFlowy Editor**
([AppFlowy-IO/appflowy-editor](https://github.com/AppFlowy-IO/appflowy-editor)).
Upstream is dual-licensed under the GNU Affero General Public License v3 and the
Mozilla Public License 2.0.

This fork is used and distributed under the **Mozilla Public License 2.0**.
See [LICENSE](LICENSE) and [NOTICE](NOTICE) for full details.
