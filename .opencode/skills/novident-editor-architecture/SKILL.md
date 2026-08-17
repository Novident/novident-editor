---
name: novident-editor-architecture
description: >-
  How the Novident Editor works internally: the three-layer model (Document → EditorState →
  NovidentEditor), the transaction mutation pipeline, undo/redo, the 6-phase span pipeline,
  keyboard strategies, IME, services, and feature subsystems (vim, zen, spell check, named
  styles, tables, plugins). Use whenever you need to understand data flow, modify behavior,
  debug rendering/selection/input, or extend a subsystem in this repo. If the user asks how
  something works, why a change behaves a certain way, or where to hook a new feature,
  consult this skill. For locating code, use novident-editor-navigation.
---

# Novident Editor — Architecture

How the system is wired together. For where files live, use `novident-editor-navigation`;
for the full detail, read `ARCHITECT.md`.

## The three-layer mental model

```
Document      →  the tree of nodes (paragraphs, headings, tables…) holding
                 rich-text Deltas and attributes. Pure data, serializable.
EditorState   →  the single mutable state: document, selection, styles,
                 services (undo, spell check, word count). Created once,
                 passed to the editor widget.
NovidentEditor →  the widget. Renders the document, forwards input, and
                 reflects every change back into the EditorState.
```

**All mutations flow through `EditorState.apply(Transaction)`.** Direct document mutation
bypasses undo/redo, selection updates, delta-change emission, and collaborative-editing
hooks — don't do it.

## Data model (`novident_editor_document`)

- **`Document`** — a tree of `Node`s rooted at a `page` node. `Node` extends
  `ChangeNotifier` + `LinkedListEntry<Node>`; every mutation notifies listeners so the
  render tree rebuilds.
- **`Node`** — `type` (string key selecting the `BlockComponentBuilder`), `attributes`
  (map; rich text lives in the `delta` attribute), `children`. Addressed by `Path` (list of
  child indices, e.g. `[0, 2]`).
- **`Delta`** — Quill-style rich text (insert/retain/delete with attributes), stored in the
  node's `delta` attribute. Single source of truth for text and inline formatting.
  `TextDocument`/`DocumentTree` were tried and reverted — storage is pure Delta.
- **Performance caches** (invalidated on mutation): children list cache; index-in-parent
  cache making `path` amortized O(1); delta parse cache keyed by raw attribute identity.
- **Delta-change events** — `Document.listenDeltaChanges` emits per-node
  `DeltaChangeEvent`s (start/end/shift) **after** a transaction applies. Only transactions
  emit; direct attribute writes never do. This is the hook spell check and other consumers
  use.

## The mutation pipeline

```
User/Command/IME → build Transaction (ops + selection) → EditorState.apply(transaction)
  → broadcast (before) on transactionStream
  → apply operations to Document (insert / update / delete / updateText)
  → emit delta changes to listeners
  → broadcast (after)
  → update selection from transaction.afterSelection
  → record operations into UndoManager history item
```

- **Operations** (`lib/src/core/transform/operation.dart`) — four invertible types:
  `InsertOperation`, `DeleteOperation`, `UpdateOperation` (merge attributes),
  `UpdateTextOperation` (compose a delta). Undo/redo is operation inversion.
- **Transaction** (`lib/src/core/transform/transaction.dart`) — list of operations +
  selection metadata (`beforeSelection`, `afterSelection`, `customSelectionType`, `reason`).
  Behaviors: consecutive text ops on the same node merge; `add()` transforms each new op
  against queued ones so paths stay valid; text edits accumulate per-node deltas in a
  compose map flushed lazily as one `UpdateTextOperation`; each text edit records a
  `DeltaChange` for post-apply emission.
- **Remote transactions** (`isRemote: true`) take a separate path that shifts the local
  selection to compensate for remote insert/delete before the cursor.
