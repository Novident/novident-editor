import 'dart:math';

import 'package:flutter/material.dart';
import 'package:novident_editor/novident_editor.dart';

import 'utils/style_resolver.dart';

const _kFontFamilyItemId = 'editor.fontFamily';
const _kDropdownWidth = 200.0;
const _kDropdownMaxHeight = 320.0;

/// Builds a desktop toolbar item that lets the user pick a font family
/// from a scrollable dropdown list.
///
/// [fontFamilies] is the list of available font families presented to the
/// user. When omitted, the list is taken from [editorState.fontProvider]
/// (which itself falls back to a universal safe set).
///
/// The effective font is resolved from the current node's style chain
/// (`basedOn`-merged), falling back to inline delta attributes.
/// When there is no selection the last known value is preserved.
///
/// The dropdown colours are driven by [highlightColor] and [iconColor]
/// (received from the toolbar's style configuration). An optional
/// [tooltipBuilder] wraps the button in a tooltip.
ToolbarItem buildFontFamilyItem({
  List<String>? fontFamilies,
}) {
  return ToolbarItem(
    id: _kFontFamilyItemId,
    group: 1,
    isActive: showInTextTypeEvenWithoutSelection,
    builder: (
      BuildContext context,
      EditorState editorState,
      Color highlightColor,
      Color? iconColor,
      ToolbarTooltipBuilder? tooltipBuilder,
    ) {
      final families = fontFamilies ??
          editorState.fontProvider?.availableFonts ??
          NovidentFontProvider.fallback().availableFonts;

      Widget child = _FontFamilyDropdownButton(
        editorState: editorState,
        fontFamilies: families,
        highlightColor: highlightColor,
        iconColor: iconColor,
      );
      if (tooltipBuilder != null) {
        child = tooltipBuilder(
          context,
          _kFontFamilyItemId,
          NovidentEditorL10n.current.fontFamily,
          child,
        );
      }
      return child;
    },
  );
}

class _FontFamilyDropdownButton extends StatefulWidget {
  const _FontFamilyDropdownButton({
    required this.editorState,
    required this.fontFamilies,
    required this.highlightColor,
    required this.iconColor,
  });

  final EditorState editorState;
  final List<String> fontFamilies;
  final Color highlightColor;
  final Color? iconColor;

  @override
  State<_FontFamilyDropdownButton> createState() =>
      _FontFamilyDropdownButtonState();
}

class _FontFamilyDropdownButtonState extends State<_FontFamilyDropdownButton> {
  final LayerLink _layerLink = LayerLink();
  OverlayEntry? _overlayEntry;
  bool _isOpen = false;

  /// Last known effective font family — preserved when selection is null.
  String? _cachedFontFamily;

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

  void _selectFamily(String family) {
    _removeOverlay();
    final selection = widget.editorState.selection;
    if (selection == null) return;

    widget.editorState.formatDelta(selection, {
      if (family.isNotEmpty)
        RichTextKeys.fontFamily: family
      else
        RichTextKeys.fontFamily: null,
    });
  }

  /// Returns the effective font family, updating the cache.
  String? _effectiveFontFamily() {
    final selection = widget.editorState.selection;
    if (selection != null) {
      final effective = _resolveFromNodeAndDelta();
      _cachedFontFamily = effective;
      return effective;
    }
    return _cachedFontFamily;
  }

  String? _resolveFromNodeAndDelta() {
    final selection = widget.editorState.selection;
    if (selection == null) return null;

    String? fromDelta;
    if (!selection.isCollapsed) {
      final nodes = widget.editorState.getNodesInSelection(selection);
      nodes.allSatisfyInSelection(selection, (delta) {
        return delta.everyAttributes((attr) {
          final raw = attr[RichTextKeys.fontFamily];
          if (raw is String && raw.isNotEmpty) {
            fromDelta = raw;
            return true;
          }
          return false;
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
          final raw = attr[RichTextKeys.fontFamily];
          if (raw is String && raw.isNotEmpty) {
            fromDelta = raw;
            return true;
          }
          return false;
        });
      });
    }
    if (fromDelta != null) return fromDelta;

    final node = widget.editorState.getNodeAtPath(selection.start.path);
    if (node != null) {
      final style =
          resolveEffectiveToolbarStyle(context, widget.editorState, node);
      final fromStyle = style.fontFamily;
      if (fromStyle != null && fromStyle.isNotEmpty) return fromStyle;
    }

    return null;
  }

