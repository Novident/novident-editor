# TextDocument Native JSON Format

## Motivation

When the breaking change is made to use `TextDocument` as the persistence format (instead of `Delta`), we need a JSON that:

1. **Does not depend on Delta** — its own format, without `insert`/`retain`/`delete` keys.
2. **Rebuilds the tree in O(n)** — using the Cartesian tree algorithm.
3. **Is compact** — short keys (`t` = text, `a` = attributes).
4. **Is versioned** — `v` field for future format evolution.

## Specification

### Version 1

```json
{
  "v": 1,
  "c": [
    {"t": "text", "a": {"attribute": "value"}},
    {"t": "text without attributes"},
    {"t": "more text", "a": {"bold": true, "italic": true}}
  ]
}
```

| Field | Type | Description |
|-------|------|-------------|
| `v` | `int` | Format version (currently `1`) |
| `c` | `List<Map>` | Chunks array in document order |
| `c[n].t` | `String` | Chunk text (always present) |
| `c[n].a` | `Map<String, dynamic>?` | Chunk attributes (absent for plain text) |

### Rules

- **`t` is always present**, even for empty strings (though empty chunks should not exist in practice).
- **`a` is omitted** when attributes are `null` or empty. Its presence implies non-empty attributes.
- **The order of `c` is the document order** (in-order traversal of the treap).
- **Priorities and tree structure are not serialized** — they are reconstructed in O(n) on deserialization with fresh random priorities.

## Comparison with Delta JSON

### Same content

**Delta JSON (legacy):**
```json
[
  {"insert": "My "},
  {"insert": "Rich", "attributes": {"bold": true, "italic": true}},
  {"insert": " Text", "attributes": {"italic": true}}
]
```

**TextDocument JSON (native):**
```json
{
  "v": 1,
  "c": [
    {"t": "My "},
    {"t": "Rich", "a": {"bold": true, "italic": true}},
    {"t": " Text", "a": {"italic": true}}
  ]
}
```

### Differences

| Aspect | Delta JSON | TextDocument Native JSON |
|--------|-----------|--------------------------|
| Root | `List` | `Map` (with versioning) |
| Text key | `insert` | `t` |
| Attributes key | `attributes` | `a` |
| Supported operations | Insert, Retain, Delete | Insert only (content only) |
| Reconstruction | O(n) — flat list | O(n) — Cartesian tree |
| Extensibility | Fixed (Quill format) | Versioned (`v`) |

## API

```dart
// Serialize
final json = doc.toNativeJson();
// → {"v": 1, "c": [{"t": "Hello"}, {"t": "World", "a": {"bold": true}}]}

// Deserialize
final doc = TextDocument.fromNativeJson(json);
```

## Reconstruction Algorithm (Cartesian Tree)

`TextDocument.fromNativeJson()` and `TextDocument.fromDelta()` use the same internal constructor `TextDocument._fromChunks()` which builds the treap in **O(n)**:

```
Input: chunks = [chunk₀, chunk₁, ..., chunkₙ₋₁]  (in document order)

1. Create nodes with random priorities: nodes[i] = TreapNode(chunks[i])
2. Traverse nodes left to right with a stack:
   - While stack.top.priority < node.priority: pop → lastPopped
   - node.left = lastPopped
   - stack.top.right = node (if stack is not empty)
   - Push node onto stack
3. The root is stack.first (the bottom of the stack)
4. Post-order: compute subtreeLength for all nodes
```

**Stack invariant**: holds the "right spine" of the tree built so far, with decreasing priorities from bottom to top (max-heap).

### Why O(n)?

Each node is pushed once and popped at most once. Total stack operations ≤ 2n. The post-order pass touches each node exactly once.

### Why random priorities?

Priorities are not persisted in JSON. On reconstruction, fresh priorities are generated with `Random()`. This guarantees a balanced treap (expected height O(log n)) without storing any balancing metadata.
