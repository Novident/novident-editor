# Changelog

## 1.0.3

* fix: `moveVerticallyInText` return `null` on empty paragraphs or empty nodes. `_renderParagraph` was the only used, and `_placeholderRenderParagraph` was ignored, causing the error
* fix: when the caret wraps the current character selection, the constrast color is never used.
* chore: `getRenderParagraph()` returns the delta content `_renderParagraph` and, if it's null, returns the `_placeholderRenderParagraph` (can be null too)

## 1.0.2

* chore: bumped `novident_editor_document` dependency to ^1.0.4 after TextDocument revert.

## 1.0.1

* feat: replaced Delta usage to the new TextDocument class.
* chore: updated dependencies to the latest versions
* chore: minimal improvements to perfomance and assignations

## 1.0.0

* First release.
