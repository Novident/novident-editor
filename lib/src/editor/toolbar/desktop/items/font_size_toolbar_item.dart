import 'dart:math';

import 'package:flutter/material.dart';
import 'package:novident_editor/novident_editor.dart';

import 'utils/style_resolver.dart';

const _kFontSizeItemId = 'editor.fontSize';
const _kDropdownWidth = 72.0;
const _kDropdownMaxHeight = 288.0;
const _kItemHeight = 32.0;
const _kDefaultFontSize = 12.0;

/// Builds a desktop toolbar item that lets the user pick a font size
/// from a scrollable list ranging from [minSize] to [maxSize].
///
/// The effective size is resolved from the current node's style chain
/// (`basedOn`-merged), falling back to inline delta attributes and
/// finally to [defaultSize] (default 12). When the dropdown opens it
/// auto-scrolls so the current size is centred in the visible area.
///
/// When there is no selection the last known value is preserved.
///
/// The dropdown colours are driven by [highlightColor] and [iconColor]
/// (received from the toolbar's style configuration). An optional
/// [tooltipBuilder] wraps the button in a tooltip.
ToolbarItem buildFontSizeItem({
  double minSize = 1,
  double maxSize = 99,
  double defaultSize = _kDefaultFontSize,
}) {
  assert(minSize < maxSize, 'minSize must be less than maxSize');

  return ToolbarItem(
    id: _kFontSizeItemId,
    group: 1,
    isActive: showInTextTypeEvenWithoutSelection,
    builder: (
      BuildContext context,
      EditorState editorState,
      Color highlightColor,
      Color? iconColor,
      ToolbarTooltipBuilder? tooltipBuilder,
    ) {
      Widget child = _FontSizeDropdownButton(
        editorState: editorState,
        minSize: minSize,
        maxSize: maxSize,
        defaultSize: defaultSize,
        highlightColor: highlightColor,
        iconColor: iconColor,
      );
      if (tooltipBuilder != null) {
        child = tooltipBuilder(
          context,
          _kFontSizeItemId,
          NovidentEditorL10n.current.fontSize,
          child,
        );
      }
      return child;
    },
  );
}

class _FontSizeDropdownButton extends StatefulWidget {
  const _FontSizeDropdownButton({
    required this.editorState,
    required this.minSize,
    required this.maxSize,
    required this.defaultSize,
    required this.highlightColor,
    required this.iconColor,
  });

  final EditorState editorState;
  final double minSize;
  final double maxSize;
  final double defaultSize;
  final Color highlightColor;
  final Color? iconColor;

  @override
  State<_FontSizeDropdownButton> createState() =>
      _FontSizeDropdownButtonState();
}

class _FontSizeDropdownButtonState extends State<_FontSizeDropdownButton> {
  final LayerLink _layerLink = LayerLink();
  OverlayEntry? _overlayEntry;
  bool _isOpen = false;

  /// Last known effective font size — preserved when selection is null.
  double _cachedFontSize = _kDefaultFontSize;

  Color get _highlightColor => widget.highlightColor;
  Color get _textColor => widget.iconColor ?? Colors.grey.shade700;
  Color get _arrowColor =>
      widget.iconColor?.withAlpha(180) ?? Colors.grey.shade500;
  Color get _selectedBg => _highlightColor.withAlpha(30);
  Color get _selectedText => _highlightColor;

  void _toggleOverlay() {
    if (_isOpen) {
      _removeOverlay();
    } else {
      _showOverlay();
    }
  }

  void _showOverlay() {
    _overlayEntry = _createOverlayEntry();
    Overlay.of(context).insert(_overlayEntry!);
    setState(() => _isOpen = true);
  }

  void _removeOverlay() {
    _overlayEntry?.remove();
    _overlayEntry = null;
    setState(() => _isOpen = false);
  }

