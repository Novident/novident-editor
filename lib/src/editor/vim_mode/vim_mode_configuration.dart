import 'dart:ui' show Color;

import 'package:flutter/foundation.dart';

/// The editing modes of the vim emulation.
enum VimMode {
  /// Keys are interpreted as commands (motions, operators, mode changes).
  /// Typing is suppressed.
  normal,

  /// The editor behaves as usual; `Esc` (configurable) returns to
  /// [VimMode.normal].
  insert,

  /// Motions extend the current selection instead of moving the caret.
  visual,
}

/// The remappable vim commands.
///
/// Every command is bound to a key sequence through
/// [VimModeConfiguration.keybindings]. The binding format is the same used
/// by `CommandShortcutEvent.command`: a comma separated list of
/// `modifier+key` combinations (e.g. `'h'`, `'shift+g'`, `'ctrl+d'`,
/// `'h,arrow left'`).
class VimCommand {
  final int code;
  const VimCommand(this.code);

  /// Returns to [VimMode.normal] (default: `escape`).
  static const VimCommand enterNormalMode = VimCommand(0);

  /// Enters [VimMode.insert] at the caret (default: `i`).
  static const VimCommand enterInsertMode = VimCommand(1);

  /// Toggles [VimMode.visual] (default: `v`).
  static const VimCommand enterVisualMode = VimCommand(2);

  /// Moves one character right, then enters insert mode (default: `a`).
  static const VimCommand enterInsertModeAfter = VimCommand(3);

  /// Moves to the start of the line, then enters insert mode
  /// (default: `shift+i`).
  static const VimCommand enterInsertModeLineStart = VimCommand(4);

  /// Moves to the end of the line, then enters insert mode
  /// (default: `shift+a`).
  static const VimCommand enterInsertModeLineEnd = VimCommand(5);

  /// Inserts an empty paragraph below and enters insert mode (default: `o`).
  static const VimCommand openLineBelow = VimCommand(6);

  /// Inserts an empty paragraph above and enters insert mode
  /// (default: `shift+o`).
  static const VimCommand openLineAbove = VimCommand(7);

  /// Enters [VimMode.visual] selecting the whole current node (vim's
  /// linewise `V`). From charwise visual it expands the selection to
  /// full-node boundaries (default: `shift+v`).
  static const VimCommand enterVisualLineMode = VimCommand(8);

  /// Default: `h`.
  static const VimCommand moveLeft = VimCommand(9);

  /// Default: `j`.
  static const VimCommand moveDown = VimCommand(10);

  /// Default: `k`.
  static const VimCommand moveUp = VimCommand(11);

  /// Default: `l`.
  static const VimCommand moveRight = VimCommand(12);

  /// Default: `w`.
  static const VimCommand moveWordForward = VimCommand(13);

  /// Default: `b`.
  static const VimCommand moveWordBackward = VimCommand(14);

  /// Default: `digit 0` (the `0` key).
  static const VimCommand moveLineStart = VimCommand(15);

  /// Default: `shift+digit 4` (`$` on a US layout).
  static const VimCommand moveLineEnd = VimCommand(16);

  /// Default: `g`.
  ///
  /// Note: this deviates from vim's `gg` — multi-key sequences are not
  /// supported yet.
  static const VimCommand moveDocumentStart = VimCommand(17);

  /// Default: `shift+g`.
  static const VimCommand moveDocumentEnd = VimCommand(18);

  /// Moves the caret to the start of the previous block (default: `{`,
  /// bound as `shift+bracket left,shift+brace left` to cover the different
  /// logical keys reported per platform).
  static const VimCommand moveBlockPrevious = VimCommand(19);

  /// Moves the caret to the start of the next block (default: `}`,
  /// bound as `shift+bracket right,shift+brace right`).
  static const VimCommand moveBlockNext = VimCommand(20);

  /// Default: `ctrl+u`.
  static const VimCommand pageUp = VimCommand(21);

  /// Default: `ctrl+d`.
  static const VimCommand pageDown = VimCommand(22);

  /// Deletes (cuts) the character under the caret, or the selection in
  /// visual mode. The removed content is copied to the clipboard when a
  /// selection is involved (default: `x`).
  static const VimCommand deleteUnderCursor = VimCommand(23);

  /// Vim's `d` operator (default: `d`).
  ///
  /// * In normal mode it is a pending operator: pressing it twice (`dd`)
  ///   cuts the current line — the line is copied to the clipboard and
  ///   removed. A single press only arms the operator
  ///   (see `VimModeController.pendingCommand`).
  /// * In visual mode a single press cuts the selection.
  static const VimCommand deleteLine = VimCommand(24);

  /// Copies the selection and returns to normal mode. Only effective in
  /// visual mode (default: `y`).
  static const VimCommand yank = VimCommand(25);

  /// Pastes the clipboard content (default: `p`).
  static const VimCommand paste = VimCommand(26);

  /// Default: `u`.
  static const VimCommand undo = VimCommand(27);

  /// Default: `ctrl+r`.
  static const VimCommand redo = VimCommand(28);

  @override
  bool operator ==(Object other) {
    return other is VimCommand && other.code == code;
  }

