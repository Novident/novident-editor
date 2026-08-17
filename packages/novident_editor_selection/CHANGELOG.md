# Changelog

## 1.0.4

* fix: head for cursor is never being computed correctly by using `prevCursorRect` when the renderer shouldn't use it.
* feat: added `headColor` and `headheadRectIndex` properties to paint heads (only works we add that head manually, like `VimSelectionRenderer`)
* feat: added new method `headWrapsCharacter` to allow any rendering to telling to the `NovidentRichText` widget, that needs to paint the current text with the constrast color.
* fix: `MobileSelectionDragMode` is not subtype of `string?`.
* chore: `MobileSelectionDragMode` from the editor to this package. 
* chore(breaking changes): moved `selectionNotifier` and `remoteSelections` from `RichTextEditorConfig` to `BlockSelectionHost`. 
* chore: moved `SelectionUpdateReason` and `SelectionType` to this package.
* chore: deprecated from `SelectionRenderer` these methods: `buildExpandedHeadCursor`, `paintExpandedHeadCursor` (replaced by `shouldPaintHeadRect`) and `expandedHeadPosition` since we recommend  computing the head and injecting it directly to the rects into `onSelectionRectsMeasured` (like I did with `VimSelectionRenderer`)
* chore: updated dependencies to their latest versions.

## 1.0.3

* chore: bumped `novident_editor_document` dependency to ^1.0.4 after TextDocument revert.

## 1.0.2

* fix: changelog has missing version changes

## 1.0.1 

* feat: use TextDocument instead Delta in some required parts
* chore: minimal changes to the API

## 1.0.0

* First release.
