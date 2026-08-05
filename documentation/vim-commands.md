# Vim Commands

Novident Editor ships with a built-in vim emulation layer.  Every keybinding is
remappable at runtime through `VimModeController`, and you can define your own
`VimCommand` instances to extend the built-in set with custom behaviour.

---

### `VimMode`

```dart
enum VimMode { normal, insert, visual }
```

---

## Architecture overview

```
VimModeConfiguration        VimModeController           Editor
┌──────────────────┐       ┌───────────────────┐       ┌────────┐
│ defaultKeybindings│       │ _events          │       │        │
│ _rawKeybindings  │──▶───│ _configuration  │──▶───│ Novident│
│ keybindings (get)│       │ buildVimMode...  │       │ Editor │
│ commandOf()      │       │ commandShortcut..│       │        │
│ rebind()         │       └───────────────────┘       └────────┘
└──────────────────┘
```

1. **`VimCommand`** — a lightweight identity class.  Two commands are equal when
   their `code` integers match, so pick unique codes for your custom commands
   (values ≥ 100 are safe).

2. **`VimModeConfiguration`** — holds the raw user overrides and resolves them
   against the built-in defaults.  Conflict resolution ensures no two commands
   share the same key: when an explicit override uses a key that another
   command's default needs, that other command is unbound.

3. **`VimModeController`** — owns the runtime state (mode, pending operator,
   active configuration).  It builds one `CommandShortcutEvent` per known
   command and exposes them through `commandShortcutEvents`.

4. **`buildVimModeCommandShortcutEvents`** — the factory that wires every
   `VimCommand` to a `CommandShortcutEvent` with separate handlers for
   normal / visual / insert modes.

---

## Quick start

```dart
import 'package:novident_editor/novident_editor.dart';

final vimController = VimModeController();

NovidentEditor(
  editorState: editorState,
  editorStyle: EditorStyle.desktop(
    // Pass the vim renderer so the block cursor is painted in
    // normal/visual mode. The renderer delegates to the standard
    // caret in insert mode automatically.
    selectionRenderer: VimSelectionRenderer(
      controller: vimController,
    ),
  ),
  commandShortcutEvents: [
    // vim shortcuts must come first so they take precedence.
    ...vimController.commandShortcutEvents,
    ...standardCommandShortcutEvents,
  ],
);

// After the editor is mounted (e.g. in a post-frame callback):
vimController.attach(editorState);

// Remap any built-in command at runtime:
vimController.configuration =
    vimController.configuration.rebind(VimCommand.moveLeft, 'a');
```

Key points:
- The vim events **must be prepended** to the shortcut list so they intercept
  keys before the standard shortcuts do.
- `attach` registers an IME interceptor that suppresses typing outside of insert
  mode.
- Rebinding happens in-place on the cached `CommandShortcutEvent`s — **no
  editor rebuild is required**.

---

## Built-in commands

| Command                        | Default binding                  | Code |
|--------------------------------|----------------------------------|------|
| `enterNormalMode`              | `escape`                         | 0    |
| `enterInsertMode`              | `i`                              | 1    |
| `enterVisualMode`              | `v`                              | 2    |
| `enterInsertModeAfter`         | `a`                              | 3    |
| `enterInsertModeLineStart`     | `shift+i`                        | 4    |
| `enterInsertModeLineEnd`       | `shift+a`                        | 5    |
| `openLineBelow`                | `o`                              | 6    |
| `openLineAbove`                | `shift+o`                        | 7    |
| `enterVisualLineMode`          | `shift+v`                        | 8    |
| `moveLeft`                     | `h`                              | 9    |
| `moveDown`                     | `j`                              | 10   |
| `moveUp`                       | `k`                              | 11   |
| `moveRight`                    | `l`                              | 12   |
| `moveWordForward`              | `e`                              | 13   |
| `moveWordBackward`             | `b`                              | 14   |
| `moveLineStart`                | `digit 0`                        | 15   |
| `moveLineEnd`                  | `shift+digit 4`                  | 16   |
| `moveDocumentStart`            | `g`                              | 17   |
| `moveDocumentEnd`              | `shift+g`                        | 18   |
| `moveBlockPrevious`            | `{,shift+bracket left,…`         | 19   |
| `moveBlockNext`                | `},shift+bracket right,…`        | 20   |
| `pageUp`                       | `ctrl+u`                         | 21   |
| `pageDown`                     | `ctrl+d`                         | 22   |
| `deleteUnderCursor`            | `x`                              | 23   |
| `deleteLine`                   | `d`                              | 24   |
| `yank`                         | `y`                              | 25   |
| `paste`                        | `p`                              | 26   |
| `undo`                         | `u`                              | 27   |
| `redo`                         | `ctrl+r`                         | 28   |

