# Changelog

## 1.0.4

* chore: update `novident_editor_selection` dependency to the latest version.

## 1.0.3

* feat: replaceable span pipeline (`NovidentTextSpanPipeline`). All per-span logic — style resolution, text transforms, span emission, selection contrast, placeholder handling and span adjustments — moved out of `NovidentRichText` into a 6-phase pipeline with immutable contexts. `DefaultNovidentTextSpanPipeline` reproduces the previous behavior exactly (legacy callbacks kept in the constructor), and the pipeline can be plugged through `RichTextEditorConfig.spanPipeline` or `NovidentRichText.spanPipeline` — custom decorations (e.g. spell-check marks) no longer require forking the widget.
* fix: use `resolveStyleForNode` instead the changed `resolveStyle`.
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
