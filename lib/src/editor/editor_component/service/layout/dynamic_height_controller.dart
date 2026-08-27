import 'dart:async';

import 'package:flutter/foundation.dart';

import 'dynamic_height_config.dart';
import 'height_cache.dart';

/// Controller for the dynamic height mode of the editor.
///
/// Orchestrates the [HeightCache] and exposes:
/// - [currentHeight]: the current editor height computed from cached block
///   heights, clamped to at least [DynamicHeightConfig.minHeight].
/// - [reportBlockHeight]: called by block components after layout to report
///   their measured height.
/// - [onDocumentMutation]: called by [EditorState.apply] to synchronize the
///   cache with document insertions, deletions, and text changes.
///
/// Can be created externally for programmatic control, or internally by
/// [DynamicHeightLayout] when only a config is provided.
class DynamicHeightController extends ChangeNotifier {
  DynamicHeightController({
    DynamicHeightConfig? config,
  }) : _config = config ?? const DynamicHeightConfig();

  DynamicHeightConfig _config;

  /// Current configuration.
  DynamicHeightConfig get config => _config;

  final HeightCache _cache = HeightCache();

  /// The underlying height cache.
  HeightCache get cache => _cache;

  /// Current height of the editor.
  ///
  /// The maximum of [DynamicHeightConfig.minHeight] and the total
  /// content height computed from the cache.
  double get currentHeight {
    final contentHeight = _cache.totalHeight;
    return contentHeight < _config.minHeight
        ? _config.minHeight
        : contentHeight;
  }

  /// Called by [BlockHeightReporter] after a block's layout.
  ///
  /// [index] is the position of the block in `parent.children`.
  /// [height] is the measured height of the block's [RenderBox].
  ///
  /// Returns `true` when the height changed by more than 1.0 px.
  bool reportBlockHeight(int index, double height) {
    final changed = _cache.reportHeight(index, height);
    if (changed) {
      _notifyWithDebounce();
    }
    return changed;
  }

  /// Called when a document mutation occurs.
  ///
  /// Must be called from [EditorState.apply] to keep the cache
  /// synchronized with insertions, deletions, and text changes.
  void onDocumentMutation(DocumentMutation mutation) {
    switch (mutation) {
      case NodesInserted(:final atIndex, :final count):
        _cache.onNodesInserted(atIndex, count);
      case NodesRemoved(:final atIndex, :final count):
        _cache.onNodesRemoved(atIndex, count);
      case TextChanged(:final nodeIndex):
        _cache.invalidateRange(nodeIndex, nodeIndex);
      case NodeUpdated(:final nodeIndex):
        _cache.invalidateRange(nodeIndex, nodeIndex);
    }
    _notifyWithDebounce();
  }

  /// Initializes the cache with [blockCount] blocks.
  ///
  /// Should be called when the editor mounts, after the root node's
  /// children are known.
  void initialize(int blockCount) {
    if (blockCount > 0) {
      _cache.onNodesInserted(0, blockCount);
    }
    notifyListeners();
  }

  /// Updates the configuration at runtime.
  void updateConfig(DynamicHeightConfig config) {
    if (config == _config) return;
    _config = config;
    notifyListeners();
  }

  /// Forces all cached heights to be re-measured.
  ///
  /// Useful when the editor style changes globally (font size, padding)
  /// and all block heights must be recomputed.
  void invalidateAll() {
    _cache.invalidateRange(0, _cache.blockCount - 1);
    notifyListeners();
  }

  Timer? _debounceTimer;

  void _notifyWithDebounce() {
    if (_config.resizeDebounce == Duration.zero) {
      notifyListeners();
      return;
    }

    _debounceTimer?.cancel();
    _debounceTimer = Timer(_config.resizeDebounce, () {
      notifyListeners();
    });
  }

  @override
  void dispose() {
    _debounceTimer?.cancel();
    _cache.dispose();
    super.dispose();
  }
}

/// Represents a document mutation that affects the block layout.
sealed class DocumentMutation {
  const DocumentMutation();
}

/// [count] nodes were inserted at position [atIndex].
final class NodesInserted extends DocumentMutation {
  final int atIndex;
  final int count;
  const NodesInserted({required this.atIndex, required this.count});
}

/// [count] nodes were removed starting at position [atIndex].
final class NodesRemoved extends DocumentMutation {
  final int atIndex;
  final int count;
  const NodesRemoved({required this.atIndex, required this.count});
}

/// The text content of the node at [nodeIndex] changed.
final class TextChanged extends DocumentMutation {
  final int nodeIndex;
  const TextChanged({required this.nodeIndex});
}

/// The top-level block at [nodeIndex] changed in a way that may affect its
/// height without changing the number of top-level blocks.
///
/// Covers attribute updates (e.g. the table row-height synchronization
/// writing cell heights) and structural changes nested inside a block
/// (e.g. adding a table row or column). The cached height is preserved
/// until the block re-reports its measured height.
final class NodeUpdated extends DocumentMutation {
  final int nodeIndex;
  const NodeUpdated({required this.nodeIndex});
}
