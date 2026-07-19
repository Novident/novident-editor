import 'package:novident_editor/novident_editor.dart';
import 'package:flutter/services.dart';
import 'package:flutter/widgets.dart';

/// Coordinates the vim emulation of the editor.
///
/// Usage:
///
/// ```dart
/// final vimController = VimModeController();
///
/// NovidentEditor(
///   editorState: editorState,
///   commandShortcutEvents: [
///     // vim shortcuts must come first so they take precedence.
///     ...vimController.commandShortcutEvents,
///     ...standardCommandShortcutEvents,
///   ],
/// );
///
/// // after the editor is mounted (e.g. in a post frame callback):
/// vimController.attach(editorState);
/// ```
///
/// [attach] registers an [NovidentKeyboardServiceInterceptor] that swallows
/// IME input while the mode is not [VimMode.insert] — that's what prevents
/// typing in normal/visual mode.
///
/// Keybindings can be changed at runtime through [configuration]; the
/// cached [commandShortcutEvents] are re-bound in place, so the editor does
/// not need to be rebuilt:
///
/// ```dart
/// vimController.configuration =
///     vimController.configuration.rebind(VimCommand.moveLeft, 'a');
/// ```
class VimModeController extends ChangeNotifier {
  VimModeController({
    VimModeConfiguration configuration = const VimModeConfiguration(),
  })  : _configuration = configuration,
        _mode = configuration.initialMode {
    _events = buildVimModeCommandShortcutEvents(this);
    _interceptor = VimModeKeyboardInterceptor(this);
  }

  VimModeConfiguration _configuration;
  VimMode _mode;
  EditorState? _editorState;
  bool _interceptorRegistered = false;
  bool _suppressSelectionSync = false;
  String? _pendingCommand;
  CursorAppearanceBuilder? _previousCursorAppearanceBuilder;

  late final Map<VimCommand, CommandShortcutEvent> _events;
  late final VimModeKeyboardInterceptor _interceptor;

  /// The current mode.
  VimMode get mode => _mode;

  /// The pending operator, e.g. `'d'` after the first press of a `dd`
  /// sequence. Null when no operator is armed.
  String? get pendingCommand => _pendingCommand;

  /// Arms/clears a pending operator (used by the vim shortcut handlers).
  void setPendingCommand(String? command) {
    if (_pendingCommand == command) {
      return;
    }
    _pendingCommand = command;
    notifyListeners();
  }

  /// Whether the vim emulation is active.
  bool get enabled => _configuration.enabled;

  VimModeConfiguration get configuration => _configuration;

  /// Applies a new configuration.
  ///
  /// The keybindings of the cached [commandShortcutEvents] are updated in
  /// place — no editor rebuild is required.
  set configuration(VimModeConfiguration value) {
    if (_configuration == value) {
      return;
    }
    final enabledChanged = _configuration.enabled != value.enabled;
    _configuration = value;
    _applyKeybindings();
    if (enabledChanged && !value.enabled) {
      // leave the editor usable when the emulation is turned off.
      _mode = VimMode.insert;
    }
    notifyListeners();
    // re-paint the caret so style/enabled changes are visible immediately.
    _repaintCursor();
  }

  /// The vim [CommandShortcutEvent]s, one per [VimCommand].
  ///
  /// The list is stable: prepend it once to the editor's
  /// `commandShortcutEvents` and rebind keys at runtime through
  /// [configuration].
  List<CommandShortcutEvent> get commandShortcutEvents =>
      _events.values.toList(growable: false);

  /// The event bound to [command], or null when the command is not known.
  CommandShortcutEvent? commandShortcutEventOf(VimCommand command) =>
      _events[command];

  /// The IME interceptor that suppresses typing outside of insert mode.
  @visibleForTesting
  NovidentKeyboardServiceInterceptor get keyboardInterceptor => _interceptor;

