# Changelog

## 1.0.7

* fix(scroll#38): auto-scroll does not stop automatically when the cursor already enters into the viewport. 
* fix(ios): ios drag handles were too far from the actual selection rect.
* fix(blocks): numbered list block does not center the position of the center respect to the list number identifier.
* fix(styles): cannot justify items.
* fix(toolbar): toggled items are not activated when the selection is colapsed by @CatHood0 in https://github.com/Novident/novident-editor/pull/37
* fix(vim): undo and redo on vim mode preserves previous ranged selection (now collapses).
* fix: most of the issues related with the workflows and the testing failing.
* fix: make public internal paste text methods using `EditorState`.
* chore(example): updated example to have the native toolbar for every platform.
* chore(example): updated example to add more variation to the content and all the design of the blocks.
* chore(skills): added new skill to allow creating content for the editor with no cost (since AI does not require to search in the codebase how are the blocks supported)

## 1.0.6

* fix(ime): send only selected nodes during text input attach by @CatHood0 in https://github.com/Novident/novident-editor/pull/32
* fix(modes): zen mode performance refactor, color-based dimming, O(1) rebuilds, and standalone typewriter by @CatHood0 in https://github.com/Novident/novident-editor/pull/34
* fix(scroll): new scroll strategy system + corrected typewriter mode by @CatHood0 in https://github.com/Novident/novident-editor/pull/36
* fix(paste): when pasted content has newlines, instead be inserting multiple nodes, just inyect the `Delta` with the raw newlines (decreases the perfomance too and produces weird rendering stuff).
* fix(39d7562): cannot paste properly in mobile devices. Introduced in the commit 39d7562.
* chore(readme): updated some documentation examples.

## 1.0.5

* feat: start of replace Delta with a new optimized version `TextDocument` by @CatHood0 in https://github.com/Novident/novident-editor/pull/23
* feat: support for fast indexation and replaced delta with text document by @CatHood0 in https://github.com/Novident/novident-editor/pull/24
* feat: extract keyboard handling into composable KeyboardStrategy policies by @CatHood0 in https://github.com/Novident/novident-editor/pull/28
* feat(spell checker): out-of-band analysis, mark-driven rendering, and isolate-backed suggestions by @CatHood0 in https://github.com/Novident/novident-editor/pull/29
* fix: most of the issues with rendering, positioning, head weird render, and vertical movement during vim usage by @CatHood0 in https://github.com/Novident/novident-editor/pull/25
* fix: internal `ScrollablePositionedList` perfomance was improved to avoid traversing multiples times the rendered tree when no required. Useful for `getVisibleNodes` that uses it.
* fix: `moveVerticallyInText` return `null` on empty paragraphs or empty nodes. `_renderParagraph` was the only used, and `_placeholderRenderParagraph` was ignored, causing the error.
* fix: `getRectsInSelection` always gets a height of `0.0` since is not checking the `_placeholderRenderParagraph` first (always null when there's content). 
* fix: head for the selection is never painted as expected on `VimSelectionRenderer`.
* fix: visual vim horizontal movement delegates the movement to the default editor command. Created new one that matches with the expected behavior for vim mode.
* fix: `MobileSelectionDragMode` is not subtype of `string?`.
* chore: `MobileSelectionDragMode` move inside `novident_editor_selection` package. 
* revert: removed `TextDocument` and `DocumentTree` across all packages — rolled back to pure `Delta`-based text storage by @CatHood0.
* chore(breaking changes): moved `SelectionUpdateReason` and `SelectionType` to `novident_editor_selection` package.
* chore: deprecated from `SelectionRenderer` these methods: `buildExpandedHeadCursor`, `paintExpandedHeadCursor` (replaced by `shouldPaintHeadRect`) and `expandedHeadPosition` since we recommend  computing the head and injecting it directly to the rects into `onSelectionRectsMeasured` (like I did with `VimSelectionRenderer`)
* chore: bumped all internal package dependencies to latest.
* chore(breaking changes): deprecated `characterShortcutEvents` and `commandShortcutEvents` and replaced for `keyboardStrategies`.
* chore(example): added ~18k of words for example, to allow testing how behaves the editor with a large document.


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
