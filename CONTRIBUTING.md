# Contributing to Novident Editor

Thanks for your interest in contributing! This is a Flutter rich-text editor
(a fork of [AppFlowy Editor](https://github.com/AppFlowy-IO/appflowy-editor),
MPL 2.0), structured as a monorepo: the root `novident_editor` package, the
extracted layers under `packages/`, and the demo app under `example/`. A few
things about the setup are not obvious from the code, so please skim this
before opening a PR.

## Project layout

The monorepo lives at the repo root. The original editor was split ("the
corte") into layered packages, each published independently to pub.dev:

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

- `novident_editor_document` is the document model: node tree, rich-text
  Delta, paths, attributes. Knows nothing about selection, styles, or
  rendering.
- `novident_editor_core` adds `Position`/`Selection`/`SelectableMixin` and
  the text rendering config.
- `novident_editor_styles` and `novident_editor_selection` provide the style
  registry/font provider and the cursor/block-selection painters.
- `novident_editor_rich_text` is `NovidentRichText` + the 6-phase span
  pipeline.
- `novident_editor_spell_check_interface` is the engine-agnostic spell-check
  contract — **pure Dart, no Flutter import, ever**.
- The root `novident_editor` is the **only** place for block components,
  editor services, plugins, toolbar, vim/zen, and find & replace.

### Layering rules (strict)

- Dependencies only flow upward in the diagram above. A lower layer must
  never import a higher one, and a package must not import the root
  `novident_editor` or a sibling it doesn't already depend on.
- `novident_editor_document` knows nothing about selection, styles, or
  rendering.
- `novident_editor_spell_check_interface` must stay pure Dart — no
  `flutter` import, ever.
- New extractions may only depend on layers below them; keep them
  dependency-light (mirror the published six).

### Versioning (independent, not lockstep)

Unlike a lockstep workspace, each package versions **independently** and the
root depends on them via pub.dev version constraints (`^1.0.x`), **not** path
deps. This has two consequences:

- **Editing a package's source has zero effect on root/example builds or
  tests** until you publish a new version and bump the constraint in the
  consuming `pubspec.yaml`. To test a package change locally, add
  `dependency_overrides: novident_editor_<x>: {path: packages/novident_editor_<x>}`
  to the consuming pubspec, then `flutter pub get`.
- When you bump a package version, update every consumer's constraint to the
  new version (root `pubspec.yaml`, `example/pubspec.yaml`, and any sibling
  package that depends on it).

## Setup

Flutter is pinned with [fvm](https://fvm.app) (see `.fvmrc`, currently
**3.32.4**). Use `fvm flutter` when fvm is available.

```bash
fvm install            # once, installs the pinned Flutter
flutter pub get        # at the repo root
```

## Running checks

Mirror what CI runs (`.github/workflows/ci.yml`):

```bash
# Root package
flutter analyze --no-fatal-infos --no-fatal-warnings
flutter test                          # whole suite
flutter test test/new/vim_mode/vim_mode_test.dart   # single file

# A single package (only dirs with pubspec.yaml are real packages)
cd packages/novident_editor_styles && flutter pub get && flutter analyze && flutter test

# Example: analyze ONLY — never test
cd example && flutter pub get && flutter analyze --no-fatal-infos --no-fatal-warnings
```

Notes:

- **Ignore the errors coming from the example tests.** CI analyzes it only; its tests
  were never meant to be runned and them will fail since are only for debugging. Don't "fix" them.
- If you touched ARB files in `lib/l10n/`, regenerate the generated
  `lib/src/l10n/intl/messages_*.dart` files (never hand-edit them):
  `flutter pub run intl_utils:generate`.

## Test conventions

The `test/` directory mirrors the `lib/` structure (see
[`documentation/testing.md`](documentation/testing.md)); `test/new/` is the
current home for new tests. Use the existing helpers — `test/test_helper.dart`
(`buildAndPump`), `test/new/infra/testable_editor.dart` (`TestableEditor`),
`test/new/util/` — don't invent new harnesses. Add or update tests for any
behaviour change.

## Conventions

- **One concern per file**, barrel files per layer (`core.dart`,
  `editor.dart`, `plugins.dart`, `extensions.dart`, `util.dart`…). New public
  symbols must be exported from the layer barrel and, if part of the public
  API, from `lib/novident_editor.dart`.
- **Block components**: new block types go in
  `lib/src/editor/block_component/<type>_block_component/` with
  `<type>_block_component.dart` + `<type>_character_shortcut.dart` (+
  `<type>_command_shortcut.dart` when it has commands), registered in
  `standard_block_components.dart`.
- **Services** live under
  `lib/src/editor/editor_component/service/<domain>/`; keyboard handling is
  composable via `KeyboardStrategy` policies in `service/shortcuts/` (the old
  `characterShortcutEvents`/`commandShortcutEvents` params are deprecated —
  use `keyboardStrategies`).
- **Plugins** (import/export formats) go under `lib/src/plugins/<format>/`
  with `decoder/` and `encoder/` subdirs and per-node parsers.
- **Text storage is pure Delta** — Inspired format from the Quill Delta format.
- **Lint** (`analysis_options.yaml`): `require_trailing_commas`,
  `prefer_final_locals`, `prefer_final_fields`, `always_declare_return_types`,
  `unawaited_futures`, `sort_constructors_first`. Keep files `dart format`-clean.
- **Legacy dirs** (`core/document/deprecated/`, `core/legacy/`) are AppFlowy
  leftovers — don't extend them; migrate callers off them.
- **Commits** follow [Conventional Commits](https://www.conventionalcommits.org/)
  (enforced by commitlint in CI).

## Pull requests

1. Branch off `master`.
2. Keep changes focused; one logical change per PR.
3. Make sure `flutter analyze` and the relevant test suites pass (root and
   any touched package), and that commits are Conventional Commits.
4. If you changed a package's source, note in the PR whether it requires a
   version bump + constraint update (see "Versioning" above).

## Reporting bugs and feature requests

- Functional bugs: open an issue using the **Bug Report** template
  (`.github/ISSUE_TEMPLATE/bug_report.yaml`).
- Ideas and improvements: open an issue using the **Feature Request**
  template (`.github/ISSUE_TEMPLATE/feature_request.yaml`).

## License

By contributing, you agree that your contributions will be licensed under the
project's [Mozilla Public License 2.0](LICENSE). This project is a fork of
AppFlowy Editor; see [NOTICE](NOTICE) for attribution.
