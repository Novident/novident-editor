---
name: novident-editor-navigation
description: >-
  Map of the Novident Editor monorepo (Flutter rich-text editor, fork of AppFlowy Editor).
  Tells you where every layer, package, service, plugin, block component, and test lives,
  plus the strict layering rules, public entry points, exact commands, and non-obvious
  gotchas. Use this skill whenever you work in this repository: to locate code without
  grep, to decide where a new block component / plugin / service / test belongs, to
  understand package boundaries, or to check the correct commands and conventions.
  If the user mentions novident_editor, the "corte", packages/, block components,
  EditorState, or any file under lib/ or packages/, consult this skill first.
---

# Novident Editor — Navigation Map

This skill is the embedded map of the repository. Read it before exploring — it replaces
grep-driven discovery. For how the system works (data flow, mutation pipeline, rendering),
use the `novident-editor-architecture` skill or read `ARCHITECT.md`.

## The monorepo at a glance

- **Root package** `novident_editor` — the editor itself: block components, services,
  plugins, toolbar, vim/zen, find & replace.
- **`packages/`** — the "corte": layers extracted from the original editor, each published
  independently to pub.dev. The root consumes them via **version constraints** (`^1.0.x`),
  not path deps.
- **`example/`** — demo app. CI analyzes it only; **never run its tests**.
- **`test/`** — mirrors `lib/` structure.
- **`documentation/`** — feature guides (styles, tables, vim, customizing, importing,
  testing, translation).

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
    │   │   ├── base_component/              # shared mixins/commands: align, indent, outdent,
    │   │   │                                #   text_direction, insert_newline_in_type, …
    │   │   ├── <type>_block_component/      # bulleted_list, divider, heading, image,
    │   │   │                                #   numbered_list, paragraph, quote, table, todo_list
    │   │   └── standard_block_components.dart  # standardBlockComponentBuilderMap (public API)
    │   ├── command/                         # selection_commands, text_commands, transform
    │   ├── editor_component/
    │   │   ├── editor_component.dart        # barrel
    │   │   ├── entry/                       # page_block_component
    │   │   └── service/
    │   │       ├── editor.dart              # NovidentEditor widget (public API)
    │   │       ├── editor_service.dart      # EditorService (GlobalKeys into service widgets)
    │   │       ├── ime/                     # delta_input_*, non_delta_input_service, text_diff
    │   │       ├── keyboard_service.dart / _widget.dart
    │   │       ├── renderer/  scroll/  selection/
    │   │       └── shortcuts/               # composable KeyboardStrategy: character/,
    │   │                                    #   character_shortcut_events/, command/ (page_commands, arrow_*)
    │   ├── find_replace_menu/
    │   ├── l10n/                            # NovidentEditorL10n (runtime strings)
    │   ├── selection_menu/
    │   ├── spell_check/                     # spell_check_service, spell_check_span_pipeline
    │   ├── toolbar/                         # desktop/ (static_toolbar, items/color, items/link) + mobile/
    │   ├── util/                            # debounce, delta_util, file_picker/, link_util, …
    │   ├── vim_mode/                        # vim_mode_controller, vim_keyboard_strategy,
    │   │                                    #   vim_selection_renderer, vim_mode_configuration
    │   └── zen_mode/                        # zen_mode_controller, block_wrapper, text_span_decorator
    ├── editor_state.dart                    # EditorState — single mutable state (public API)
    ├── extensions/                          # node, position, attributes, color, theme extensions
    ├── flutter/                             # vendored forks of Flutter ecosystem code
    │   └── scrollable_positioned_list/      # vendored fork — edit the copy, never add the pub dep
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
    └── service/                             # context_menu/, default_text_operations/,
                                             #   internal_key_event_handlers/, selection/ (gestures),
                                             #   shortcut_event/ (keybinding, key_mapping)

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
└── new/                                     # current test home: block_component/, command/,
                                             #   editor_component/, find_replace_menu/, infra/
                                             #   (TestableEditor), service/, toolbar/, util/, vim_mode/

example/lib/                                 # demo app (analyze-only in CI)
├── main.dart
├── common/                                  # configurations/, constants/ (chapter contents),
│                                            #   controller/, nodes/ (directory, file, root), store/
├── cursor_renderers/                        # block_aware_cursor_renderer, rainbow_selection_renderer
├── extensions/                              # node_ext, num_ext
├── spell_check/                             # Hunspell en_US checker + worker isolate (reference impl)
└── widgets/                                 # drawer/, editor/, views/ (android_view, desktop_view)