  void _selectSize(double size) {
    _removeOverlay();
    final selection = widget.editorState.selection;
    if (selection == null) return;

    widget.editorState.formatDelta(selection, {
      RichTextKeys.fontSize: size,
    });
  }

  /// Returns the effective font size, updating the cache.
  double _effectiveFontSize() {
    final selection = widget.editorState.selection;
    if (selection != null) {
      final effective = _resolveFromNodeAndDelta();
      _cachedFontSize = effective;
      return effective;
    }
    return _cachedFontSize;
  }

  double _resolveFromNodeAndDelta() {
    final selection = widget.editorState.selection;
    if (selection == null) return widget.defaultSize;

    double? fromDelta;
    if (!selection.isCollapsed) {
      final nodes = widget.editorState.getNodesInSelection(selection);
      nodes.allSatisfyInSelection(selection, (delta) {
        return delta.everyAttributes((attr) {
          final raw = attr[RichTextKeys.fontSize];
          if (raw != null) {
            fromDelta = (raw is num) ? raw.toDouble() : double.tryParse('$raw');
          }
          return true;
        });
      });
    } else {
      final prevSelection = selection.copyWith(
        start: selection.start.copyWith(
          offset: max(selection.startIndex - 1, 0),
        ),
      );
      final nodes = widget.editorState.getNodesInSelection(prevSelection);
      nodes.allSatisfyInSelection(prevSelection, (delta) {
        return delta.everyAttributes((attr) {
          final raw = attr[RichTextKeys.fontSize];
          if (raw != null) {
            fromDelta = (raw is num) ? raw.toDouble() : double.tryParse('$raw');
          }
          return true;
        });
      });
    }
    if (fromDelta != null) return fromDelta!;

    final node = widget.editorState.getNodeAtPath(selection.start.path);
    if (node != null) {
      final style = resolveEffectiveToolbarStyle(
        context,
        widget.editorState,
        node,
      );
      final fromStyle = style.fontSize;
      return fromStyle;
    }

    return widget.defaultSize;
  }

