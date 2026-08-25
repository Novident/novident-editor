import 'package:novident_editor/novident_editor.dart';
import 'package:novident_editor/src/editor/editor_component/service/ime/delta_input_on_floating_cursor_update.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';

import 'ime/delta_input_impl.dart';

// handle software keyboard and hardware keyboard
class KeyboardServiceWidget extends StatefulWidget {
  const KeyboardServiceWidget({
    super.key,
    this.commandShortcutEvents = const [],
    @Deprecated(
      "Use keyboardStrategies and define DefaultEditorStrategy instead",
    )
    this.characterShortcutEvents = const [],
    @Deprecated(
      "Use keyboardStrategies and define DefaultEditorStrategy instead",
    )
    this.keyboardStrategies = const [],
    this.focusNode,
    this.contentInsertionConfiguration,
    required this.child,
  });

  final ContentInsertionConfiguration? contentInsertionConfiguration;
  final FocusNode? focusNode;

  @Deprecated("Use keyboardStrategies and define DefaultEditorStrategy instead")
  final List<CommandShortcutEvent> commandShortcutEvents;
  @Deprecated("Use keyboardStrategies and define DefaultEditorStrategy instead")
  final List<CharacterShortcutEvent> characterShortcutEvents;

  /// Physical keyboard interpretation policies, consulted in order (the
  /// first one that does not return `ignored` wins).
  ///
  /// When empty (default), a [DefaultEditorStrategy] is used over
  /// [commandShortcutEvents].
  final List<KeyboardStrategy> keyboardStrategies;

  final Widget child;

  @override
  State<KeyboardServiceWidget> createState() => KeyboardServiceWidgetState();
}