  OverlayEntry _createOverlayEntry() {
    final family = _effectiveFontFamily();

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
                child: _FontFamilyMenuPanel(
                  fontFamilies: widget.fontFamilies,
                  currentFamily: family,
                  highlightColor: _highlightColor,
                  selectedBg: _selectedBg,
                  selectedText: _selectedText,
                  textColor: _textColor,
                  onSelected: _selectFamily,
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  String _displayLabel() {
    final family = _effectiveFontFamily();
    if (family != null && family.isNotEmpty) return family;
    // When nothing is explicitly set the button shows the provider's
    // default — this matches what kDefaultBaseStyle resolves to.
    final provider =
        widget.editorState.fontProvider ?? NovidentFontProvider.fallback();
    return provider.defaultFontFamily;
  }

  @override
  void dispose() {
    _overlayEntry?.remove();
    _overlayEntry = null;
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final family = _effectiveFontFamily();

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
              width: 1,
            ),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              ConstrainedBox(
                constraints:
                    const BoxConstraints(minWidth: 90, maxWidth: 150),
                child: Text(
                  _displayLabel(),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    fontSize: 12,
                    fontFamily: family,
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

class _FontFamilyMenuPanel extends StatelessWidget {
  const _FontFamilyMenuPanel({
    required this.fontFamilies,
    required this.currentFamily,
    required this.highlightColor,
    required this.selectedBg,
    required this.selectedText,
    required this.textColor,
    required this.onSelected,
  });

  final List<String> fontFamilies;
  final String? currentFamily;
  final Color highlightColor;
  final Color selectedBg;
  final Color selectedText;
  final Color textColor;
  final ValueChanged<String> onSelected;

  @override
  Widget build(BuildContext context) {
    // When no explicit font is set, the first entry shows the default font
    // name (from the provider) as the "clear / default state" label.
    final defaultFamily = fontFamilies.isNotEmpty ? fontFamilies.first : '';
    final entries = <_FontFamilyEntry>[
      _FontFamilyEntry(
        family: '',
        label: currentFamily == null ? defaultFamily : NovidentEditorL10n.current.noStyle,
        isSelected: currentFamily == null,
      ),
      ...fontFamilies.map(
        (f) => _FontFamilyEntry(
          family: f,
          label: f,
          isSelected: f == currentFamily,
        ),
      ),
    ];

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
          child: ListView(
            padding: const EdgeInsets.symmetric(vertical: 4),
            shrinkWrap: true,
            children: entries.map((entry) {
              return _FontFamilyMenuItem(
                label: entry.label,
                fontFamily: entry.family.isNotEmpty ? entry.family : null,
                isSelected: entry.isSelected,
                selectedBg: selectedBg,
                selectedText: selectedText,
                textColor: textColor,
                onTap: () => onSelected(entry.family),
              );
            }).toList(growable: false),
          ),
        ),
      ),
    );
  }
}

class _FontFamilyEntry {
  final String family;
  final String label;
  final bool isSelected;

  const _FontFamilyEntry({
    required this.family,
    required this.label,
    required this.isSelected,
  });
}

class _FontFamilyMenuItem extends StatelessWidget {
  const _FontFamilyMenuItem({
    required this.label,
    required this.fontFamily,
    required this.isSelected,
    required this.selectedBg,
    required this.selectedText,
    required this.textColor,
    required this.onTap,
  });

  final String label;
  final String? fontFamily;
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
        height: 32,
        padding: const EdgeInsets.symmetric(horizontal: 12),
        alignment: Alignment.centerLeft,
        decoration: BoxDecoration(
          color: isSelected ? selectedBg : null,
        ),
        child: Text(
          label,
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          style: TextStyle(
            fontSize: 13,
            fontFamily: fontFamily,
            fontWeight: isSelected ? FontWeight.w600 : FontWeight.normal,
            color: isSelected ? selectedText : textColor,
          ),
        ),
      ),
    );
  }
}
