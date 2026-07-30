## 1.0.2

* Feat: replaced `node.attributes` to return a direct `Map` instance, instead copies. It's NOT recommended to use for mutation. All the warnings is inside the method documentation. Use `updateAttributes` instead for any change to maintain the consistency.

## 1.0.1

* Chore: expose `OpIterator` to the public API.
* Chore: export `clear` and `operations` methods from `Delta` class. 
* Fix: `length` now uses cached plain text value when needed. 


## 1.0.0

* Initial release: document model extracted from `novident_editor`.
* `Document` — tree-structured document with JSON serialization.
* `Node` — tree node with attributes, children, path resolution.
* `Delta` — Quill-compatible rich-text delta (compose, diff, invert).
* `Path` — `List<int>` with comparison and navigation extensions.
* `Attributes` — map-based attribute helpers (compose, invert, diff).
* `NodeIterator` — depth-first visual-order traversal.
* `RichTextKeys` — well-known rich-text attribute constants.