Every binding in the right column is expressed in the editor's
[shortcut command format](#key-binding-format).

---

## Key binding format

Bindings follow the same syntax as `CommandShortcutEvent.command` — a
comma-separated list of `modifier+key` tokens:

```
h                     plain key
shift+g               key with modifier
ctrl+shift+d          multiple modifiers
a,arrow left          two alternative bindings for the same command
{,shift+brace left    literal symbols translated to key names automatically
```

Modifiers: `alt`, `ctrl`, `shift`, `meta`, `cmd`, `win`.  Keys use Flutter's
`LogicalKeyboardKey` names (lowercase): `escape`, `enter`, `arrow left`,
`backspace`, `digit 0`, `brace left`, `bracket left`, `space`, `tab`, `f1`…

Single-character symbols (`{`, `}`, `$`, `!`, `(`, etc.) are automatically
translated to their key names, so you can write `{` instead of `brace left`.

---

## Remapping at runtime

Use `rebind` on the current configuration.  The change takes effect
immediately — the shortcut events are updated in-place:

```dart
vimController.configuration =
    vimController.configuration.rebind(VimCommand.moveLeft, 'a');

// Or rebind multiple commands at once:
vimController.configuration = VimModeConfiguration(
  keybindings: {
    VimCommand.moveLeft:  'arrow left',
    VimCommand.moveDown:  'arrow down',
    VimCommand.moveUp:    'arrow up',
    VimCommand.moveRight: 'arrow right',
  },
);
```

When a manual override steals a key from another command's default binding,
that command is automatically unbound.  For example, rebinding `moveLeft` to
`a` unbinds `enterInsertModeAfter` (which also uses `a` by default).

---

## Creating custom VimCommand

Built-in commands use codes 0–28.  Pick any integer ≥ **100** for your own
commands to avoid future collisions:

### 1. Define the command

```dart
/// Your custom vim commands.
class MyVimCommands {
  MyVimCommands._();

  /// Indents the current node by one level (vim's `>`).
  static const indent = VimCommand(101);

  /// Outdents the current node by one level (vim's `<`).
  static const outdent = VimCommand(102);

  /// Inserts a horizontal divider below the current line.
  static const insertDivider = VimCommand(103);
}
```

### 2. Wire the handlers

The editor already ships with `indentCommand` and `outdentCommand` — we can
delegate to them.  For the divider we write a small inline handler:

```dart
import 'package:novident_editor/novident_editor.dart';
import 'package:flutter/services.dart';

Map<VimCommand, CommandShortcutEvent> buildCustomVimEvents(
  VimModeController controller,
) {
  return {
    MyVimCommands.indent: event(
      MyVimCommands.indent,
      controller: controller,
      onNormal: (editorState, _) => indentCommand.handler(editorState),
      onVisual: (editorState, _) => indentCommand.handler(editorState),
    ),
    MyVimCommands.outdent: event(
      MyVimCommands.outdent,
      controller: controller,
      onNormal: (editorState, _) => outdentCommand.handler(editorState),
      onVisual: (editorState, _) => outdentCommand.handler(editorState),
    ),
    MyVimCommands.insertDivider: event(
      MyVimCommands.insertDivider,
      controller: controller,
      onNormal: (editorState, _) {
        final selection = editorState.selection;
        if (selection == null) return KeyEventResult.ignored;
        final transaction = editorState.transaction;
        transaction.insertNode(
          selection.end.path.next,
          dividerBlockNode(),
        );
        transaction.afterSelection = Selection.collapsed(
          Position(path: selection.end.path.next),
        );
        editorState.apply(transaction);
        return KeyEventResult.handled;
      },
    ),
  };
}
```

### 3. Provide bindings and register

```dart
final vimController = VimModeController(
  configuration: VimModeConfiguration(
    keybindings: {
      MyVimCommands.indent:        'shift+period',   // >
      MyVimCommands.outdent:       'shift+comma',     // <
      MyVimCommands.insertDivider: 'ctrl+shift+minus', // Ctrl+Shift+-
    },
  ),
);

NovidentEditor(
  editorState: editorState,
  commandShortcutEvents: [
    // Custom vim events take precedence over built-in ones.
    ...buildCustomVimEvents(vimController).values,
    ...vimController.commandShortcutEvents,
    ...standardCommandShortcutEvents,
  ],
);
```

Because `VimCommand` equality is based on the `code` integer, your custom
commands can be stored in `VimModeConfiguration.keybindings` and resolved
exactly like the built-in ones.

---

## Cursor styling

The vim emulation uses a **block cursor** in normal and visual mode, rendered
through a `VimSelectionRenderer` that is passed to `EditorStyle.desktop()`.
The insert-mode caret is never altered — the standard thin blinking line is
preserved.

### Configuring the block cursor

The block cursor is styled through `VimCursorStyle`, accessible from
`VimModeConfiguration.cursorStyle`:

```dart
final vimController = VimModeController(
  configuration: VimModeConfiguration(
    cursorStyle: VimCursorStyle(
      color: Colors.purple,      // defaults to EditorStyle.cursorColor
      opacity: 0.55,             // 0.0 – 1.0, keep text readable underneath
      blink: false,              // steady block (default), set true to blink
      blockWidth: null,          // null = auto-measure the character width
      minBlockWidthFactor: 0.4,  // lower clamp × caret height
      maxBlockWidthFactor: 1.0,  // upper clamp × caret height
    ),
  ),
);

NovidentEditor(
  editorState: editorState,
  editorStyle: EditorStyle.desktop(
    cursorColor: Colors.black87,  // insert-mode caret color
    selectionRenderer: VimSelectionRenderer(
      controller: vimController,
    ),
  ),
  commandShortcutEvents: [
    ...vimController.commandShortcutEvents,
    ...standardCommandShortcutEvents,
  ],
);
```

### Width policy

When `blockWidth` is null (default), the renderer measures the character
under the caret from the text layout and clamps the result between
`minBlockWidthFactor` and `maxBlockWidthFactor` (both relative to the caret
height). This keeps the block usable on whitespace (too narrow) and on
ligatures / tabs / wide glyphs (too wide).

Set `blockWidth` to a fixed value to override the measurement entirely.

### Changing the style at runtime

The cursor style can be changed at runtime **without rebuilding the editor** —
the `SelectionRenderer` reads the current `VimCursorStyle` from the controller
on every frame:

```dart
vimController.configuration = vimController.configuration.copyWith(
  cursorStyle: const VimCursorStyle(
    color: Colors.red,
    blockWidth: 20,
    blink: true,
  ),
);
```

### How it works

The `VimSelectionRenderer` implements the `SelectionRenderer` interface from
`novident_selection`. In normal/visual mode it paints a `VimBlockCursor`
(a semi-transparent `Container` that covers the character at the caret),
while in insert mode every call delegates to the fallback `DefaultSelectionRenderer`
(the standard thin caret). The mode switch triggers a repaint automatically
via the editor's selection notifier — no manual rebuild required.

---

## Observing state

`VimModeController` extends `ChangeNotifier`.  Subscribe to react to mode
changes, pending operators, and binding updates:

```dart
vimController.addListener(() {
  print('Mode: ${vimController.mode}');
  print('Pending: ${vimController.pendingCommand}');
  print('Enabled: ${vimController.enabled}');
});
```


## Toggling vim on / off

```dart
// Programmatically:
vimController.configuration =
    vimController.configuration.copyWith(enabled: false);

// Or with the convenience method:
vimController.toggleEnabled();
```

When the emulation is disabled, the controller falls back to insert mode and
all key events are forwarded to the standard editor shortcuts.

---

## API reference

### `VimCommand`

```dart
class VimCommand {
  final int code;
  const VimCommand(this.code);

  // Two commands are equal when their codes match.
  // Built-in codes: 0–28.  Use ≥ 100 for custom commands.
}
```

### `VimModeConfiguration`

| Member | Description |
|--------|-------------|
| `VimModeConfiguration({enabled, initialMode, ...})` | Const constructor with user overrides. |
| `VimModeConfiguration.defaultBindings({...})` | Non-const; spreads defaults under user overrides. |
| `keybindings` → `Map<VimCommand, String>` | **Resolved** map: defaults + conflict resolution + overrides. |
| `commandOf(VimCommand) → String?` | Effective binding for one command (falls back to defaults). |
| `rebind(VimCommand, String keys) → VimModeConfiguration` | Returns a copy with the command rebound. |
| `copyWith({enabled, initialMode, …, keybindings})` | Standard immutable copy. |

### `VimModeController`

| Member | Description |
|--------|-------------|
| `commandShortcutEvents → List<CommandShortcutEvent>` | Prepend to the editor. |
| `commandShortcutEventOf(VimCommand) → CommandShortcutEvent?` | Lookup by command (null for unknown). |
| `attach(EditorState)` / `detach()` | Bind / unbind to the editor. |
| `configuration` (get/set) | Read or replace the resolved configuration.  Setter updates bindings in-place. |
| `mode → VimMode` | Current mode (`normal`, `insert`, `visual`). |
| `pendingCommand → String?` | Armed operator (e.g. `'d'` for `dd`). |
| `enabled → bool` | Whether the emulation is active. |
| `toggleEnabled()` | Toggles the emulation. |
| `enterNormalMode()` / `enterInsertMode()` / `enterVisualMode()` | Mode transitions. |
| `enterVisualLineMode()` | Selects the whole current node (linewise `V`). |
| `dispose()` | Unbinds and cleans up. |