  /// Binds the controller to [editorState], registers the IME interceptor
  /// on its keyboard service and starts listening to selection changes to
  /// keep the mode in sync with mouse interactions
  /// (see [VimModeConfiguration.syncModeWithSelection]).
  ///
  /// The keyboard service only exists after the editor is mounted; when it
  /// is not available yet, the registration is retried on the next frame.
  void attach(EditorState editorState) {
    detach();
    _editorState = editorState;
    editorState.selectionNotifier.addListener(_onEditorSelectionChanged);
    // chain the caret customizer so the native pipeline paints the vim
    // block cursor (no overlay involved).
    _previousCursorAppearanceBuilder = editorState.cursorAppearanceBuilder;
    editorState.cursorAppearanceBuilder = _cursorAppearanceBuilder;
    _registerInterceptor();
  }

  /// Unbinds the controller, unregisters the IME interceptor and restores
  /// the previous caret customizer.
  void detach() {
    final editorState = _editorState;
    if (editorState != null) {
      editorState.selectionNotifier.removeListener(_onEditorSelectionChanged);
      if (identical(
        editorState.cursorAppearanceBuilder,
        _cursorAppearanceBuilder,
      )) {
        editorState.cursorAppearanceBuilder = _previousCursorAppearanceBuilder;
      }
      if (_interceptorRegistered) {
        editorState.service.keyboardService
            ?.unregisterInterceptor(_interceptor);
      }
    }
    _previousCursorAppearanceBuilder = null;
    _interceptorRegistered = false;
    _pendingCommand = null;
    _editorState = null;
  }

  @override
  void dispose() {
    detach();
    super.dispose();
  }

  /// Switches to [VimMode.normal].
  ///
  /// When leaving visual mode with an expanded selection, the selection is
  /// collapsed at its end (vim-like behavior) unless [collapseSelection] is
  /// false — useful when a pending async operation (e.g. paste) still needs
  /// to consume the expanded selection and will set the final caret itself.
  /// Pass [editorState] to enable the collapse when the transition is
  /// triggered outside of a shortcut handler.
  void enterNormalMode({
    EditorState? editorState,
    bool collapseSelection = true,
  }) {
    final es = editorState ?? _editorState;
    if (collapseSelection && _mode == VimMode.visual && es != null) {
      final selection = es.selection;
      if (selection != null && !selection.isCollapsed) {
        es.updateSelectionWithReason(
          selection.normalized.collapse(),
          reason: SelectionUpdateReason.uiEvent,
        );
      }
    }
    _setMode(VimMode.normal);
  }

  /// Switches to [VimMode.insert].
  void enterInsertMode() => _setMode(VimMode.insert);

  /// Switches to [VimMode.visual] selecting whole nodes, like vim's
  /// linewise `V`.
  ///
  /// * With a collapsed caret, the entire current node is selected.
  /// * With an expanded (charwise) selection, it is widened to full-node
  ///   boundaries: start of the first node to end of the last one.
  ///
  /// Nodes without text (or empty ones) keep the selection collapsed at
  /// their start — the linewise operators for those cases are `dd`/`o`.
  void enterVisualLineMode({EditorState? editorState}) {
    final es = editorState ?? _editorState;
    _setMode(VimMode.visual);

    final selection = es?.selection;
    if (es == null || selection == null) {
      return;
    }
    final normalized = selection.normalized;
    final startNode = es.getNodeAtPath(normalized.start.path);
    final endNode = es.getNodeAtPath(normalized.end.path);
    if (startNode == null || endNode == null) {
      return;
    }

    es.updateSelectionWithReason(
      Selection(
        start: Position(path: startNode.path),
        end: Position(
          path: endNode.path,
          offset: endNode.delta?.length ?? 0,
        ),
      ),
      reason: SelectionUpdateReason.uiEvent,
    );
  }

  /// Switches to [VimMode.visual].
  ///
  /// Like vim's `v`, a collapsed caret immediately wraps the character
  /// under it (the block cursor already covers that character), so the
  /// visual operators (`d`, `x`, `y`, `p`) act on it right away. At the
  /// end of a line the last character is wrapped instead.
  void enterVisualMode({EditorState? editorState}) {
    final es = editorState ?? _editorState;
    _setMode(VimMode.visual);

    final selection = es?.selection;
    if (es == null || selection == null || !selection.isCollapsed) {
      return;
    }
    final node = es.getNodeAtPath(selection.end.path);
    final length = node?.delta?.length ?? 0;
    final offset = selection.end.offset;

    Selection? wrapped;
    if (offset < length) {
      wrapped = Selection(
        start: Position(path: selection.end.path, offset: offset),
        end: Position(path: selection.end.path, offset: offset + 1),
      );
    } else if (length > 0) {
      wrapped = Selection(
        start: Position(path: selection.end.path, offset: length - 1),
        end: Position(path: selection.end.path, offset: length),
      );
    }
    if (wrapped != null) {
      es.updateSelectionWithReason(
        wrapped,
        reason: SelectionUpdateReason.uiEvent,
      );
    }
  }

