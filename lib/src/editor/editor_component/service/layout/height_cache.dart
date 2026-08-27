/// Incremental height cache for editor blocks.
///
/// Maintains a sparse map `[index → height]` with O(1) updates for
/// individual blocks and O(k) index-shift operations for insertions
/// and deletions (where k is the number of shifted indices).
///
/// Unmeasured blocks are estimated with [defaultHeight]. Heights are
/// only considered changed when the delta exceeds 1.0 logical pixel.
final class HeightCache {
  HeightCache({this.defaultHeight = 60.0});

  /// Estimated height for blocks that have not been measured yet.
  final double defaultHeight;

  final Map<int, double> _heights = {};
  double _totalHeight = 0.0;
  int _blockCount = 0;

  /// Number of times [reportHeight] was called with a novel height.
  /// > 0 means at least one real layout measurement was fed back.
  int _measurementCount = 0;

  /// Indices that were invalidated and must be re-measured.
  final Set<int> _dirty = {};

  final List<void Function()> _listeners = [];

  /// Sum of all block heights (measured + estimated).
  double get totalHeight => _totalHeight;

  /// Total number of registered blocks.
  int get blockCount => _blockCount;

  /// Whether at least one block has been measured via [reportHeight].
  bool get hasMeasuredBlocks => _measurementCount > 0;

  /// Height of the block at [index] (measured value or [defaultHeight]).
  double heightOf(int index) {
    RangeError.checkNotNegative(index, 'index');
    return _heights[index] ?? defaultHeight;
  }

  /// Reports the measured height of a block after layout.
  ///
  /// Returns `true` when the height changed by more than 1.0 px,
  /// indicating that listeners should be notified.
  bool reportHeight(int index, double height) {
    RangeError.checkNotNegative(index, 'index');
    final isDirty = _dirty.remove(index);
    final old = _heights[index];
    if (!isDirty && old != null && (old - height).abs() < 1.0) {
      return false;
    }
    final delta = height - (old ?? defaultHeight);
    _heights[index] = height;
    _totalHeight += delta;
    _measurementCount++;
    return true;
  }

  /// Notifies the cache that [count] blocks were inserted at [atIndex].
  ///
  /// Existing indices ≥ [atIndex] are shifted by +[count]. The new
  /// blocks are estimated with [defaultHeight] until measured.
  void onNodesInserted(int atIndex, int count) {
    RangeError.checkNotNegative(atIndex, 'atIndex');
    if (count <= 0) return;

    _blockCount += count;
    _totalHeight += count * defaultHeight;

    final keysToShift = _heights.keys
        .where((k) => k >= atIndex)
        .toList(growable: false)
      ..sort((a, b) => b.compareTo(a));

    for (final oldIndex in keysToShift) {
      final height = _heights.remove(oldIndex)!;
      _heights[oldIndex + count] = height;
    }
  }

  /// Notifies the cache that [count] blocks were removed starting at
  /// [atIndex].
  ///
  /// Cached entries for the removed indices are discarded. Indices
  /// after the removed range are compacted.
  void onNodesRemoved(int atIndex, int count) {
    RangeError.checkNotNegative(atIndex, 'atIndex');
    if (count <= 0) return;

    _blockCount -= count;

    for (int i = atIndex; i < atIndex + count; i++) {
      final removed = _heights.remove(i);
      if (removed != null) {
        _totalHeight -= removed;
      } else {
        _totalHeight -= defaultHeight;
      }
    }

    final keysToShift = _heights.keys
        .where((k) => k >= atIndex + count)
        .toList(growable: false)
      ..sort();

    for (final oldIndex in keysToShift) {
      final height = _heights.remove(oldIndex)!;
      _heights[oldIndex - count] = height;
    }
  }

  /// Invalidates cached heights in the range [start, end] (inclusive).
  ///
  /// The existing height estimate is preserved in [_totalHeight] until a
  /// new measurement arrives via [reportHeight], preventing one-frame
  /// overflow when content grows.
  void invalidateRange(int start, [int? end]) {
    RangeError.checkNotNegative(start, 'start');
    final endIdx = end ?? _blockCount - 1;
    if (endIdx < start) return;

    for (int i = start; i <= endIdx && i < _blockCount; i++) {
      if (!_heights.containsKey(i)) {
        _totalHeight += defaultHeight;
      }
      _dirty.add(i);
    }
  }

  /// Accumulated height from index 0 up to [upToIndex] (inclusive).
  double accumulatedHeightUpTo(int upToIndex) {
    double sum = 0.0;
    final limit = upToIndex >= _blockCount ? _blockCount - 1 : upToIndex;
    for (int i = 0; i <= limit; i++) {
      sum += heightOf(i);
    }
    return sum;
  }

  /// Registers a listener that is called when the total height changes.
  void addListener(void Function() listener) {
    _listeners.add(listener);
  }

  /// Removes a previously registered listener.
  void removeListener(void Function() listener) {
    _listeners.remove(listener);
  }

  /// Notifies all registered listeners. Call after one or more
  /// operations that produced changes.
  void notifyIfChanged(bool changed) {
    if (changed) {
      for (final listener in _listeners) {
        listener();
      }
    }
  }

  /// Clears all cached heights and resets the block count to zero.
  void clear() {
    _heights.clear();
    _totalHeight = 0.0;
    _blockCount = 0;
    _measurementCount = 0;
  }

  /// Releases resources and clears all listeners.
  void dispose() {
    _listeners.clear();
    clear();
  }
}
