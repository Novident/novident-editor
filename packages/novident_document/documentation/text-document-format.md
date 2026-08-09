# TextDocument — Documentation

## Index

1. [Executive Summary](#1-executive-summary)
2. [Architecture](#2-architecture)
3. [Internal Structure: Treap-Rope](#3-internal-structure-treap-rope)
4. [API Reference](#4-api-reference)
5. [Delta vs TextDocument Comparison](#5-delta-vs-textdocument-comparison)
6. [Native JSON Format](#6-native-json-format)
7. [Migration Guide](#7-migration-guide)
8. [Testing](#8-testing)

---

## 1. Executive Summary

`TextDocument` replaces Delta's flat `List<TextOperation>` with a **Treap-Rope**: a probabilistically balanced binary tree where each node holds a `TextChunk` (text + attributes) augmented with the total subtree character count.

| Metric | `Delta` (legacy) | `TextDocument` (new) |
|--------|-------------------|-----------------------|
| `insert(pos, text)` | O(n) via `compose()` | **O(log n)** |
| `delete(pos, len)` | O(n) via `compose()` | **O(log n)** |
| `format(pos, len, attrs)` | O(n) via `compose()` | **O(log n + k)** |
| `attributesAt(pos)` | O(n) via `slice()` | **O(log n)** |
| `slice(start, end)` | O(n) | **O(log n + k)** |
| `length` | O(n) fold | **O(1)** |
| JSON serialization | Direct | `toDelta().toJson()` |
| Legacy modification | `compose()` | `applyDelta(Delta)` → **O(log n)** |

**Full backward compatibility**: JSON is always legacy `Delta`. `TextDocument` provides `fromDelta()`/`toDelta()` converters and an `applyDelta()` method that translates Delta modifications into O(log n) native operations.

---

## 2. Architecture

```
┌──────────────────────────────────────────────────────────────┐
│                       Node (document)                          │
│                                                               │
│  attributes['delta'] → List<dynamic>                          │
│       ▲                                            │          │
│       │ toJson()                                   │ fromJson()│
│       ▼                                            ▼          │
│  ┌─────────────────────────────────────────────────────┐     │
│  │                   TextDocument                       │     │
│  │  ┌─────────────────────────────────────────────┐    │     │
│  │  │              Treap-Rope                       │    │     │
│  │  │  ┌──────┐     ┌──────┐     ┌──────┐         │    │     │
│  │  │  │Chunk0│────│Chunk1│────│Chunk2│─→ ...    │    │     │
│  │  │  │"Hello"│   │" wo" │    │"rld" │         │    │     │
│  │  │  │{bold}│    │ null │    │{bold}│         │    │     │
│  │  │  │len:5 │    │len:3 │    │len:3 │         │    │     │
│  │  │  └──────┘     └──────┘     └──────┘         │    │     │
│  │  └─────────────────────────────────────────────┘    │     │
│  │                                                     │     │
│  │  API: insert() delete() format() slice()            │     │
│  │       attributesAt() applyDelta() chunks            │     │
│  └─────────────────────────────────────────────────────┘     │
└──────────────────────────────────────────────────────────────┘
```

### Data flow

```
Loading an existing document:
  Legacy JSON → Delta.fromJson() → TextDocument.fromDelta()
                                         │
                                    Treap-Rope (O(n), once)

Editor modification:
  Option A (legacy, Phase 2):
    Delta()..retain(pos)..insert(text, attrs)
    → textDocument.applyDelta(change)    ← O(log n)!

  Option B (native, Phase 3):
    textDocument.insert(pos, text, attrs) ← O(log n) direct

Serialization:
  textDocument.toDelta().toJson() → Legacy JSON
```

---

## 3. Internal Structure: Treap-Rope

### 3.1 `TextChunk` — atomic unit

```dart
class TextChunk {
  final String text;              // Contiguous text
  final Attributes? attributes;   // Uniform attributes (null = plain text)
  int get length => text.length;
}
```

Equivalent to a legacy Delta `TextInsert`: same `(text, attributes)` pair, stored in a tree instead of a flat list.

**For building Flutter `TextSpan`s:**
```dart
List<TextSpan> spans = doc.chunks.map((chunk) {
  return TextSpan(
    text: chunk.text,
    style: _attributesToStyle(chunk.attributes),
  );
}).toList();
```

### 3.2 `_TreapNode` — tree node

```
          ┌──────────────┐
          │ _TreapNode    │
          │ chunk: "wo"  │
          │ priority: 42  │  ← Random, Heap balance
          │ subtreeLen: 10│  ← Sum of subtree lengths
          │ left ─┐       │
          │ right ─┐      │
          └───────┼───────┘
        ┌─────────┘  └─────────┐
        ▼                       ▼
   ┌──────────┐           ┌──────────┐
   │"Hello"   │           │"rld"     │
   │{bold}    │           │{bold}    │
   │len: 5    │           │len: 3    │
   └──────────┘           └──────────┘
```

**Two invariants:**

| Invariant | Description |
|-----------|-------------|
| **BST by position** | In-order traversal = document order. All nodes in the left subtree come before this node; all in the right come after. |
| **Max-Heap by priority** | `this.priority > left.priority && this.priority > right.priority`. Ensures expected O(log n) balance. |
| **Augmented** | `subtreeLength = chunk.length + left.subtreeLength + right.subtreeLength`. Enables O(log n) position-based lookup. |

### 3.3 Treap Operations

#### `_split(node, pos)` — O(log n)

Splits the tree in two: `[0, pos)` on the left, `[pos, total)` on the right.

```
_split(root, 5):
  Before: [Hello(5)] → [wo(3)] → [rld(3)]   (total=11)
  After:  left=[Hello(5)]                   right=[w(1)] → [o(2)] → [rld(3)]
                                              ↑ "wo" was split into "w" + "o"
```

**Algorithm:**
1. If `pos <= leftLen`: split point is in the left subtree → recurse.
2. If `pos >= leftLen + chunkLen`: split point is in the right subtree → recurse.
3. Otherwise: split point is **inside** this chunk → cut the chunk in two and create a new node for the right part.

#### `_merge(left, right)` — O(log n)

Joins two treaps where all positions in `left` precede all positions in `right`.

**Algorithm:**
1. If `left.priority > right.priority`: `left` is root, `left.right = merge(left.right, right)`.
2. Otherwise: `right` is root, `right.left = merge(left, right.left)`.

#### `_nodeAt(node, pos)` — O(log n)

Binary search by `subtreeLength`:
1. If `pos < left.subtreeLength`: go left.
2. If `pos < left.subtreeLength + chunk.length`: **found** — this node contains the position.
3. Otherwise: `pos -= left.subtreeLength + chunk.length`, go right.

---

## 4. API Reference

### 4.1 Constructors

```dart
// Empty document
final doc = TextDocument.empty();

// From legacy Delta (loading existing documents)
final doc = TextDocument.fromDelta(node.delta!);

// From legacy JSON
final doc = TextDocument.fromJson(jsonList);

// From native JSON (preferred for new storage)
final doc = TextDocument.fromNativeJson(nativeJson);
```

### 4.2 Properties

```dart
int get length;       // O(1) — total character count
bool get isEmpty;     // O(1) — true if _root == null
List<TextChunk> get chunks; // O(n) — in-order traversal, for TextSpan
```

### 4.3 O(log n) Mutations

```dart
// Insert text at position
doc.insert(5, 'Hello', attributes: {'bold': true});

// Delete range
doc.delete(5, 3);  // 3 characters starting at position 5

// Format range (merges attributes via composeAttributes)
doc.format(0, 5, {'italic': true});
```

### 4.4 O(log n) Queries

```dart
// Attributes at position
Attributes? attrs = doc.attributesAt(3); // null for plain text

// Plain text in a range
String text = doc.plainText(0, 10);  // first 10 characters
String all = doc.plainText();        // entire text
```

### 4.5 O(log n + k) Range Queries

```dart
// Extract range as legacy Delta
Delta part = doc.slice(5, 15);
```

### 4.6 Serialization

```dart
// To legacy Delta (for interop)
Delta legacy = doc.toDelta();

// To legacy JSON (for persistence)
List<dynamic> json = doc.toJson();

// To native JSON (for future persistence)
Map<String, dynamic> native = doc.toNativeJson();
```

### 4.7 Legacy Bridge: `applyDelta()`

```dart
// Apply a Delta modification to the document.
// Translates each TextOperation into O(log n) native operations.

final change = Delta()
  ..retain(5)
  ..insert('Hello', attributes: {'bold': true})
  ..delete(3);

doc.applyDelta(change); // O(|change| × log N) instead of O(N)
```

**Operation mapping:**

| Delta operation | Native call |
|-----------------|-------------|
| `Retain(N)` | `cursor += N` |
| `Retain(N, attrs: A)` | `format(cursor, N, A)` |
| `Insert(text, attrs: A)` | `insert(cursor, text, A)` |
| `Delete(N)` | `delete(cursor, N)` |

---

## 5. Delta vs TextDocument Comparison

### 5.1 Same content, different structure

**Delta (legacy):**
```json
[
  {"insert": "Gandalf", "attributes": {"bold": true}},
  {"insert": " the "},
  {"insert": "Grey", "attributes": {"color": "#ccc"}}
]
```
→ Flat `List<TextOperation>`. Positional access: O(n).

**TextDocument:**
```
TextDocument
├── chunks[0]: TextChunk("Gandalf", {bold: true})
├── chunks[1]: TextChunk(" the ", null)
└── chunks[2]: TextChunk("Grey", {color: "#ccc"})

Internally: Balanced treap. Positional access: O(log n).
```

**Output JSON (identical):**
```json
[
  {"insert": "Gandalf", "attributes": {"bold": true}},
  {"insert": " the "},
  {"insert": "Grey", "attributes": {"color": "#ccc"}}
]
```

### 5.2 Same modification, different complexity

**Operation: replace "Grey" with "White"**

```dart
final change = Delta()
  ..retain(12)
  ..insert('White', attributes: {'color': '#fff'})
  ..delete(4);
```

**With Delta (legacy):**
```dart
final result = documentDelta.compose(change);
// Iterates through ALL document operations (O(n))
// For a doc with 5000 spans → 5000 OpIterator iterations
```

**With TextDocument:**
```dart
doc.applyDelta(change);
// Only 3 treap operations (insert + delete)
// Each O(log 5000) ≈ O(13)
// Total: ~39 operations vs 5000
```

### 5.3 Chunk fragmentation

In Delta, `compose()` can produce fragmentation (adjacent chunks with identical attributes). In `TextDocument`, native operations preserve existing chunks but do not automatically merge adjacent chunks with the same attributes. This may produce more chunks than necessary, but does not affect correctness or complexity.

A `compact()` method can be implemented to merge adjacent chunks with identical attributes in O(n).

---

## 6. Native JSON Format

See [`04-native-json-format.md`](./04-native-json-format.md) for the full specification.

`TextDocument` has its own JSON format for when the breaking change is made:

```json
{
  "v": 1,
  "c": [
    {"t": "Hello ", "a": {"bold": true}},
    {"t": "World"}
  ]
}
```

- **`v`**: format version (future extensibility).
- **`c`**: chunks array in document order.
- **`t`**: text. **`a`**: attributes (omitted for plain text).

**API:**
```dart
final json = doc.toNativeJson();
final restored = TextDocument.fromNativeJson(json);
```

Reconstruction uses a **Cartesian tree in O(n)** — does not depend on `Delta` at all.

### Visual comparison: same content, two formats

| Delta JSON (legacy) | Native JSON |
|---------------------|-------------|
| `[{"insert":"My "},{"insert":"Rich","attributes":{"bold":true}}]` | `{"v":1,"c":[{"t":"My "},{"t":"Rich","a":{"bold":true}}]}` |

---

## 7. Migration Guide

### Phase 0 (current): `TextDocument` + tests

- `TextDocument` exists alongside `Delta`.
- 76 tests cover the full API.
- The editor is **not modified**.

### Phase 1: `Node` caches `TextDocument`

```dart
// In node.dart, add:
TextDocument? _cachedTextDocument;

TextDocument? get textDocument {
  final raw = _attributes['delta'];
  if (raw is! List) return null;
  if (!identical(raw, _cachedDeltaRaw)) {
    _cachedDeltaRaw = raw;
    _cachedDelta = Delta.fromJson(raw);
    _cachedTextDocument = TextDocument.fromJson(raw);  // ← NEW
  }
  return _cachedTextDocument;
}
```

The editor continues using `node.delta` unchanged. `TextDocument` is an additional cache.

### Phase 2: `Transaction.compose()` uses `applyDelta()`

```dart
// In transaction.dart, replace:
final composed = deltaQueue.fold<Delta>(node.delta!, (p, e) => p.compose(e));
// With:
final doc = node.textDocument!;
for (final d in deltaQueue) { doc.applyDelta(d); }
final composed = doc.toDelta();
```

The editor **continues building Deltas** (nothing breaks), but application is O(log n).

### Phase 3 (optional): Native API in the editor

Progressively migrate call sites:

```dart
// Before:
transaction.insertText(node, index, text, attributes: attrs);

// After:
node.textDocument!.insert(index, text, attributes: attrs);
```

Legacy `Delta` remains only for serialization and external plugins (Markdown, HTML, Quill Delta).

---

## 7. Testing

### Test files

| File | Tests | Description |
|------|-------|-------------|
| `test/text_document_test.dart` | 76 | Full TextDocument API |
| `test/text_document_vs_delta_test.dart` | 26 | Delta vs TextDocument: correctness + performance |
| `test/text_delta_test.dart` (existing) | ~50 | Legacy Delta |
| Others (node, path, document, etc.) | ~21 | Existing infrastructure |

### `test/text_document_test.dart` — 76 tests

| Group | Tests | Description |
|-------|-------|-------------|
| Construction | 6 | `empty()`, `fromDelta()`, `fromJson()`, edge cases |
| length / isEmpty | 6 | Basic properties |
| `insert()` | 10 | Start, end, middle, attributes, bounds |
| `delete()` | 7 | Start, end, middle, cross-chunk, bounds |
| `format()` | 7 | New attributes, merge, cross-chunk, bounds |
| `attributesAt()` | 5 | Plain text, formatted, edges, bounds |
| `slice()` | 8 | Ranges, attributes, Delta round-trip |
| `plainText()` | 4 | Ranges, empty document |
| `toDelta()` / `toJson()` | 4 | Round-trip, idempotence, matching JSON |
| `applyDelta()` | 7 | Insert, delete, format, composite, chaining |
| `chunks` | 3 | Order, attributes, post-split |
| Stress / edge cases | 6 | 500 inserts, mixed ops, Unicode, exhaustive |

### `test/text_document_vs_delta_test.dart` — 26 tests

| Group | Tests | Description |
|-------|-------|-------------|
| Correctness | 11 | Character-by-character equivalence, round-trips, random mixed ops |
| Performance | 8 | Benchmarks: insert, delete, format, attributesAt, slice, applyDelta, scaling |
| Native JSON | 7 | Native format: round-trip, compactness, versioning, edge cases |

**Performance tests included:**
- `attributesAt` (O(log n) vs O(n)): **10x+ faster**
- `insert` on large documents: O(log n) vs O(n)
- `applyDelta` vs `compose` with 5000 chunks
- Logarithmic scaling verified across 4 document sizes

### Running

```bash
flutter test test/text_document_test.dart
# 76 tests, 0 failures

flutter test test/text_document_vs_delta_test.dart
# 26 tests, 0 failures

flutter test  # all package tests
# 173 tests, 0 failures (71 legacy + 102 new)
```

### Edge case coverage

- Empty document
- Insert/delete at boundaries (position 0, end position)
- Operations crossing chunk boundaries
- Formatting that merges existing attributes
- Delta with empty operations (`insert('')`)
- Multi-byte Unicode text (emojis)
- Out-of-bounds positions (throws `RangeError`)
- Fuzz: inserts at every possible position, deletes of all sizes
- Round-trip: `Delta → TextDocument → toDelta() → toJson()` produces the same JSON as the original
