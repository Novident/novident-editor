# Changelog

## 1.0.5

* fix: `moveVerticallyInText` return `null` on empty paragraphs or empty nodes. `_renderParagraph` was the only used, and `_placeholderRenderParagraph` was ignored, causing the error.
* fix: `getRectsInSelection` always gets a height of `0.0` since is not checking the `_placeholderRenderParagraph` first (always null when there's content). 
* fix: head for the selection is never painted as expected on `VimSelectionRenderer`.
* revert: removed `TextDocument` and `DocumentTree` across all packages — rolled back to pure `Delta`-based text storage by @CatHood0.
* chore: bumped all internal package dependencies to latest.

## 1.0.4

* feat(breaking changes): layered editor extraction + cursor rendering API by @CatHood0 in https://github.com/Novident/novident-editor/pull/14
* feat: contrast spans text color during selection by @CatHood0 in https://github.com/Novident/novident-editor/pull/21
* feat: default font families by platform by @CatHood0 in https://github.com/Novident/novident-editor/pull/22
* fix: vertical cursor jumps to wrong position during scroll animation by @CatHood0 in https://github.com/Novident/novident-editor/pull/12
* fix: cursor Disappears During KeyRepeat Events by @CatHood0 in https://github.com/Novident/novident-editor/pull/13
* fix: stack overflow on drag scroll by @CatHood0 in https://github.com/Novident/novident-editor/pull/16
* fix: replace universal_html with package:web to support wasm compilation by @CatHood0 in https://github.com/Novident/novident-editor/pull/17
* fix: prevent infinite table row-height relayout loop on sub-pixel jitter by @CatHood0 in https://github.com/Novident/novident-editor/pull/18
* fix: most of the API of `SelectionRenderer` implementations are not used by the editor by @CatHood0 in https://github.com/Novident/novident-editor/pull/20

## 1.0.3

* feat: style system, font provider & static toolbar by @CatHood0 in https://github.com/Novident/novident-editor/pull/3
* feat: First line indent for the editor by @CatHood0 in https://github.com/Novident/novident-editor/pull/4
* feat: re-design table customization and creation  by @CatHood0 in https://github.com/Novident/novident-editor/pull/5
* feat: filter when use first line indent by @CatHood0 in https://github.com/Novident/novident-editor/pull/9

## 1.0.2

* Chore: moved core models to its own package by @CatHood0 in https://github.com/Novident/novident-editor/pull/1
* fix (e2d7c5b): propagation of heading format in command by saif-ellafi (#1189 from appflowy-editor)
* fix (1ae68d7): most of issues with deprecated members and missing ones
* fix (cf69710): test issues, and some appflowy references 
* fix: korean ime issue by @CatHood0 in https://github.com/Novident/novident-editor/pull/2

## 1.0.1

* Fix: `TextInputClient.onFocusReceived` error from pub dev. Added placeholder
* Fix: dependency versions error from pub dev
* Fix: file picker new version implementation changes

## 1.0.0