  @override
  int get hashCode => code.hashCode;
}

/// The appearance of the vim block cursor painted while the editor is in
/// normal or visual mode (the insert caret is never altered).
///
/// The block is painted by the editor's native caret pipeline through
/// `EditorState.cursorAppearanceBuilder` — no extra overlay is involved.
///
/// Width policy: [blockWidth] wins when set; otherwise the character under
/// the caret is measured from the text layout and clamped between
/// [minBlockWidthFactor] and [maxBlockWidthFactor] (both relative to the
/// caret height, i.e. font-size aware). The clamp keeps the block usable
/// on whitespace (too narrow) and on ligatures/tabs/wide glyphs (too wide).
@immutable
class VimCursorStyle {
  const VimCursorStyle({
    this.color,
    this.opacity = 0.55,
    this.blink = false,
    this.blockWidth,
    this.minBlockWidthFactor = 0.4,
    this.maxBlockWidthFactor = 1.0,
  })  : assert(opacity >= 0.0 && opacity <= 1.0),
        assert(blockWidth == null || blockWidth > 0),
        assert(minBlockWidthFactor > 0),
        assert(maxBlockWidthFactor >= minBlockWidthFactor);

  /// The color of the block cursor. Defaults to the editor's
  /// `EditorStyle.cursorColor` when null.
  final Color? color;

  /// The opacity of the block, so the character underneath stays readable.
  final double opacity;

  /// Whether the block cursor blinks. Defaults to false (a steady block,
  /// like most vim implementations).
  final bool blink;

  /// Fixed width of the block. When null (default) the block covers the
  /// character under the caret, measured from the text layout and clamped
  /// by [minBlockWidthFactor]/[maxBlockWidthFactor].
  final double? blockWidth;

  /// Lower bound of the measured width, as a fraction of the caret height.
  ///
  /// Also used when there is nothing to measure (end of line, empty
  /// paragraph). With the default line height, `0.4 × height` is roughly
  /// `0.6em` — close to a terminal cell.
  final double minBlockWidthFactor;

  /// Upper bound of the measured width, as a fraction of the caret height,
  /// so ligatures, tabs and very wide glyphs don't produce a huge block.
  final double maxBlockWidthFactor;

  VimCursorStyle copyWith({
    Color? color,
    double? opacity,
    bool? blink,
    double? blockWidth,
    double? minBlockWidthFactor,
    double? maxBlockWidthFactor,
  }) {
    return VimCursorStyle(
      color: color ?? this.color,
      opacity: opacity ?? this.opacity,
      blink: blink ?? this.blink,
      blockWidth: blockWidth ?? this.blockWidth,
      minBlockWidthFactor: minBlockWidthFactor ?? this.minBlockWidthFactor,
      maxBlockWidthFactor: maxBlockWidthFactor ?? this.maxBlockWidthFactor,
    );
  }

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) {
      return true;
    }
    return other is VimCursorStyle &&
        other.color == color &&
        other.opacity == opacity &&
        other.blink == blink &&
        other.blockWidth == blockWidth &&
        other.minBlockWidthFactor == minBlockWidthFactor &&
        other.maxBlockWidthFactor == maxBlockWidthFactor;
  }

  @override
  int get hashCode => Object.hash(
        color,
        opacity,
        blink,
        blockWidth,
        minBlockWidthFactor,
        maxBlockWidthFactor,
      );
}

/// Configuration of the vim emulation.
///
/// All the keybindings are customizable:
///
/// ```dart
/// const config = VimModeConfiguration(
///   keybindings: {
///     // move with wasd instead of hjkl
///     VimCommand.moveLeft: 'a',
///     VimCommand.moveDown: 's',
///     VimCommand.moveUp: 'w',
///     VimCommand.moveRight: 'd',
///   },
/// );
/// ```
///
/// Bindings not present in [keybindings] fall back to [defaultKeybindings].
/// When an explicit override steals a key from another command's default,
/// that command is unbound (set to empty string).
@immutable
class VimModeConfiguration {
  const VimModeConfiguration({
    this.enabled = true,
    this.initialMode = VimMode.normal,
    this.syncModeWithSelection = true,
    this.cursorStyle = const VimCursorStyle(),
    Map<VimCommand, String> keybindings = const {},
  }) : _rawKeybindings = keybindings;

  VimModeConfiguration.defaultBindings({
    this.enabled = true,
    this.initialMode = VimMode.normal,
    this.syncModeWithSelection = true,
    this.cursorStyle = const VimCursorStyle(),
    Map<VimCommand, String> keybindings = const {},
  }) : _rawKeybindings = {...defaultKeybindings, ...keybindings};

  /// Whether the vim emulation is active. When false, every vim shortcut
  /// is ignored and typing behaves as usual.
  final bool enabled;

  /// The mode the controller starts in.
  final VimMode initialMode;

  /// Whether mouse/selection changes drive the mode:
  ///
  /// * expanding the selection (mouse drag, select all) enters
  ///   [VimMode.visual];
  /// * collapsing it (mouse click) while in visual mode returns to
  ///   [VimMode.normal].
  ///
  /// Only selection updates coming from UI events are considered — the
  /// selections produced by transactions (typing, undo, …) never switch
  /// the mode.
  final bool syncModeWithSelection;