  /// Toggles [VimModeConfiguration.enabled].
  void toggleEnabled() {
    configuration = _configuration.copyWith(enabled: !_configuration.enabled);
  }

  void _setMode(VimMode mode) {
    if (_mode == mode) {
      return;
    }
    _mode = mode;
    _pendingCommand = null;
    notifyListeners();
    // the caret only repaints on selection changes — poke the notifier so
    // the new mode's cursor appearance is applied immediately.
    _repaintCursor();
  }

  /// Forces the selection areas to repaint the caret with the current
  /// mode/configuration, without changing the selection.
  void _repaintCursor() {
    final editorState = _editorState;
    if (editorState == null) {
      return;
    }
    _suppressSelectionSync = true;
    try {
      // PropertyValueNotifier notifies even when the value is identical.
      editorState.selectionNotifier.value = editorState.selection;
    } finally {
      _suppressSelectionSync = false;
    }
  }

  /// The caret customizer installed on the editor state: paints the vim
  /// block cursor in normal/visual mode and leaves the insert caret alone.
  CursorAppearance? _cursorAppearanceBuilder(
    Node node,
    Selection selection,
    Position caretPosition,
  ) {
    if (!enabled || _mode == VimMode.insert) {
      return _previousCursorAppearanceBuilder?.call(
        node,
        selection,
        caretPosition,
      );
    }

    final style = _configuration.cursorStyle;
    final displayPosition = _displayCaretPosition(selection, caretPosition);
    return CursorAppearance(
      // in visual mode, also paint the block at the moving head of the
      // selection so the user can see where it is being extended from.
      paintOnExpandedSelection: true,
      position: displayPosition,
      shouldBlink: style.blink,
      color: _resolveCursorBaseColor(style).withValues(alpha: style.opacity),
      rectBuilder: (rect) => _vimBlockRect(node, displayPosition, rect, style),
    );
  }

  /// Where the block cursor is *painted* — the selection itself is never
  /// altered.
  ///
  /// The internal selection is end-exclusive (`[a, b)` covers the
  /// characters `a..b-1`), so when the moving head is the upper bound of
  /// an expanded selection the block is rendered on `b - 1`: the last
  /// character actually selected. This keeps the caret visually still
  /// when `v` wraps the character under it, exactly like vim.
  ///
  /// Guards: collapsed selections, heads at offset 0 (the character
  /// `b - 1` would live in another block) and lower-bound heads
  /// (leftward/backward selections, already inclusive at that end) are
  /// left untouched.
  Position _displayCaretPosition(Selection selection, Position head) {
    if (selection.isCollapsed) {
      return head;
    }
    final normalized = selection.normalized;
    if (head != normalized.end || head.offset <= 0) {
      return head;
    }
    return Position(path: head.path, offset: head.offset - 1);
  }

  /// The block base color: the configured one or the editor caret color.
  ///
  /// `EditorState.editorStyle` is a `late` field initialized by the
  /// editor's first build; painting always happens afterwards, but keep a
  /// defensive fallback anyway.
  Color _resolveCursorBaseColor(VimCursorStyle style) {
    if (style.color != null) {
      return style.color!;
    }
    try {
      return _editorState?.editorStyle.cursorColor ?? const Color(0xFF00BCF0);
    } catch (_) {
      return const Color(0xFF00BCF0);
    }
  }