- **Undo/redo** (`lib/src/history/undo_manager.dart`) — `HistoryItem` collects ops +
  before/after selection; it can be **sealed** (debounced, default 50 ms) so a typing burst
  is one undo step. `FixedSizeStack` (default 200) backs both stacks. `undo()` inverts the
  ops (reverse order) and applies with `recordUndo: false, recordRedo: true`.

## Rendering

- **`NovidentEditor`** (StatefulWidget) composes services around the renderer:
  `Provider(editorState)` → `FocusScope` → `Overlay` → `KeyboardServiceWidget` →
  `SelectionServiceWidget` → `ScrollServiceWidget` → `renderer.build(root node)`. It writes
  configuration into the EditorState in `initState`/`didUpdateWidget` (`_updateValues`):
  `editorStyle`, `styles`, `fontProvider`, `editable`, `documentRules`, spell-check service
  lifecycle.
- **Block components** — each node type maps to a `BlockComponentBuilder`
  (`service/renderer/block_component_service.dart`) that builds a `BlockComponent` widget.
  The standard map is `standardBlockComponentBuilderMap`; consumers extend/override via the
  `blockComponentBuilders` parameter. Shared behavior lives in `base_component/` mixins and
  commands (align, indent, outdent, text direction, convert-to-paragraph,
  insert-newline-in-type, auto-complete…).
- **The 6-phase span pipeline** (`novident_editor_rich_text`) — `NovidentRichText` renders a
  node's delta through an abstract `NovidentTextSpanPipeline`:
  ```
  per TextInsert:  1 resolveStyle → 2 transformText → 3 emitSpans
  per node:        4 paintSelectionContrast (over the emitted spans)
  placeholder:     5 buildPlaceholder
  per node:        6 adjustSpan (over the root span)
  ```
  Phase 2 must not change UTF-16 length (document offsets are measured on the original
  text). Phase 3 may split text (spell-check marks, syntax highlighting) but returned spans
  must cover the text exactly. Implementations must be stateless w.r.t. the phases.
  `DefaultNovidentTextSpanPipeline` reproduces legacy behavior; `SpellCheckSpanPipeline`
  plugs in at phase 3.
- **Selection rendering** (`novident_editor_selection`) — `SelectionRenderer` is the full
  control surface for cursor/selection appearance and movement. The deprecated head-cursor
  methods (`buildExpandedHeadCursor`, `paintExpandedHeadCursor`, `expandedHeadPosition`) are
  replaced by computing the head and injecting it into the rects in
  `onSelectionRectsMeasured` (see `VimSelectionRenderer`). Selected via
  `EditorStyle.selectionRenderer`.

## Input handling

- **Keyboard** — a list of `KeyboardStrategy` policies consulted in order; the first that
  does not return `ignored` wins. `DefaultEditorStrategy` wraps the classic character/
  command shortcut lists; `VimStrategy` intercepts keys outside insert mode. The deprecated
  `characterShortcutEvents`/`commandShortcutEvents` widget params are bridged into a
  `DefaultEditorStrategy` when `keyboardStrategies` is empty.
- **IME** (`service/ime/`) — soft-keyboard/IME input goes through `DeltaInputService`
  (delta-driven), `NonDeltaInputService` (plain-text fallback), `TextDiff` (diffing
  composed text), and the `delta_input_on_*` implementations. This layer is what makes
  Korean/Japanese IME composition work.
- **Selection gestures** (`service/selection/`) — `SelectionGesture` (desktop) and
  `MobileSelectionGesture` (touch) translate pointer events into selection updates through
  `updateSelectionWithReason`, which routes through the active `SelectionRenderer` and
  completes after the frame for UI events.

## Services (`EditorService`)

`EditorState.service` holds GlobalKeys into the widget tree's service widgets:

| Service | Key | Role |
|---|---|---|
| `rendererService` | — (assigned) | `BlockComponentRenderer` — maps node type → builder |
| `selectionService` | `selectionServiceKey` | selection state, gestures, context menu |
| `keyboardService` | `keyboardServiceKey` | keyboard strategies + IME input |
| `scrollService` | `scrollServiceKey` | scrolling, auto-scroll |

