import 'package:flutter/material.dart';
import 'package:novident_editor_core/novident_editor_core.dart';
import 'package:novident_editor_document/novident_editor_document.dart';

import 'selection_renderer.dart';

/// Host interface for [BlockSelectionArea] to query editor-level state
/// without depending on [EditorState].
///
/// The editor provides a concrete implementation (e.g. via an InheritedWidget
/// or Provider) that delegates to [EditorState].
abstract class BlockSelectionHost {
  /// Whether the current selection is a block-level selection.
  bool isBlockSelectionMode();

  /// Optional cursor appearance customization (vim-style, etc.).
  CursorAppearance? customizeCursor({
    required Node node,
    required Selection? selection,
    required Position position,
  });

  /// Margin to apply around block selection highlights, resolved from
  /// the block component builder configuration.
  EdgeInsets? blockSelectionMargin(Node node);

  /// Extra selection info value for the drag mode key.
  /// Returns `null` when not available.
  String? selectionDragModeValue();

  /// Custom selection/cursor renderer. Read from the host so it stays
  /// current even when the parent widget hasn't rebuilt (e.g. after
  /// [VimModeController.attach] swaps it at runtime).
  SelectionRenderer? get selectionRenderer;
}

/// Describes custom cursor appearance provided by the host.
class CursorAppearance {
  const CursorAppearance({
    this.style,
    this.shouldBlink,
    this.color,
    this.rectBuilder,
    this.paintOnExpandedSelection = false,
    this.position,
  });

  final CursorStyle? style;
  final bool? shouldBlink;
  final Color? color;
  final Rect Function(Rect)? rectBuilder;
  final bool paintOnExpandedSelection;
  final Position? position;
}
