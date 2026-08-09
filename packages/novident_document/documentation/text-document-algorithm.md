# TextDocument — Internal Treap-Rope Algorithms

## Index

1. [Split](#1-split)
2. [Merge](#2-merge)
3. [NodeAt (position lookup)](#3-nodeat)
4. [Insert](#4-insert)
5. [Delete](#5-delete)
6. [Format](#6-format)
7. [Slice (range extraction)](#7-slice)
8. [applyDelta](#8-applydelta)
9. [Complexities](#9-complexities)

---

## 1. Split

**Goal**: split the treap into `[0, pos)` and `[pos, total)`.

**Complexity**: O(log n) expected.

```
function split(node, pos):
    if node == null: return (null, null)

    leftLen = node.left.subtreeLength

    if pos <= leftLen:
        // Split point is in the left subtree
        (ll, lr) = split(node.left, pos)
        node.left = lr
        node.update()
        return (ll, node)

    if pos >= leftLen + node.chunk.length:
        // Split point is in the right subtree
        (rl, rr) = split(node.right, pos - leftLen - node.chunk.length)
        node.right = rl
        node.update()
        return (node, rr)

    // Split point is INSIDE this chunk!
    offset = pos - leftLen
    leftChunk  = TextChunk(node.chunk.text[0:offset], node.chunk.attributes)
    rightChunk = TextChunk(node.chunk.text[offset:], node.chunk.attributes)

    rightNode = TreapNode(rightChunk)
    rightNode.right = node.right
    rightNode.update()

    node.chunk = leftChunk
    node.right = null
    node.update()

    return (node, rightNode)
```

**Visual example:**

```
Before:                            
    ┌──[A: "Hello", len=5]──┐     
    │                        │     
  null                ┌──[B:" World", len=6]
                      │
                     ...            

split(root, 7):
    - A's leftLen = 0
    - pos(7) >= 0 + 5 → go right
    - In B: leftLen = 0, pos(7-5=2) < 0 + 6 → SPLIT B
    - offset = 2
    - leftChunk = " W", rightChunk = "orld"
    
After:
    left:                        right:
    ┌──[A: "Hello", len=5]──┐   ┌──[B': "orld", len=4]
    │                        │   │
    └──[B_left: " W", len=2]     ...
    
    (A is root by priority;      (B' is an independent leaf)
     B_left is right child)
```

---

## 2. Merge

**Goal**: join two treaps where all positions in `left` < all positions in `right`.

**Complexity**: O(log n) expected.

```
function merge(left, right):
    if left == null: return right
    if right == null: return left

    if left.priority > right.priority:
        left.right = merge(left.right, right)
        left.update()
        return left
    else:
        right.left = merge(left, right.left)
        right.update()
        return right
```

**BST invariant preserved**: `merge` never crosses `left` nodes to the right of `right` nodes. Priority only decides which is the root of the result, not the in-order.

**Example:**

```
merge( [A(len=5, prio=30)], [B(len=3, prio=20)] ):
    A.prio > B.prio → A is root
    A.right = merge(null, B) = B
    A.update() → A.subtreeLength = 5 + 3 = 8
    return A

Result:
    ┌──A──┐
    │     │
   null   B
```

```
merge( [A(len=5, prio=10)], [B(len=3, prio=40)] ):
    B.prio > A.prio → B is root
    B.left = merge(A, null) = A
    B.update() → B.subtreeLength = 3 + 5 = 8
    return B

Result:
    ┌──B──┐
    │     │
    A    null
```

---

## 3. NodeAt

**Goal**: find the node and local offset that contain position `pos`.

**Complexity**: O(log n) — iterative binary search.

```
function nodeAt(node, pos):
    current = node
    while true:
        leftLen = current.left?.subtreeLength ?? 0

        if pos < leftLen:
            current = current.left
        else if pos < leftLen + current.chunk.length:
            return (node: current, offset: pos - leftLen)
        else:
            pos -= leftLen + current.chunk.length
            current = current.right
```

**Example:**

```
Tree:
        ┌──C: "rld", len=3──┐
        │                    │
   ┌──B: " wo", len=3    [D: "!!!", len=3]
   │
[A: "Hello", len=5]

nodeAt(root, 6):
    - current = C, leftLen = B.subtreeLen + A.subtreeLen = 3+5 = 8
    - pos(6) < 8 → go left
    - current = B, leftLen = A.subtreeLen = 5
    - pos(6) >= 5 && pos(6) < 5+3 → FOUND
    - return (node: B, offset: 6-5=1)
    - B.chunk is " wo", offset 1 → character 'w'
```

---

## 4. Insert

**Goal**: insert text at `position`.

**Complexity**: O(log n).

```
function insert(position, text, attributes):
    (left, right) = split(root, position)
    newNode = TreapNode(TextChunk(text, attributes))
    root = merge(merge(left, newNode), right)
```

**Example**: insert "X" at position 2 of "ABC":

```
Before: [A: "ABC", len=3]

split(root, 2):
    left:  [A_left: "AB", len=2]
    right: [A_right: "C", len=1]

merge(merge(left, [X:"X"]), right):
    [AB, len=2] + [X:"X", len=1] + [C, len=1]

After: chunks = ["AB", "X", "C"]  → "ABXC"
```

---

## 5. Delete

**Goal**: remove `length` characters starting at `position`.

**Complexity**: O(log n).

```
function delete(position, length):
    (left, midRight) = split(root, position)
    (mid, right) = split(midRight, length)
    // mid is discarded
    root = merge(left, right)
```

**Example**: delete 2 characters starting at position 1 of "ABCD":

```
Before: [A: "ABCD", len=4]

split(root, 1):
    left:  [A_left: "A", len=1]
    right: [A_right: "BCD", len=3]

split(right, 2):
    mid:   [A_mid: "BC", len=2]    ← discarded
    right: [A_right2: "D", len=1]

merge(left, right): [A: "A", len=1] + [D: "D", len=1]

After: chunks = ["A", "D"]  → "AD"
```

---

## 6. Format

**Goal**: apply `attributes` to the range `[position, position+length)`.

**Complexity**: O(log n + k) where k = number of chunks in the range.

```
function format(position, length, attributes):
    (left, midRight) = split(root, position)
    (mid, right) = split(midRight, length)

    formatted = applyAttributes(mid, attributes)
    // applyAttributes traverses in-order and merges via composeAttributes

    root = merge(merge(left, formatted), right)

function applyAttributes(node, attrs):
    if node == null: return null
    merged = composeAttributes(node.chunk.attributes, attrs)
    node.chunk = TextChunk(node.chunk.text, attributes: merged)
    node.left = applyAttributes(node.left, attrs)
    node.right = applyAttributes(node.right, attrs)
    node.update()
    return node
```

`composeAttributes(existing, new)` performs `{...existing, ...new}` and removes keys with `null` values, following the same semantics as `Delta.compose()`.

---

## 7. Slice

**Goal**: extract the range `[start, end)` as a legacy `Delta`.

**Complexity**: O(log n + k) where k = number of chunks in the range.

```
function slice(start, end):
    result = Delta()
    sliceRange(root, start, end, 0, result)
    return result

function sliceRange(node, start, end, currentPos, result):
    if node == null: return currentPos

    leftLen = node.left?.subtreeLength ?? 0

    // Left subtree
    if end > currentPos AND start < currentPos + leftLen:
        currentPos = sliceRange(node.left, start, end, currentPos, result)
    else:
        currentPos += leftLen   // Skip subtree, advance position

    // This node
    nodeEnd = currentPos + node.chunk.length
    if currentPos < end AND nodeEnd > start:
        // Overlap — extract sub-chunk
        chunkStart = max(0, start - currentPos)
        chunkEnd = min(node.chunk.length, end - currentPos)
        result.insert(
            node.chunk.text[chunkStart..chunkEnd],
            attributes: node.chunk.attributes
        )

    currentPos = nodeEnd

    // Right subtree
    rightLen = node.right?.subtreeLength ?? 0
    if currentPos < end AND start < currentPos + rightLen:
        currentPos = sliceRange(node.right, start, end, currentPos, result)
    else:
        currentPos += rightLen

    return currentPos
```

**Branch pruning**: the algorithm only visits nodes whose range overlaps `[start, end)`. Nodes entirely before or after are skipped, advancing `currentPos` by the corresponding `subtreeLength`.

---

## 8. applyDelta

**Goal**: apply a modification `Delta` (with `Retain`, `Insert`, `Delete`) to the document.

**Complexity**: O(|change| × log N).

```
function applyDelta(change):
    cursor = 0
    for each op in change.operations:
        if op is TextInsert:
            insert(cursor, op.text, attributes: op.attributes)
            cursor += op.text.length
        else if op is TextRetain:
            if op.attributes != null:
                format(cursor, op.length, op.attributes!)
            cursor += op.length
        else if op is TextDelete:
            delete(cursor, op.length)
            // cursor does NOT advance — text under cursor was removed
    return this
```

**Example**: `Delta()..retain(5)..insert("X")..delete(3)` on "Hello World":

```
cursor=0
Retain(5):          cursor += 5 → cursor=5
Insert("X"):        insert(5, "X") → "HelloX World"
                    cursor += 1 → cursor=6
Delete(3):          delete(6, 3) → removes " Wo" → "HelloXrld"
                    cursor unchanged

Result: "HelloXrld"
```

---

## 9. Complexities

| Operation | Complexity | Notes |
|-----------|------------|-------|
| `length` | O(1) | `_root?.subtreeLength` |
| `isEmpty` | O(1) | `_root == null` |
| `insert(pos, text)` | O(log n) | One split + two merge |
| `delete(pos, len)` | O(log n) | Two split + one merge |
| `format(pos, len, attrs)` | O(log n + k) | Two split + k-node walk + two merge |
| `attributesAt(pos)` | O(log n) | Binary search by subtreeLength |
| `slice(start, end)` | O(log n + k) | Pruned walk, k = nodes in range |
| `plainText(range)` | O(log n + k) | Pruned walk |
| `toDelta()` | O(n) | Full in-order walk |
| `toJson()` | O(n) | `toDelta().toJson()` |
| `toNativeJson()` | O(n) | Full in-order walk |
| `fromDelta(delta)` | O(n) | Cartesian tree builder |
| `fromNativeJson(json)` | O(n) | Cartesian tree builder |
| `applyDelta(change)` | O(\|change\| × log n) | Each op translated to O(log n) |
| `chunks` | O(n) | Full in-order walk |

**Expected treap height**: O(log n). With 10,000 chunks: height ≈ 14–20. With 1,000,000: height ≈ 30.

**Branching factor**: 2 (binary tree). No B-tree or higher fan-out structures are used — the binary tree is sufficient given the logarithmic height and implementation simplicity.
