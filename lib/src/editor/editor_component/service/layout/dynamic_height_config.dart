/// Configuration for the dynamic height mode of the editor.
///
/// When provided to [NovidentEditor] via [NovidentEditor.dynamicHeightConfig],
/// the editor grows vertically as content is added, like an HTML `<textarea>`.
///
/// The final height of the editor is exactly the height of its content,
/// clamped to at least [minHeight].
class DynamicHeightConfig {
  const DynamicHeightConfig({
    this.availableWidth = 0,
    this.minHeight = 100.0,
    this.defaultBlockHeight = 60.0,
    this.resizeDebounce = Duration.zero,
  });

  /// Minimum height of the editor.
  ///
  /// The editor will never be smaller than this value, even when empty.
  final double minHeight;

  final double availableWidth;

  /// Estimated height for blocks that have not been measured yet.
  ///
  /// Used as initial value before a block reports its real height.
  /// A reasonable value reduces initial layout flicker.
  final double defaultBlockHeight;

  /// Debounce duration for height change notifications.
  ///
  /// Useful to avoid excessive rebuilds during rapid typing.
  /// [Duration.zero] means no debounce (every change notifies immediately).
  final Duration resizeDebounce;

  DynamicHeightConfig copyWith({
    double? availableWidth,
    double? minHeight,
    double? defaultBlockHeight,
    Duration? resizeDebounce,
  }) {
    return DynamicHeightConfig(
      availableWidth: availableWidth ?? this.availableWidth,
      minHeight: minHeight ?? this.minHeight,
      defaultBlockHeight: defaultBlockHeight ?? this.defaultBlockHeight,
      resizeDebounce: resizeDebounce ?? this.resizeDebounce,
    );
  }

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) return true;
    return other is DynamicHeightConfig &&
        other.minHeight == minHeight &&
        other.availableWidth == availableWidth &&
        other.defaultBlockHeight == defaultBlockHeight &&
        other.resizeDebounce == resizeDebounce;
  }

  @override
  int get hashCode => Object.hash(
        minHeight,
        defaultBlockHeight,
        resizeDebounce,
        availableWidth,
      );
}