  OverlayEntry _createOverlayEntry() {
    final sizes = _buildSizeList();
    final currentSize = _effectiveFontSize();

    return OverlayEntry(
      builder: (overlayContext) {
        return GestureDetector(
          behavior: HitTestBehavior.translucent,
          onTap: _removeOverlay,
          child: Stack(
            children: [
              CompositedTransformFollower(
                link: _layerLink,
                showWhenUnlinked: false,
                offset: const Offset(0, 36),
                child: _FontSizeMenuPanel(
                  sizes: sizes,
                  currentSize: currentSize,
                  highlightColor: _highlightColor,
                  selectedBg: _selectedBg,
                  selectedText: _selectedText,
                  textColor: _textColor,
                  onSelected: _selectSize,
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  List<double> _buildSizeList() {
    return List<double>.generate(
      (widget.maxSize - widget.minSize).toInt() + 1,
      (i) => widget.minSize + i,
      growable: false,
    );
  }

  @override
  void dispose() {
    _overlayEntry?.remove();
    _overlayEntry = null;
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final currentSize = _effectiveFontSize();

    return CompositedTransformTarget(
      link: _layerLink,
      child: InkWell(
        onTap: _toggleOverlay,
        borderRadius: BorderRadius.circular(4),
        hoverColor: Colors.black.withAlpha(10),
        child: Container(
          height: 28,
          padding: const EdgeInsets.symmetric(horizontal: 8),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(4),
            border: Border.all(
              color: _isOpen ? _highlightColor : Colors.transparent,
            ),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              ConstrainedBox(
                constraints: const BoxConstraints(minWidth: 36, maxWidth: 52),
                child: Text(
                  currentSize.truncateToDouble() == currentSize
                      ? '${currentSize.toInt()}'
                      : currentSize.toStringAsFixed(1),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    fontSize: 12,
                    color: _isOpen ? _highlightColor : _textColor,
                  ),
                ),
              ),
              const SizedBox(width: 2),
              Icon(
                _isOpen ? Icons.arrow_drop_up : Icons.arrow_drop_down,
                size: 16,
                color: _isOpen ? _highlightColor : _arrowColor,
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _FontSizeMenuPanel extends StatefulWidget {
  const _FontSizeMenuPanel({
    required this.sizes,
    required this.currentSize,
    required this.highlightColor,
    required this.selectedBg,
    required this.selectedText,
    required this.textColor,
    required this.onSelected,
  });

  final List<double> sizes;
  final double currentSize;
  final Color highlightColor;
  final Color selectedBg;
  final Color selectedText;
  final Color textColor;
  final ValueChanged<double> onSelected;

  @override
  State<_FontSizeMenuPanel> createState() => _FontSizeMenuPanelState();
}

class _FontSizeMenuPanelState extends State<_FontSizeMenuPanel> {
  final ScrollController _scrollController = ScrollController();
  bool _didInitialScroll = false;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (!_didInitialScroll) {
      _didInitialScroll = true;
      WidgetsBinding.instance.addPostFrameCallback((_) {
        _scrollToCurrent();
      });
    }
  }

  void _scrollToCurrent() {
    if (!_scrollController.hasClients) return;

    final index = widget.sizes.indexOf(widget.currentSize);
    if (index < 0) return;

    final visibleHeight = min(
      widget.sizes.length * _kItemHeight,
      _kDropdownMaxHeight,
    );
    final centerOffset =
        (index * _kItemHeight) - (visibleHeight / 2) + (_kItemHeight / 2);
    final maxOffset = max(
      0.0,
      (widget.sizes.length * _kItemHeight) - visibleHeight,
    );

    _scrollController.animateTo(
      centerOffset.clamp(0.0, maxOffset),
      duration: const Duration(milliseconds: 100),
      curve: Curves.easeOut,
    );
  }

  @override
  void dispose() {
    _scrollController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.transparent,
      child: Container(
        width: _kDropdownWidth,
        constraints: const BoxConstraints(maxHeight: _kDropdownMaxHeight),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(6),
          border: Border.all(color: Colors.black.withAlpha(26)),
          boxShadow: const [
            BoxShadow(
              color: Color(0x1A000000),
              blurRadius: 8,
              offset: Offset(0, 2),
            ),
          ],
        ),
        child: ClipRRect(
          borderRadius: BorderRadius.circular(6),
          child: ListView.builder(
            controller: _scrollController,
            padding: const EdgeInsets.symmetric(vertical: 4),
            itemCount: widget.sizes.length,
            itemExtent: _kItemHeight,
            itemBuilder: (context, index) {
              final size = widget.sizes[index];
              final isSelected = size == widget.currentSize;
              return _FontSizeMenuItem(
                size: size,
                isSelected: isSelected,
                selectedBg: widget.selectedBg,
                selectedText: widget.selectedText,
                textColor: widget.textColor,
                onTap: () => widget.onSelected(size),
              );
            },
          ),
        ),
      ),
    );
  }
}

class _FontSizeMenuItem extends StatelessWidget {
  const _FontSizeMenuItem({
    required this.size,
    required this.isSelected,
    required this.selectedBg,
    required this.selectedText,
    required this.textColor,
    required this.onTap,
  });

  final double size;
  final bool isSelected;
  final Color selectedBg;
  final Color selectedText;
  final Color textColor;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      child: Container(
        height: _kItemHeight,
        alignment: Alignment.center,
        decoration: BoxDecoration(
          color: isSelected ? selectedBg : null,
        ),
        child: Text(
          size.truncateToDouble() == size
              ? '${size.toInt()}'
              : size.toStringAsFixed(1),
          style: TextStyle(
            fontSize: 13,
            fontWeight: isSelected ? FontWeight.w600 : FontWeight.normal,
            color: isSelected ? selectedText : textColor,
          ),
        ),
      ),
    );
  }
}