documentation/                               # feature guides (styles, tables, vim-commands,
                                             #   customizing, importing, testing, translation,
                                             #   migrations/, performance-*)
```

Note: `packages/` may contain extra dirs without a `pubspec.yaml` (work-in-progress
extractions). They are **not** part of the published API — ignore them.

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
      novident_editor (root)            (block components, services, plugins, toolbar, vim/zen…)
```

- `novident_editor_document` knows nothing about selection, styles, or rendering — only the
  node tree, rich-text Delta, paths, and attributes.
- `novident_editor_core` depends only on document; `styles` and `selection` depend only on
  document + core; `rich_text` depends on document + core + styles + selection.
- The root `novident_editor` is the **only** place for block components, editor services,
  plugins, toolbar, vim/zen, and find & replace.
- `novident_editor_spell_check_interface` must stay pure Dart — no `flutter` import, ever.
- Never let a lower layer import a higher one; a package must not import the root
  `novident_editor` or a sibling it doesn't already depend on.

## Entry points (public API)

| Symbol | Location |
|---|---|
| `NovidentEditor` widget | `lib/src/editor/editor_component/service/editor.dart` |
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

## Gotchas (non-negotiable)

- **`packages/` source is NOT what root/example consume.** Root and `example/` depend on
  `novident_editor_*` via **pub.dev version constraints** (`^1.0.x`), not path deps. Editing
  a package's source has **zero effect** on root/example builds or tests until you publish a
  new version and bump the constraint. To test a package change locally, add
  `dependency_overrides: novident_editor_<x>: {path: packages/novident_editor_<x>}` to the
  consuming pubspec, then `flutter pub get`.
- **Never run `flutter test` in `example/`.** CI analyzes it only; its tests were never
  meant to run and fail on a missing library. Don't "fix" them.
- **`lib/src/l10n/intl/messages_*.dart` is generated.** Edit ARB files in `lib/l10n/` only,
  then run `flutter pub run intl_utils:generate`. Never hand-edit generated files.
- **`lib/src/flutter/scrollable_positioned_list/` is a vendored fork** — edit the vendored
  copy, never add the pub dependency.
- **Flutter is pinned to 3.32.4** (`.fvmrc`). Use `fvm flutter` when fvm is available.

## Where new code goes (structure preservation)

- **One concern per file**, barrel files per layer (`core.dart`, `editor.dart`,
  `plugins.dart`, `extensions.dart`, `util.dart`…). New public symbols must be exported from
  the layer barrel and, if part of the public API, from `lib/novident_editor.dart`.
- **Block components**: new block types go in
  `lib/src/editor/block_component/<type>_block_component/` with
  `<type>_block_component.dart` + `<type>_character_shortcut.dart` (+
  `<type>_command_shortcut.dart` when it has commands), registered in
  `standard_block_components.dart`.
- **Services** live under `lib/src/editor/editor_component/service/<domain>/`; keyboard
  handling is composable via `KeyboardStrategy` policies in `service/shortcuts/`.
- **Plugins** (import/export formats) go under `lib/src/plugins/<format>/` with `decoder/`
  and `encoder/` subdirs and per-node parsers.
- **Tests mirror the source path** under `test/` (or `test/new/` for the current suite). Use
  existing helpers — `test/test_helper.dart` (`buildAndPump`),
  `test/new/infra/testable_editor.dart` (`TestableEditor`), `test/new/util/` — don't invent
  new harnesses.
- **Lint** (`analysis_options.yaml`): `require_trailing_commas`, `prefer_final_locals`,
  `prefer_final_fields`, `always_declare_return_types`, `unawaited_futures`,
  `sort_constructors_first`. Keep files `dart format`-clean.
- **Legacy dirs** (`core/document/deprecated/`, `core/legacy/`) are AppFlowy leftovers —
  don't extend them; migrate callers off them.

## Deeper dives

- `AGENTS.md` — full structure & conventions (this skill is its condensed, always-in-context form).
- `ARCHITECT.md` — how the system works (data flow, mutation pipeline, rendering).
- `CONTRIBUTING.md` — workflow, PRs, versioning.
- `documentation/` — feature guides: `styles.md`, `tables.md`, `vim-commands.md`,
  `customizing.md`, `importing.md`, `testing.md`, `translation.md`, `migrations/`.