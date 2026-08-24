import 'package:flutter/material.dart';
import 'package:novident_editor/novident_editor.dart';

final styleToolbarItem = ToolbarItem(
  id: 'editor.style',
  group: 1,
  isActive: (editorState) => true,
  builder: (
    BuildContext context,
    EditorState editorState,
    Color highlightColor,
    Color? iconColor,
    ToolbarTooltipBuilder? tooltipBuilder,
  ) {
    Widget child = _StyleDropdownButton(
      editorState: editorState,
      highlightColor: highlightColor,
      iconColor: iconColor,
    );
    if (tooltipBuilder != null) {
      child = tooltipBuilder(
        context,
        'editor.style',
        NovidentEditorL10n.current.noStyle,
        child,
      );
    }
    return child;
  },
);

class _StyleDropdownButton extends StatefulWidget {
  const _StyleDropdownButton({
    required this.editorState,
    required this.highlightColor,
    required this.iconColor,
  });

  final EditorState editorState;
  final Color highlightColor;
  final Color? iconColor;

  @override
  State<_StyleDropdownButton> createState() => _StyleDropdownButtonState();
}

class _StyleDropdownButtonState extends State<_StyleDropdownButton> {
  final LayerLink _layerLink = LayerLink();
  OverlayEntry? _overlayEntry;
  bool _isOpen = false;

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

  void _selectStyle(String styleId) {
    _removeOverlay();
    final editorState = widget.editorState;
    final selection = editorState.selection;
    if (selection == null) return;
    editorState.updateNode(
      selection,
      (node) => node.copyWith(
        attributes: {
          ...node.attributes,
          if (styleId.isNotEmpty)
            blockComponentStyleRef: styleId
          else
            blockComponentStyleRef: null,
        },
      ),
    );
  }

  OverlayEntry _createOverlayEntry() {
    return OverlayEntry(
      builder: (overlayContext) {
        final config = NovidentEditorStyles.maybeOf(context)?.config;
        final allStyles = config?.registry.styles.values.toList() ?? [];

        final editorState = widget.editorState;
        final selection = editorState.selection;
        final node = selection != null
            ? editorState.getNodeAtPath(selection.start.path)
            : null;
        final currentStyleRef =
            node?.attributes[blockComponentStyleRef] as String?;

        return GestureDetector(
          behavior: HitTestBehavior.translucent,
          onTap: _removeOverlay,
          child: Stack(
            children: [
              CompositedTransformFollower(
                link: _layerLink,
                showWhenUnlinked: false,
                offset: const Offset(0, 36),
                child: _StyleMenuPanel(
                  allStyles: allStyles,
                  currentStyleRef: currentStyleRef,
                  noStyleLabel: NovidentEditorL10n.current.noStyle,
                  highlightColor: _highlightColor,
                  selectedBg: _selectedBg,
                  selectedText: _selectedText,
                  textColor: _textColor,
                  onSelected: _selectStyle,
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  @override
  void dispose() {
    _overlayEntry?.remove();
    _overlayEntry = null;
    super.dispose();
  }

  String _currentLabel() {
    final config = NovidentEditorStyles.maybeOf(context)?.config;
    final editorState = widget.editorState;
    final selection = editorState.selection;
    if (selection == null) return NovidentEditorL10n.current.noStyle;
    final node = editorState.getNodeAtPath(selection.start.path);
    if (node == null) return NovidentEditorL10n.current.noStyle;
    final styleRef = node.attributes[blockComponentStyleRef] as String?;
    if (styleRef != null && styleRef.isNotEmpty) {
      final name = config?.registry[styleRef]?.name;
      if (name != null) return name;
    }
    return NovidentEditorL10n.current.noStyle;
  }

  @override
  Widget build(BuildContext context) {
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
                constraints: const BoxConstraints(minWidth: 70, maxWidth: 130),
                child: Text(
                  _currentLabel(),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
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

class _StyleMenuPanel extends StatelessWidget {
  const _StyleMenuPanel({
    required this.allStyles,
    required this.currentStyleRef,
    required this.noStyleLabel,
    required this.highlightColor,
    required this.selectedBg,
    required this.selectedText,
    required this.textColor,
    required this.onSelected,
  });

  final List<NovidentStyleDefinition> allStyles;
  final String? currentStyleRef;
  final String noStyleLabel;
  final Color highlightColor;
  final Color selectedBg;
  final Color selectedText;
  final Color textColor;
  final ValueChanged<String> onSelected;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.transparent,
      child: Container(
        width: 200,
        constraints: const BoxConstraints(maxHeight: 320),
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
            children: [
              _StyleMenuItem(
                label: noStyleLabel,
                isSelected: currentStyleRef == null,
                selectedBg: selectedBg,
                selectedText: selectedText,
                textColor: textColor,
                onTap: () => onSelected(''),
              ),
              for (final style in allStyles)
                _StyleMenuItem(
                  label: style.name,
                  isSelected: style.id == currentStyleRef,
                  selectedBg: selectedBg,
                  selectedText: selectedText,
                  textColor: textColor,
                  onTap: () => onSelected(style.id),
                ),
            ],
          ),
        ),
      ),
    );
  }
}

class _StyleMenuItem extends StatelessWidget {
  const _StyleMenuItem({
    required this.label,
    required this.isSelected,
    required this.selectedBg,
    required this.selectedText,
    required this.textColor,
    required this.onTap,
  });

  final String label;
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
            fontWeight: isSelected ? FontWeight.w600 : FontWeight.normal,
            color: isSelected ? selectedText : textColor,
          ),
        ),
      ),
    );
  }
}