  /// Widens the caret rect into a block that covers the character under
  /// the caret, clamped so whitespace, ligatures, tabs and wide glyphs
  /// produce a reasonable block (see [VimCursorStyle]).
  Rect _vimBlockRect(
    Node node,
    Position position,
    Rect caretRect,
    VimCursorStyle style,
  ) {
    final height = caretRect.height;
    var width = style.blockWidth;

    if (width == null) {
      double? measured;
      final delta = node.delta;
      final selectable = node.selectable;
      if (delta != null &&
          selectable != null &&
          position.offset < delta.length) {
        final nextRect = selectable.getCursorRectInPosition(
          Position(path: position.path, offset: position.offset + 1),
        );
        if (nextRect != null) {
          final sameLine = (nextRect.top - caretRect.top).abs() < height / 2;
          if (sameLine && nextRect.left > caretRect.left) {
            measured = nextRect.left - caretRect.left;
          }
        }
      }
      final minWidth = height * style.minBlockWidthFactor;
      final maxWidth = height * style.maxBlockWidthFactor;
      width = (measured ?? minWidth).clamp(minWidth, maxWidth);
    }

    return Rect.fromLTWH(caretRect.left, caretRect.top, width, height);
  }

  /// Keeps the mode in sync with selection changes coming from UI events
  /// (mouse drag/click, select all).
  void _onEditorSelectionChanged() {
    if (_suppressSelectionSync) {
      return;
    }
    final editorState = _editorState;
    if (editorState == null ||
        !enabled ||
        !_configuration.syncModeWithSelection) {
      return;
    }

    final reason = editorState.selectionUpdateReason;
    if (reason != SelectionUpdateReason.uiEvent &&
        reason != SelectionUpdateReason.selectAll) {
      // edits collapse the selection through transactions — e.g. an
      // external paste (ctrl+v) replacing the visual selection. Like vim,
      // any edit leaves visual mode.
      final selection = editorState.selection;
      if (_mode == VimMode.visual &&
          (selection == null || selection.isCollapsed)) {
        _setMode(VimMode.normal);
      }
      return;
    }

    // a user driven selection change cancels any pending operator.
    if (_pendingCommand != null) {
      _pendingCommand = null;
      notifyListeners();
    }

    final selection = editorState.selection;
    if (selection == null) {
      if (_mode == VimMode.visual) {
        _setMode(VimMode.normal);
      }
      return;
    }

    if (!selection.isCollapsed) {
      // mouse drag / select all → visual mode.
      if (_mode != VimMode.visual) {
        _setMode(VimMode.visual);
      }
    } else if (_mode == VimMode.visual) {
      // mouse click collapses the selection → back to normal mode.
      _setMode(VimMode.normal);
    }
  }

  void _applyKeybindings() {
    // snapshot the resolved map once — the getter recomputes on every call.
    final Map<VimCommand, String> resolved = _configuration.keybindings;
    for (final entry in _events.entries) {
      final binding = resolved[entry.key];
      if (binding == null || binding.isEmpty) {
        entry.value.clearCommand();
      } else {
        entry.value.updateCommand(command: binding);
      }
    }
  }

  void _registerInterceptor() {
    final editorState = _editorState;
    if (editorState == null) {
      return;
    }
    final keyboardService = editorState.service.keyboardService;
    if (keyboardService != null) {
      keyboardService.registerInterceptor(_interceptor);
      _interceptorRegistered = true;
      return;
    }
    // the editor is not mounted yet — retry on the next frame while the
    // controller stays attached.
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (_editorState == editorState && !_interceptorRegistered) {
        _registerInterceptor();
      }
    });
  }
}

/// Swallows IME input while the vim emulation is enabled and the mode is
/// not [VimMode.insert].
class VimModeKeyboardInterceptor extends NovidentKeyboardServiceInterceptor {
  VimModeKeyboardInterceptor(this.controller);

  final VimModeController controller;

  bool get _blocked => controller.enabled && controller.mode != VimMode.insert;

  @override
  Future<bool> interceptInsert(
    TextEditingDeltaInsertion insertion,
    EditorState editorState,
    List<CharacterShortcutEvent> characterShortcutEvents,
  ) async {
    return _blocked;
  }

  @override
  Future<bool> interceptDelete(
    TextEditingDeltaDeletion deletion,
    EditorState editorState,
  ) async {
    return _blocked;
  }

  @override
  Future<bool> interceptReplace(
    TextEditingDeltaReplacement replacement,
    EditorState editorState,
    List<CharacterShortcutEvent> characterShortcutEvents,
  ) async {
    return _blocked;
  }

  @override
  Future<bool> interceptPerformAction(
    TextInputAction action,
    EditorState editorState,
  ) async {
    return _blocked;
  }
}