  /// The appearance of the block cursor painted through the editor's
  /// native caret pipeline in normal and visual mode. The insert caret is
  /// never altered.
  final VimCursorStyle cursorStyle;

  /// The raw user overrides supplied through [VimModeConfiguration.new]
  /// or [rebind].
  final Map<VimCommand, String> _rawKeybindings;

  /// The resolved keybindings: every built-in command has an entry
  /// (default or user override).  Commands whose default binding was
  /// shadowed by an explicit override of another command are set to the
  /// empty string (unbound).
  Map<VimCommand, String> get keybindings => _resolve(_rawKeybindings);

  /// The built-in bindings, following vim conventions where possible.
  static final Map<VimCommand, String> defaultKeybindings = Map.unmodifiable({
    VimCommand.enterNormalMode: 'escape',
    VimCommand.enterInsertMode: 'i',
    VimCommand.enterInsertModeAfter: 'a',
    VimCommand.enterInsertModeLineStart: 'shift+i',
    VimCommand.enterInsertModeLineEnd: 'shift+a',
    VimCommand.openLineBelow: 'o',
    VimCommand.openLineAbove: 'shift+o',
    VimCommand.enterVisualMode: 'v',
    VimCommand.enterVisualLineMode: 'shift+v',
    VimCommand.moveLeft: 'h',
    VimCommand.moveDown: 'j',
    VimCommand.moveUp: 'k',
    VimCommand.moveRight: 'l',
    VimCommand.moveWordForward: 'e',
    VimCommand.moveWordBackward: 'b',
    VimCommand.moveLineStart: 'digit 0',
    VimCommand.moveLineEnd: 'shift+digit 4',
    VimCommand.moveDocumentStart: 'g',
    VimCommand.moveDocumentEnd: 'shift+g',
    VimCommand.moveBlockPrevious: '{,shift+bracket left,shift+brace left',
    VimCommand.moveBlockNext: '},shift+bracket right,shift+brace right',
    VimCommand.pageUp: 'ctrl+u',
    VimCommand.pageDown: 'ctrl+d',
    VimCommand.deleteUnderCursor: 'x',
    VimCommand.deleteLine: 'd',
    VimCommand.yank: 'y',
    VimCommand.paste: 'p',
    VimCommand.undo: 'u',
    VimCommand.redo: 'ctrl+r',
  });

  /// The effective binding of [command]: checks the resolved map first,
  /// then falls back to [defaultKeybindings] for commands not in the map.
  ///
  /// Returns `null` when the command is not known at all.
  String? commandOf(VimCommand command) =>
      keybindings[command] ?? defaultKeybindings[command];

  VimModeConfiguration copyWith({
    bool? enabled,
    VimMode? initialMode,
    bool? syncModeWithSelection,
    VimCursorStyle? cursorStyle,
    Map<VimCommand, String>? keybindings,
  }) {
    return VimModeConfiguration(
      enabled: enabled ?? this.enabled,
      initialMode: initialMode ?? this.initialMode,
      syncModeWithSelection:
          syncModeWithSelection ?? this.syncModeWithSelection,
      cursorStyle: cursorStyle ?? this.cursorStyle,
      keybindings: keybindings ?? _rawKeybindings,
    );
  }

  /// Returns a copy with [command] bound to [keys], keeping the other
  /// overrides.
  VimModeConfiguration rebind(VimCommand command, String keys) {
    return copyWith(
      keybindings: <VimCommand, String>{
        ..._rawKeybindings,
        command: keys,
      },
    );
  }

  /// Builds the resolved map: defaults merged with user overrides, minus
  /// any default binding whose key-sequence was stolen by an explicit
  /// override of a different command.
  static Map<VimCommand, String> _resolve(Map<VimCommand, String> overrides) {
    final result = Map<VimCommand, String>.from(defaultKeybindings);

    // Collect every individual key used by explicit overrides.
    final usedKeys = <String>{};
    for (final binding in overrides.values) {
      for (final token in binding.split(',')) {
        usedKeys.add(token.trim());
      }
    }

    // Clear default bindings that conflict with explicit overrides.
    for (final entry in result.entries.toList()) {
      for (final token in entry.value.split(',')) {
        if (usedKeys.contains(token.trim())) {
          result[entry.key] = '';
          break;
        }
      }
    }

    // Layer user overrides on top.
    result.addAll(overrides);

    return Map.unmodifiable(result);
  }

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) {
      return true;
    }
    return other is VimModeConfiguration &&
        other.enabled == enabled &&
        other.initialMode == initialMode &&
        other.syncModeWithSelection == syncModeWithSelection &&
        other.cursorStyle == cursorStyle &&
        mapEquals(other._rawKeybindings, _rawKeybindings);
  }

  @override
  int get hashCode => Object.hash(
        enabled,
        initialMode,
        syncModeWithSelection,
        cursorStyle,
        Object.hashAllUnordered(
          _rawKeybindings.entries.map((e) => Object.hash(e.key, e.value)),
        ),
      );
}