## Feature subsystems

- **Vim mode** (`lib/src/editor/vim_mode/`) — `VimModeController` owns the mode
  (normal/insert/visual), the pending operator buffer, and a runtime-rebindable
  `configuration`. `VimStrategy` blocks IME input outside insert mode — the mode is the
  strategy's hardware↔IME correlation. `VimSelectionRenderer` paints the block cursor and
  injects the selection head into measured rects. `vimKeyboardStrategies(controller)`
  returns the strategy list.
- **Zen mode** (`lib/src/editor/zen_mode/`) — `ZenModeController` (a
  `ValueNotifier<ZenModeConfiguration>`) dims unfocused blocks via a `blockWrapper`,
  neutralizes colors via a `textSpanDecorator` (without touching the document), and keeps
  the focused block vertically centered (typewriter scroll) by driving the
  `EditorScrollController`. Disables native caret auto-scroll to avoid fighting it.
- **Spell check** (`lib/src/editor/spell_check/`) — out-of-band, Word-like: `SpellCheckService`
  listens to delta changes, marks nodes pending, a single global inactivity timer (debounce,
  default 600 ms) restarts on every change, and on expiry each pending node is re-analyzed
  entirely with `proofState: 'error'` marks injected into its delta. Marks are written
  **directly** via `node.updateAttributes` — never through transactions and never through
  `emitChanges` — so analysis can never loop on itself. The checker implements the pure-Dart
  `NovidentSpellChecker` contract; the reference Hunspell `en_US` impl lives in
  `example/lib/spell_check/` with parsing/affix/suggestions in a worker isolate.
- **Named styles** (`novident_editor_styles`) — `NovidentStyleRegistry` holds
  `NovidentStyleDefinition`s with `basedOn` inheritance; resolution is a three-tier fallback
  (explicit style → type default → global default). Base styles require `fontSize`,
  `fontFamily`, `textColor`. `NovidentFontProvider` supplies font families + a guaranteed
  non-null default.
- **Tables** (`lib/src/editor/block_component/table_block_component/`) — weight-based column
  layout filling the available width, with reusable `TableStyleDefinition`s. `TableNode.fromList`
  builds the tree; `table_commands.dart` the keyboard commands; `table_action_menu.dart` the
  row/column actions.
- **Find & replace** (`lib/src/editor/find_replace_menu/`) — search with match highlighting
  (results drive selection via `SelectionUpdateReason.searchHighlight`) and replace applied
  through transactions.
- **Plugins** (`lib/src/plugins/`) — import/export formats, each with `decoder/` and
  `encoder/` subdirs and per-node parsers, exposed as `Codec<Document, String>`:
  HTML (`NovidentEditorHTMLCodec`), Markdown (`NovidentEditorMarkdownCodec`), Quill Delta
  (encoder), word count (`WordCountService`).

## Data flow summary

```
Input (KeyboardStrategy / IME / gestures) → Transaction → EditorState.apply
  → Document (node tree + deltas) → BlockComponentRenderer → 6-phase span pipeline → UI
  → UndoManager (history items) → inverted Transaction → apply
```

**The invariant**: every mutation enters through `EditorState.apply` as a `Transaction`;
the document is the source of truth; the widget tree is a pure function of `EditorState` +
`Document`; every change is observable through the transaction streams and delta-change
events for collaboration and analysis features.

## Deeper dives

- `ARCHITECT.md` — the full architecture document (this skill is its condensed form).
- `AGENTS.md` — structure, conventions, commands, gotchas.
- `documentation/` — feature guides: `styles.md`, `tables.md`, `vim-commands.md`,
  `customizing.md`, `importing.md`, `testing.md`, `translation.md`,
  `components/table-architecture.md`, `performance-*.md`.