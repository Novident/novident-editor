# AGENTS.md

Flutter rich-text editor — **Novident Editor**, a fork of [AppFlowy Editor](https://github.com/AppFlowy-IO/appflowy-editor) (MPL 2.0, see `NOTICE`). Monorepo: root package `novident_editor` + extracted packages under `packages/` + demo app under `example/`.

## Non-negotiable gotchas

- **`packages/` source is NOT what root/example consume.** Root and `example/` depend on `novident_editor_*` via **pub.dev version constraints** (`^1.0.x`), not path deps (verified in `pubspec.lock`: `source: hosted`). Editing a package's source has **zero effect** on root/example builds or tests until you publish a new version and bump the constraint. To test a package change locally, add `dependency_overrides: novident_editor_<x>: {path: packages/novident_editor_<x>}` to the consuming pubspec, then `flutter pub get`.
- **Never run `flutter test` in `example/`.** CI analyzes it only; its tests were never meant to run and fail on a missing library. Don't "fix" them.
- **`lib/src/l10n/intl/messages_*.dart` is generated.** Edit ARB files in `lib/l10n/` only, then run `flutter pub run intl_utils:generate`. Generated files are analyzer-excluded (`analysis_options.yaml`); never hand-edit them.
- **`lib/src/flutter/scrollable_positioned_list/` is a vendored fork** of the pub package — edit the vendored copy, never add the pub dependency.
- **Flutter is pinned to 3.32.4** (`.fvmrc`). Use `fvm flutter` when fvm is available.

## Directory tree (where everything lives)

```
lib/
├── novident_editor.dart                     # public barrel: re-exports packages + src layers
└── src/
    ├── core/                                # document model + transforms
    │   ├── core.dart                        # barrel
    │   ├── document/                        # Node, Path, Attributes, TextDelta, Document, Diff, NodeIterator
    │   │   ├── deprecated/                  # legacy Document/Node — do not use
    │   │   └── rules/                       # DocumentRule (at_least_one_editable_node_rule)
    │   ├── legacy/                          # built_in_attribute_keys (legacy)
    │   └── transform/                       # Operation, Transaction
    ├── editor/
    │   ├── editor.dart                      # barrel
    │   ├── block_component/                 # one directory per block type
    │   │   ├── base_component/              # shared mixins/commands: align, indent, outdent, text_direction,
    │   │   │                                #   insert_newline_in_type, convert_to_paragraph, auto_complete…
    │   │   ├── <type>_block_component/      # bulleted_list, divider, heading, image, numbered_list,
    │   │   │                                #   paragraph, quote, table, todo_list
    │   │   └── standard_block_components.dart  # standardBlockComponentBuilderMap (public API)
    │   ├── command/                         # selection_commands, text_commands, transform
    │   ├── editor_component/
    │   │   ├── editor_component.dart        # NovidentEditor widget (public API)
    │   │   ├── entry/                       # page_block_component
    │   │   └── service/
    │   │       ├── editor.dart, editor_service.dart
    │   │       ├── ime/                     # delta_input_*, non_delta_input_service, text_diff, text_input_service
    │   │       ├── keyboard_service.dart / _widget.dart
    │   │       ├── renderer/  scroll/  selection/
    │   │       └── shortcuts/               # composable KeyboardStrategy: character/, character_shortcut_events/,
    │   │                                    #   command/ (page_commands, arrow_*, …)
    │   ├── find_replace_menu/
    │   ├── l10n/                            # NovidentEditorL10n (runtime strings)
    │   ├── selection_menu/
    │   ├── spell_check/                     # spell_check_service, spell_check_span_pipeline
    │   ├── toolbar/                         # desktop/ (static_toolbar, items/color, items/link) + mobile/
    │   ├── util/                            # debounce, delta_util, file_picker/, link_util, platform_extension…
    │   ├── vim_mode/                        # vim_mode_controller, vim_keyboard_strategy, vim_selection_renderer,
    │   │                                    #   vim_mode_configuration, vim_mode_shortcuts
    │   └── zen_mode/                        # zen_mode_controller, block_wrapper, text_span_decorator
    ├── editor_state.dart                    # EditorState — single mutable state (public API)
    ├── extensions/                          # node, position, attributes, color, theme, alignment extensions
    ├── flutter/                             # vendored forks of Flutter ecosystem code
    │   └── scrollable_positioned_list/      # vendored fork (see gotchas)
    ├── history/                             # undo_manager
    ├── infra/                               # clipboard, editor_svg, log, mobile/
    ├── l10n/                                # l10n.dart barrel (generated intl/ lives here too)
    ├── plugins/                             # import/export formats
    │   ├── html/                            # html_document, encoder/ (delta_html_encoder, parser/), decoder
    │   ├── markdown/                        # decoder/ (parser/, custom_syntaxes/), encoder/ (parser/)
    │   ├── quill_delta/                     # quill_delta_encoder
    │   ├── word_count/                      # word_counter_service
    │   └── blocks/columns/                  # column_block_component, columns_block_component
    ├── render/                              # color_menu/, selection/ (cursor_appearance, mobile handles), toolbar/
    └── service/                             # context_menu/, default_text_operations/, internal_key_event_handlers/,
                                             #   selection/ (gestures), shortcut_event/ (keybinding, key_mapping)

packages/                                    # ← the "corte": layers extracted from the original editor
├── novident_document/                       # PUBLISHED novident_editor_document 1.0.6 — nodes, delta, paths, attributes
├── novident_editor_core/                    # PUBLISHED 1.0.3 — Position/Selection/SelectableMixin, text rendering config
├── novident_editor_styles/                  # PUBLISHED 1.0.3 — style definitions, registry, font provider
├── novident_editor_selection/               # PUBLISHED 1.0.5 — cursor, block selection, painters
├── novident_editor_rich_text/               # PUBLISHED 1.0.4 — NovidentRichText + 6-phase span pipeline
└── novident_editor_spell_check_interface/   # PUBLISHED 1.0.0 — pure-Dart spell-check contract (no Flutter dep)

test/                                        # mirrors lib/ structure (documentation/testing.md)
├── test_helper.dart                         # buildAndPump extension (localizations + pump)
├── core/  customer/  editor/  mobile/  performance/  plugins/  render/  service/  spell_check/
└── new/                                     # current test home: block_component/, command/, editor_component/,
                                             #   find_replace_menu/, infra/ (TestableEditor), service/, toolbar/,
                                             #   util/ (keyboard_util, node_util, …), vim_mode/

example/lib/                                 # demo app (analyze-only in CI)
├── main.dart
├── common/                                  # configurations/ (builders, tree_configs, widgets), constants/
│                                            #   (chapter contents), controller/, nodes/ (directory, file, root), store/
├── cursor_renderers/                        # block_aware_cursor_renderer, rainbow_selection_renderer
├── extensions/                              # node_ext, num_ext
├── spell_check/                             # Hunspell en_US checker + worker isolate (reference impl)
└── widgets/                                 # drawer/, editor/ (document_session, editor_configuration, my_editor,
                                             #   session_controller, vim_mode_chip, word_count_chip, zen_editor_view),
                                             #   views/ (android_view, desktop_view)

documentation/                               # feature guides (styles, tables, vim-commands, customizing,
                                             #   importing, testing, translation, migrations/, performance-*)
.plans/                                      # numbered implementation plans (Spanish, gitignored) + validate/*.sh
```

## Layering rules (strict)

```
novident_editor_spell_check_interface   (pure Dart, no Flutter — standalone contract)

novident_editor_document                (base: nodes, delta, paths, attributes)
        ^
novident_editor_core                    (Position, Selection, SelectableMixin, text rendering config)
       ^        ^
  styles ─┘  selection                  (style registry/font provider)  (cursor, block selection, painters)
       ^        ^
       └── rich_text ──┘                (NovidentRichText + 6-phase span pipeline)
              ^
      novident_editor (root)            (block components, services, plugins, toolbar, vim/zen...)
```

- `novident_editor_document` knows nothing about selection, styles, or rendering — only the node tree, rich-text Delta, paths, and attributes.
- `novident_editor_core` depends only on document; `novident_editor_styles` and `novident_editor_selection` depend only on document + core; `novident_editor_rich_text` depends on document + core + styles + selection.
- The root `novident_editor` is the **only** place for block components, editor services, plugins, toolbar, vim/zen, and find & replace.
- `novident_editor_spell_check_interface` must stay pure Dart — no `flutter` import, ever.
- Never let a lower layer import a higher one; a package must not import the root `novident_editor` or a sibling it doesn't already depend on.

## Design conventions

- **Keyboard handling is composable**: `KeyboardStrategy` policies in `service/shortcuts/`. The old `characterShortcutEvents`/`commandShortcutEvents` params are deprecated (1.0.5 breaking change) — use `keyboardStrategies`.
- **Selection rendering**: implement `SelectionRenderer`; the deprecated head-cursor methods (`buildExpandedHeadCursor`, `paintExpandedHeadCursor`, `expandedHeadPosition`) are replaced by computing the head and injecting it into the rects in `onSelectionRectsMeasured` (see `VimSelectionRenderer`).
- **Spell check runs out of band**: analysis after typing inactivity, marks stored in the delta, render pipeline underlines; no checker call inside `build`.
- **IME**: text input goes through the `ime/` services (`delta_input_*`, `non_delta_input_service`, `text_diff`).

## Entry points (public API)

| Symbol | Location |
|---|---|
| `NovidentEditor` widget | `lib/src/editor/editor_component/editor_component.dart` |
| `EditorState` | `lib/src/editor_state.dart` |
| Public barrel | `lib/novident_editor.dart` |
| `standardBlockComponentBuilderMap` | `lib/src/editor/block_component/standard_block_components.dart` |
| `NovidentEditorLocalizations` | `lib/src/l10n/l10n.dart` (generated from `lib/l10n/intl_*.arb`) |

## Commands

```bash
# Root package
flutter pub get
flutter analyze --no-fatal-infos --no-fatal-warnings
flutter test                          # whole suite
flutter test test/new/vim_mode/vim_mode_test.dart   # single file

# A single package (only dirs with pubspec.yaml are real packages)
cd packages/novident_editor_styles && flutter pub get && flutter analyze && flutter test

# l10n regeneration after editing ARB files
flutter pub run intl_utils:generate

# Example: analyze ONLY — never test
cd example && flutter pub get && flutter analyze --no-fatal-infos --no-fatal-warnings
```

## CI (`.github/workflows/ci.yml` — what must pass)

1. Root: `flutter analyze` + `flutter test`.
2. Packages: for each `packages/*/` **with a pubspec.yaml**, `pub get` + `analyze` + `test` (only if `test/` exists).
3. Example: `pub get` + `analyze` only — **no tests** (intentional).
4. `commitlint.yml`: Conventional Commits (`commitlint.config.mjs`).

## Structure preservation rules (the pattern to keep)

- **One concern per file**, barrel files per layer (`core.dart`, `editor.dart`, `plugins.dart`, `extensions.dart`, `util.dart`…). New public symbols must be exported from the layer barrel and, if part of the public API, from `lib/novident_editor.dart`.
- **Block components**: new block types go in `lib/src/editor/block_component/<type>_block_component/` with `<type>_block_component.dart` + `<type>_character_shortcut.dart` (+ `<type>_command_shortcut.dart` when it has commands), registered in `standard_block_components.dart`.
- **Services** live under `lib/src/editor/editor_component/service/<domain>/`; keyboard handling is composable via `KeyboardStrategy` policies in `service/shortcuts/`.
- **Plugins** (import/export formats) go under `lib/src/plugins/<format>/` with `decoder/` and `encoder/` subdirs and per-node parsers.
- **Tests mirror the source path** under `test/` (or `test/new/` for the current suite). Use existing helpers — `test/test_helper.dart` (`buildAndPump`), `test/new/infra/testable_editor.dart` (`TestableEditor`), `test/new/util/` — don't invent new harnesses.
- **Lint** (`analysis_options.yaml`): `require_trailing_commas`, `prefer_final_locals`, `prefer_final_fields`, `always_declare_return_types`, `unawaited_futures`, `sort_constructors_first`. Keep files `dart format`-clean.
- **Legacy dirs** (`core/document/deprecated/`, `core/legacy/`) are AppFlowy leftovers — don't extend them; migrate callers off them.

## Testing requirements (mandatory)

Every fix, modification, or feature **must** ship with tests. A change without tests is incomplete — do not consider it done.

- **Where the tests go depends on what you touched:**
  - Root package (`lib/`): mirror the source path under `test/` (current suite: `test/new/`).
  - A package (`packages/<name>/`): add tests under `packages/<name>/test/` mirroring that package's `lib/` structure.
- **Coverage expectations:**
  - The happy path of the change.
  - **Edge cases**: empty input, boundary offsets (0 and length), collapsed vs expanded selections, multi-node selections, absent/null attributes, repeated operations (undo/redo), remote transactions.
  - **Real-world cases**: the concrete user scenario that motivated the change (a specific typing sequence, paste, IME composition, a particular document shape).
- **Regression tests**: a bug fix must include a test that fails on the old code and passes on the new code.
- **Use the existing harnesses** — `test/test_helper.dart` (`buildAndPump`), `test/new/infra/testable_editor.dart` (`TestableEditor`), `test/new/util/` — don't invent new ones.
- Run the suite for the touched layer before finishing: `flutter test` (root) or `cd packages/<name> && flutter test`.

## Roadmap context

- **Done** (CHANGELOG): layered extraction (1.0.4), style system + font provider + static toolbar (1.0.3), vim emulation, zen mode, spell check, tables, named styles with `basedOn`, `keyboardStrategies` (1.0.5).
- **Next** (README roadmap): Zen mode performance, full customization of every default block, richer clipboard (currently plain text), translations, typewriter scrolling without Zen, uncouple keyboard/scroll services.