@visibleForTesting
class KeyboardServiceWidgetState extends State<KeyboardServiceWidget>
    implements NovidentKeyboardService {
  late final SelectionGestureInterceptor interceptor;
  late final EditorState editorState;
  late final TextInputService textInputService;
  late final FocusNode focusNode;

  final List<NovidentKeyboardServiceInterceptor> interceptors = [];

  /// Effective keyboard strategies, derived from the widget's parameters.
  late List<KeyboardStrategy> _strategies;

  // previous selection
  Selection? previousSelection;

  // use for IME only
  bool enableIMEShortcuts = true;

  // use for hardware keyboard only
  bool enableKeyboardShortcuts = true;

  @override
  void initState() {
    super.initState();

    _strategies = _buildStrategies();

    editorState = Provider.of<EditorState>(context, listen: false);
    editorState.selectionNotifier.addListener(_onSelectionChanged);

    interceptor = SelectionGestureInterceptor(
      key: 'keyboard',
      canTap: (details) {
        enableIMEShortcuts = true;
        focusNode.requestFocus();
        textInputService.close();
        return true;
      },
    );
    editorState.service.selectionService
        .registerGestureInterceptor(interceptor);

    textInputService = buildTextInputService();

    focusNode = widget.focusNode ?? FocusNode(debugLabel: 'keyboard service');
    focusNode.addListener(_onFocusChanged);

    keepEditorFocusNotifier.addListener(_onKeepEditorFocusChanged);
  }

  @override
  void didUpdateWidget(covariant KeyboardServiceWidget oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (!identical(
          oldWidget.commandShortcutEvents,
          widget.commandShortcutEvents,
        ) ||
        !identical(
          oldWidget.characterShortcutEvents,
          widget.characterShortcutEvents,
        ) ||
        !identical(oldWidget.keyboardStrategies, widget.keyboardStrategies)) {
      _strategies = _buildStrategies();
    }
  }

  List<KeyboardStrategy> _buildStrategies() => widget.keyboardStrategies.isEmpty
      ? [
          DefaultEditorStrategy(
            commandShortcutEvents: widget.commandShortcutEvents,
            characterShortcutEvents: widget.characterShortcutEvents,
          ),
        ]
      : widget.keyboardStrategies;

  @override
  void dispose() {
    editorState.selectionNotifier.removeListener(_onSelectionChanged);
    editorState.service.selectionService.unregisterGestureInterceptor(
      'keyboard',
    );
    focusNode.removeListener(_onFocusChanged);
    if (widget.focusNode == null) {
      focusNode.dispose();
    }
    keepEditorFocusNotifier.removeListener(_onKeepEditorFocusChanged);
    super.dispose();
  }

  @override
  void disable({
    bool showCursor = false,
    UnfocusDisposition disposition = UnfocusDisposition.previouslyFocusedChild,
  }) {
    focusNode.unfocus(disposition: disposition);
  }

  @override
  void enable() {
    focusNode.requestFocus();
  }

  @override
  void enableShortcuts() {
    enableKeyboardShortcuts = true;
  }

  @override
  void disableShortcuts() {
    enableKeyboardShortcuts = false;
  }

  // Used in mobile only
  @override
  void closeKeyboard() {
    textInputService.close();
  }

  // Used in mobile only
  @override
  void enableKeyBoard(Selection selection) {
    _attachTextInputService(selection);
  }

  @override
  Widget build(BuildContext context) {
    Widget child = widget.child;
    // if there is no command shortcut event, we don't need to handle hardware keyboard.
    // like in read-only mode.
    if (widget.commandShortcutEvents.isNotEmpty ||
        widget.keyboardStrategies.isNotEmpty) {
      // the Focus widget is used to handle hardware keyboard.
      child = Focus(
        focusNode: focusNode,
        onKeyEvent: _onKeyEvent,
        child: child,
      );
    }

    // ignore the default behavior of the space key on web
    if (kIsWeb) {
      child = Shortcuts(
        shortcuts: {
          LogicalKeySet(LogicalKeyboardKey.space):
              const DoNothingAndStopPropagationIntent(),
        },
        child: child,
      );
    }

    return child;
  }

  @override
  void registerInterceptor(NovidentKeyboardServiceInterceptor interceptor) {
    interceptors.add(interceptor);
  }

  @override
  void unregisterInterceptor(NovidentKeyboardServiceInterceptor interceptor) {
    interceptors.remove(interceptor);
  }

  /// handle hardware keyboard
  KeyEventResult _onKeyEvent(FocusNode node, KeyEvent event) {
    if (!enableKeyboardShortcuts) {
      return KeyEventResult.ignored;
    }

    if ((event is! KeyDownEvent && event is! KeyRepeatEvent) ||
        !enableIMEShortcuts) {
      if (textInputService.composingTextRange != TextRange.empty) {
        return KeyEventResult.skipRemainingHandlers;
      }
      return KeyEventResult.ignored;
    }

    return dispatchKeyEvent(_strategies, event, editorState);
  }

  void _onSelectionChanged() {
    final doNotAttach = editorState
        .selectionExtraInfo?[selectionExtraInfoDoNotAttachTextService];
    if (doNotAttach == true) {
      return;
    }

    // attach the delta text input service if needed
    final selection = editorState.selection;

    enableIMEShortcuts = true;

    if (selection == null) {
      textInputService.close();
    } else {
      // For the deletion, we should attach the text input service immediately.
      _attachTextInputService(selection);
      _updateCaretPosition(selection);

      if (editorState.selectionUpdateReason == SelectionUpdateReason.uiEvent) {
        focusNode.requestFocus();
        NovidentEditorLog.editor.debug('keyboard service - request focus');
      } else {
        NovidentEditorLog.editor.debug(
          'keyboard service - selection changed: $selection',
        );
      }
    }

    previousSelection = selection;
  }

  void _attachTextInputService(Selection selection) {
    final textEditingValue = _getCurrentTextEditingValue(selection);
    if (textEditingValue != null) {
      textInputService.attach(
        textEditingValue,
        TextInputConfiguration(
          viewId: View.of(context).viewId,
          inputType: TextInputType.multiline,
          textCapitalization: TextCapitalization.sentences,
          inputAction: TextInputAction.newline,
          keyboardAppearance: Theme.of(context).brightness,
          enableSuggestions:
              UniversalPlatform.isMobile || UniversalPlatform.isMacOS,
          enableDeltaModel: true,
          allowedMimeTypes:
              widget.contentInsertionConfiguration?.allowedMimeTypes ?? [],
        ),
      );
      // disable shortcuts when the IME active
      enableIMEShortcuts = textEditingValue.composing == TextRange.empty;
    } else {
      enableIMEShortcuts = true;
    }
  }

  /// Cached plain text for the last set of editable nodes — avoids
  /// O(n²) string concatenation on every drag event. Invalidated by
  /// node list identity.
  String? _cachedPlainText;
  int? _cachedEndOffset;
  List<Node>? _cachedEditableNodes;

  @override
  void invalidateCache() {
    _cachedPlainText = null;
    _cachedEditableNodes = null;
  }

  // This function is used to get the current text editing value of the editor
  // based on the given selection.
  TextEditingValue? _getCurrentTextEditingValue(Selection selection) {
    final editableNodes = editorState.getNodesInSelection(selection);

    // if the selection is inline and the selection is updated by ui event,
    // we should clear the composing range on Android.
    final shouldClearComposingRange =
        editorState.selectionType == SelectionType.inline &&
            editorState.selectionUpdateReason == SelectionUpdateReason.uiEvent;

    if (EditorPlatform.isAndroid && shouldClearComposingRange) {
      textInputService.clearComposingTextRange();
    }

    // Get the composing text range.
    final composingTextRange =
        textInputService.composingTextRange ?? TextRange.empty;
    _cachedEndOffset = selection.isCollapsed || selection.isSingle
        ? null
        : selection.startIndex;
    if (editableNodes.isNotEmpty) {
      // Cache the concatenated text by node-set identity: drag
      // selections fire ~60×/s with identical node ranges — only the
      // offsets change. A plain StringBuffer eliminates the O(n²)
      // per-event allocations of the former fold.
      if (!identical(editableNodes, _cachedEditableNodes) ||
          _cachedPlainText == null) {
        final buffer = StringBuffer();
        for (final node in editableNodes) {
          buffer.writeln(node.delta?.toPlainText() ?? '');
        }
        _cachedEditableNodes = editableNodes;
        _cachedPlainText = buffer.toString();
        if (!selection.isCollapsed && !selection.isSingle) {
          _cachedEndOffset = _cachedPlainText!.length - 1;
        }
      }

      // strip trailing \n
      final text = _cachedPlainText!.substring(
        0,
        _cachedPlainText!.length - 1,
      );

      return TextEditingValue(
        text: text,
        selection: TextSelection(
          baseOffset: _clampOffset(selection.startIndex, text.length),
          extentOffset: selection.isSingle
              ? _clampOffset(selection.endIndex, text.length)
              : _clampOffset(
                  _cachedEndOffset ?? selection.endIndex,
                  text.length,
                ),
        ),
        composing: composingTextRange,
      );
    }
    return null;
  }

  /// Clamps a character offset to the valid `[0, length]` range.
  ///
  /// A selection can legitimately point at a non-text node (divider, image,
  /// …) whose `delta` is null, so the concatenated text is empty while the
  /// selection still carries non-zero offsets. Pushing such an out-of-range
  /// selection to the IME (`setEditingState`) trips Flutter's
  /// `TextEditingValue._textRangeIsValid` assertion, so clamp here.
  static int _clampOffset(int offset, int length) {
    if (offset < 0) return 0;
    if (offset > length) return length;
    return offset;
  }

  void _onFocusChanged() {
    NovidentEditorLog.editor.debug(
      'keyboard service - focus changed: ${focusNode.hasFocus}}',
    );

    final renderer = editorState.selectionRenderer;
    final selection = editorState.selection;
    final focusedNode = selection != null
        ? editorState.getNodeAtPath(selection.end.path)
        : null;

    if (focusNode.hasFocus) {
      renderer?.onFocusGained(
        FocusLifecycleContext(
          focusedNode: focusedNode,
          hasSelection: selection != null,
          selection: selection,
        ),
      );
    } else {
      renderer?.onFocusLost(
        FocusLifecycleContext(
          focusedNode: focusedNode,
          hasSelection: selection != null,
          selection: selection,
        ),
      );

      /// On web, we don't need to close the keyboard when the focus is lost.
      if (kIsWeb) {
        return;
      }

      // clear the selection when the focus is lost.
      if (keepEditorFocusNotifier.shouldKeepFocus) {
        return;
      }

      final children =
          WidgetsBinding.instance.focusManager.primaryFocus?.children;
      if (children != null && !children.contains(focusNode)) {
        editorState.selection = null;
      }
      textInputService.close();
    }
  }

  void _onKeepEditorFocusChanged() {
    NovidentEditorLog.editor.debug(
      'keyboard service - on keep editor focus changed: ${keepEditorFocusNotifier.value}}',
    );

    if (!keepEditorFocusNotifier.shouldKeepFocus) {
      focusNode.requestFocus();
    }
  }

  // only verify on macOS.
  void _updateCaretPosition(Selection? selection) {
    if (selection == null || !selection.isCollapsed) {
      return;
    }
    final node = editorState.getNodeAtPath(selection.start.path);
    if (node == null) {
      return;
    }
    final renderBox = node.renderBox;
    final selectable = node.selectable;
    if (renderBox != null && selectable != null) {
      final size = renderBox.size;
      final transform = renderBox.getTransformTo(null);
      final rect = selectable.getCursorRectInPosition(
        selection.end,
        shiftWithBaseOffset: true,
      );
      if (rect != null) {
        textInputService.updateCaretPosition(size, transform, rect);
      }
    }
  }

  DeltaTextInputService buildTextInputService() {
    return DeltaTextInputService(
      onInsert: (insertion) async {
        for (final interceptor in interceptors) {
          final result = await interceptor.interceptInsert(
            insertion,
            editorState,
            widget.characterShortcutEvents,
          );
          if (result) {
            assert(() {
              NovidentEditorLog.input.info(
                'keyboard service onInsert - intercepted by interceptor: $interceptor',
              );
              return true;
            }());
            return false;
          }
        }

        for (final strategy in _strategies) {
          final result = await strategy.onInsert(insertion, editorState);
          switch (result) {
            case ImeDeltaResult.handled:
              return true;
            case ImeDeltaResult.swallowed:
              return false;
            case ImeDeltaResult.ignored:
              break;
          }
        }

        await onInsert(
          insertion,
          editorState,
        );
        return true;
      },
      onDelete: (deletion) async {
        for (final interceptor in interceptors) {
          final result = await interceptor.interceptDelete(
            deletion,
            editorState,
          );
          if (result) {
            assert(() {
              NovidentEditorLog.input.info(
                'keyboard service onDelete - intercepted by interceptor: $interceptor',
              );
              return true;
            }());
            return false;
          }
        }

        for (final strategy in _strategies) {
          final result = await strategy.onDelete(deletion, editorState);
          switch (result) {
            case ImeDeltaResult.handled:
              return true;
            case ImeDeltaResult.swallowed:
              return false;
            case ImeDeltaResult.ignored:
              break;
          }
        }

        await onDelete(
          deletion,
          editorState,
        );
        return true;
      },
      onReplace: (replacement) async {
        for (final interceptor in interceptors) {
          final result = await interceptor.interceptReplace(
            replacement,
            editorState,
            widget.characterShortcutEvents,
          );
          if (result) {
            assert(() {
              NovidentEditorLog.input.info(
                'keyboard service onReplace - intercepted by interceptor: $interceptor',
              );
              return true;
            }());
            return false;
          }
        }

        for (final strategy in _strategies) {
          final result = await strategy.onReplace(replacement, editorState);
          switch (result) {
            case ImeDeltaResult.handled:
              return true;
            case ImeDeltaResult.swallowed:
              return false;
            case ImeDeltaResult.ignored:
              break;
          }
        }

        final selection = editorState.selection;
        if (selection != null && !selection.isSingle) {
          // Multi-node: preserve the historical order (delete → dispatch →
          // insert) — the selection is deleted BEFORE consulting the
          // strategies about the converted insertion.
          await editorState.deleteSelection(selection);
          final insertion = replacement.toInsertion();
          for (final strategy in _strategies) {
            final result = await strategy.onInsert(insertion, editorState);
            switch (result) {
              case ImeDeltaResult.handled:
                return true;
              case ImeDeltaResult.swallowed:
                return false;
              case ImeDeltaResult.ignored:
                break;
            }
          }
          await onInsert(
            insertion,
            editorState,
          );
          return true;
        }

        await onReplace(
          replacement,
          editorState,
        );
        return true;
      },
      onNonTextUpdate: (nonTextUpdate) async {
        for (final interceptor in interceptors) {
          final result = await interceptor.interceptNonTextUpdate(
            nonTextUpdate,
            editorState,
            widget.characterShortcutEvents,
          );
          if (result) {
            assert(() {
              NovidentEditorLog.input.info(
                'keyboard service onNonTextUpdate - intercepted by interceptor: $interceptor',
              );
              return true;
            }());
            return false;
          }
        }

        for (final strategy in _strategies) {
          final result =
              await strategy.onNonTextUpdate(nonTextUpdate, editorState);
          switch (result) {
            case ImeDeltaResult.handled:
              return true;
            case ImeDeltaResult.swallowed:
              return false;
            case ImeDeltaResult.ignored:
              break;
          }
        }

        await onNonTextUpdate(
          nonTextUpdate,
          editorState,
        );
        return true;
      },
      onPerformAction: (action) async {
        for (final interceptor in interceptors) {
          final result = await interceptor.interceptPerformAction(
            action,
            editorState,
          );
          if (result) {
            assert(() {
              NovidentEditorLog.input.info(
                'keyboard service onPerformAction - intercepted by interceptor: $interceptor',
              );
              return true;
            }());
            return;
          }
        }

        for (final strategy in _strategies) {
          final result = await strategy.onPerformAction(action, editorState);
          if (result != ImeDeltaResult.ignored) {
            return;
          }
        }

        await onPerformAction(
          action,
          editorState,
        );
      },
      onFloatingCursor: (point) async {
        for (final interceptor in interceptors) {
          final result = await interceptor.interceptFloatingCursor(
            point,
            editorState,
          );
          if (result) {
            assert(() {
              NovidentEditorLog.input.info(
                'keyboard service onFloatingCursor - intercepted by interceptor: $interceptor',
              );
              return true;
            }());
            return;
          }
        }

        for (final strategy in _strategies) {
          final result = await strategy.onFloatingCursor(point, editorState);
          if (result != ImeDeltaResult.ignored) {
            return;
          }
        }

        await onFloatingCursorUpdate(
          point,
          editorState,
        );
      },
      contentInsertionConfiguration: widget.contentInsertionConfiguration,
    );
  }
}
