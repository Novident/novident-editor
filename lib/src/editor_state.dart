import 'dart:async';
import 'dart:collection';

import 'package:novident_editor/novident_editor.dart';
import 'package:novident_editor/src/editor/editor_component/service/scroll/auto_scroller.dart';
import 'package:novident_editor/src/history/undo_manager.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';

typedef EditorTransactionValue = (
  TransactionTime time,
  Transaction transaction,
  ApplyOptions options,
);

class EditorStateDebugInfo {
  EditorStateDebugInfo({
    this.debugPaintSizeEnabled = false,
  });

  /// Enable the debug paint size for selection handle.
  ///
  /// It only available on mobile.
  bool debugPaintSizeEnabled;
}

/// the type of this value is bool.
///
/// set true to this key to prevent attaching the text service when selection is changed.
const selectionExtraInfoDoNotAttachTextService =
    'selectionExtraInfoDoNotAttachTextService';

class ApplyOptions {
  const ApplyOptions({
    this.recordUndo = true,
    this.recordRedo = false,
    this.inMemoryUpdate = false,
  });

  /// This flag indicates that
  /// whether the transaction should be recorded into
  /// the undo stack
  final bool recordUndo;
  final bool recordRedo;

  /// This flag used to determine whether the transaction is in-memory update.
  final bool inMemoryUpdate;
}

enum TransactionTime {
  before,
  after,
}

/// The state of the editor.
///
/// The state includes:
/// - The document to render
/// - The state of the selection
///
/// [EditorState] also includes the services of the editor:
/// - Selection service
/// - Scroll service
/// - Keyboard service
/// - Input service
/// - Toolbar service
///
/// In consideration of collaborative editing,
/// all the mutations should be applied through [Transaction].
///
/// Mutating the document with document's API is not recommended.
class EditorState implements BlockSelectionHost, RichTextEditorConfig {
  EditorState({
    required this.document,
    this.minHistoryItemDuration = const Duration(milliseconds: 50),
    int? maxHistoryItemSize,
  }) {
    undoManager = UndoManager(maxHistoryItemSize ?? 200);
    undoManager.state = this;
  }

  @Deprecated('use EditorState.blank() instead')
  EditorState.empty()
      : this(
          document: Document.blank(),
        );

  EditorState.blank({
    bool withInitialText = true,
  }) : this(
          document: Document.blank(
            withInitialText: withInitialText,
          ),
        );

  final Document document;

  // the minimum duration for saving the history item.
  final Duration minHistoryItemDuration;

  /// Whether the editor is editable.
  ValueNotifier<bool> editableNotifier = ValueNotifier(true);

  bool get editable => editableNotifier.value;

  set editable(bool value) {
    if (value == editable) {
      return;
    }
    editableNotifier.value = value;
  }

  /// Whether the editor should disable auto scroll.
  bool disableAutoScroll = false;

  /// The edge offset of the auto scroll.
  double autoScrollEdgeOffset = novidentEditorAutoScrollEdgeOffset;

  /// The style of the editor.
  ///
  /// Defaults to [EditorStyle.desktop] (same default as [NovidentEditor]) so
  /// [EditorState] is usable without widget initialization (e.g. unit tests
  /// calling [updateSelectionWithReason] directly). Overwritten by
  /// [NovidentEditor] during init.
  EditorStyle editorStyle = const EditorStyle.desktop();

  /// The styles configuration for the editor.
  ///
  /// Set by [NovidentEditor] during init. Used by [insertNewLine] to resolve
  /// [NovidentStyleDefinition.next] when creating consecutive paragraphs.
  NovidentStylesConfig? editorStyles;

  /// The font provider for the editor.
  ///
  /// Supplies the list of available font families and a guaranteed non-null
  /// default. Set by [NovidentEditor] during init.
  NovidentFontProvider? fontProvider;

  /// Customizes how the caret is painted by the selection areas.
  ///
  /// When not null, it is consulted every time a caret is painted — return
  /// a [CursorAppearance] to adjust the caret rect, style, color or blink
  /// behavior (e.g. a vim-like block cursor), or null to keep the default
  /// painting.
  CursorAppearanceBuilder? cursorAppearanceBuilder;

  @override
  SelectionRenderer? get selectionRenderer => editorStyle.selectionRenderer;

  /// @override from BlockSelectionHost
  @override
  bool isBlockSelectionMode() => selectionType == SelectionType.block;

  /// @override from BlockSelectionHost
  @override
  CursorAppearance? customizeCursor({
    required Node node,
    required Selection? selection,
    required Position position,
  }) {
    return cursorAppearanceBuilder?.call(node, selection!, position);
  }

  /// @override from BlockSelectionHost
  @override
  EdgeInsets? blockSelectionMargin(Node node) {
    final builder = service.rendererService.blockComponentBuilder(node.type);
    return builder?.configuration.blockSelectionAreaMargin(node);
  }

  /// @override from BlockSelectionHost
  @override
  dynamic selectionDragModeValue() => selectionExtraInfo?[selectionDragModeKey];

  // ---- RichTextEditorConfig overrides ----

  @override
  double get textScaleFactor => editorStyle.textScaleFactor;

  @override
  double? get firstLineIndentFallback => editorStyle.firstLineIndent;

  @override
  TextSpanDecoratorForAttribute? get textSpanDecorator =>
      editorStyle.textSpanDecorator;

  @override
  NovidentTextSpanOverlayBuilder? get textSpanOverlayBuilder =>
      editorStyle.textSpanOverlayBuilder;

  @override
  TextStyleConfiguration get textStyleConfiguration =>
      editorStyle.textStyleConfiguration;

  @override
  NovidentTextSpanPipeline? get spanPipeline {
    if (editorStyle.spellChecker == null) {
      return null;
    }
    return SpellCheckSpanPipeline(
      misspelledStyle: editorStyle.spellCheckMisspelledStyle ??
          SpellCheckSpanPipeline.defaultMisspelledStyle,
    );
  }

  /// The spell-check analysis service, created and attached by the editor
  /// widget when [EditorStyle.spellChecker] is set.
  SpellCheckService? spellCheckService;

  /// The selection notifier of the editor.
  /// The selection notifier of the editor.
  @override
  final PropertyValueNotifier<Selection?> selectionNotifier =
      PropertyValueNotifier<Selection?>(null);

  /// The selection of the editor.
  Selection? get selection => selectionNotifier.value;

  /// Remote selection is the selection from other users.
  @override
  final PropertyValueNotifier<List<RemoteSelection>> remoteSelections =
      PropertyValueNotifier<List<RemoteSelection>>([]);

  /// Sets the selection of the editor.
  set selection(Selection? value) {
    // clear the toggled style when the selection is changed.
    if (selectionNotifier.value != value) {
      _toggledStyle.clear();
    }

    // reset slice flag
    sliceUpcomingAttributes = true;

    selectionNotifier.value = value;
  }

  SelectionType? _selectionType;

  set selectionType(SelectionType? value) {
    if (value == _selectionType) {
      return;
    }
    _selectionType = value;
  }

  SelectionType? get selectionType => _selectionType;

  SelectionUpdateReason _selectionUpdateReason = SelectionUpdateReason.uiEvent;

  SelectionUpdateReason get selectionUpdateReason => _selectionUpdateReason;

  Map? selectionExtraInfo;

  // Service reference.
  final service = EditorService();

  NovidentScrollService? get scrollService => service.scrollService;

  NovidentSelectionService get selectionService => service.selectionService;

  BlockComponentRendererService get renderer => service.rendererService;

  set renderer(BlockComponentRendererService value) {
    service.rendererService = value;
  }

  /// Customize the debug info for the editor state.
  ///
  /// Refer to [EditorStateDebugInfo] for more details.
  EditorStateDebugInfo debugInfo = EditorStateDebugInfo();

  /// store the auto scroller instance in here temporarily.
  AutoScroller? autoScroller;
  ScrollableState? scrollableState;

  /// The dynamic height controller, if dynamic height mode is active.
  DynamicHeightController? dynamicHeightController;

  /// Configures log output parameters,
  /// such as log level and log output callbacks,
  /// with this variable.
  NovidentLogConfiguration get logConfiguration => NovidentLogConfiguration();

  /// Stores the selection menu items.
  List<SelectionMenuItem> selectionMenuItems = [];

  /// Stores the toolbar items.
  @Deprecated('use floating toolbar or mobile toolbar instead')
  List<ToolbarItem> toolbarItems = [];

  /// listen to this stream to get notified when the transaction applies.
  Stream<EditorTransactionValue> get transactionStream => _observer.stream;
  final StreamController<EditorTransactionValue> _observer =
      StreamController.broadcast(sync: true);
  final StreamController<EditorTransactionValue> _asyncObserver =
      StreamController.broadcast();

  /// Store the toggled format style, like bold, italic, etc.
  /// All the values must be the key from [RichTextKeys.supportToggled].
  ///
  /// Use the method [updateToggledStyle] to update key-value pairs
  ///
  /// NOTES: It only works once;
  ///   after the selection is changed, the toggled style will be cleared.
  UnmodifiableMapView<String, dynamic> get toggledStyle =>
      UnmodifiableMapView<String, dynamic>(_toggledStyle);
  final _toggledStyle = Attributes();
  late final toggledStyleNotifier = ValueNotifier<Attributes>(toggledStyle);

  void updateToggledStyle(String key, dynamic value) {
    _toggledStyle[key] = value;
    toggledStyleNotifier.value = {..._toggledStyle};
  }

  /// Whether the upcoming attributes should be sliced.
  ///
  /// If the value is true, the upcoming attributes will be sliced.
  /// If the value is false, the upcoming attributes will be skipped.
  bool _sliceUpcomingAttributes = true;

  bool get sliceUpcomingAttributes => _sliceUpcomingAttributes;

  set sliceUpcomingAttributes(bool value) {
    if (value == _sliceUpcomingAttributes) {
      return;
    }
    NovidentEditorLog.input.debug('sliceUpcomingAttributes: $value');
    _sliceUpcomingAttributes = value;
  }

  late final UndoManager undoManager;

  Transaction get transaction {
    final transaction = Transaction(document: document);
    transaction.beforeSelection = selection;
    return transaction;
  }

  bool showHeader = false;
  bool showFooter = false;

  @override
  bool enableAutoComplete = false;
  @override
  NovidentAutoCompleteTextProvider? autoCompleteTextProvider;

  // only used for testing
  bool disableSealTimer = false;

  /// The rules to apply to the document.
  List<DocumentRule> get documentRules => _documentRules;
  List<DocumentRule> _documentRules = [];
  set documentRules(List<DocumentRule> value) {
    _documentRules = value;

    _subscription?.cancel();
    _subscription = _asyncObserver.stream.listen((value) async {
      for (final rule in _documentRules) {
        if (rule.shouldApply(editorState: this, value: value)) {
          await rule.apply(editorState: this, value: value);
        }
      }
    });
  }

  StreamSubscription? _subscription;

  final Set<VoidCallback> _onScrollViewScrolledListeners = {};

  void addScrollViewScrolledListener(VoidCallback callback) =>
      _onScrollViewScrolledListeners.add(callback);

  void removeScrollViewScrolledListener(VoidCallback callback) =>
      _onScrollViewScrolledListeners.remove(callback);

  void _notifyScrollViewScrolledListeners() {
    for (final listener in Set.of(_onScrollViewScrolledListeners)) {
      listener.call();
    }
  }

  RenderBox? get renderBox {
    final renderObject =
        service.scrollServiceKey.currentContext?.findRenderObject();
    if (renderObject != null && renderObject is RenderBox) {
      return renderObject;
    }
    return null;
  }

  Future<void> updateSelectionWithReason(
    Selection? selection, {
    SelectionUpdateReason reason = SelectionUpdateReason.transaction,
    Map? extraInfo,
    SelectionType? customSelectionType,
  }) async {
    final completer = Completer<void>();

    if (reason == SelectionUpdateReason.uiEvent) {
      _selectionType = customSelectionType ?? SelectionType.inline;
      // Complete after the frame is rendered so listeners can re-measure
      // the freshly painted selection.
      WidgetsBinding.instance.addPostFrameCallback(
        (timeStamp) => completer.complete(),
      );
    } else if (customSelectionType != null) {
      _selectionType = customSelectionType;
    }

    // broadcast to other users here
    selectionExtraInfo = extraInfo;
    _selectionUpdateReason = reason;

    // Assign synchronously when there is no custom renderer so callers
    // (including unit tests) can read `selection` immediately after the
    // call. With a custom renderer, wait for its normalized result.
    final renderer = selectionRenderer;
    if (renderer == null) {
      this.selection = selection;
    } else {
      this.selection = (await renderer.updateSelectionWithReason(
            this,
            selection,
            reason: reason,
            extraInfo: extraInfo,
            customSelectionType: customSelectionType,
          )) ??
          selection;
    }

    // The completer must always complete: non-UI-event callers get an
    // already-completed future, UI-event callers resolve after the frame.
    if (reason != SelectionUpdateReason.uiEvent) {
      completer.complete();
    }

    return completer.future;
  }

  /// Re-notifies every selection listener without changing the selection
  /// value, the update reason, or the selection renderer.
  ///
  /// [updateSelectionWithReason] is the single entry point for REAL
  /// selection changes; it goes through the renderer and completes an
  /// awaitable future. Some flows only need to force the visual selection
  /// to repaint after the value has already been set (e.g. re-showing the
  /// selection when the context menu closes). In those cases the value
  /// comparison inside the notifier would swallow the notification — this
  /// method delivers it directly.
  void refreshSelection() {
    // PropertyValueNotifier notifies its listeners on every assignment,
    // even for an equal value — re-assigning the current value is the
    // supported way to deliver a pure notification wave.
    selectionNotifier.value = selectionNotifier.value;
  }

  Timer? _debouncedSealHistoryItemTimer;
  final bool _enableCheckIntegrity = false;

  // the value of the notifier is meaningless, just for triggering the callbacks.
  final ValueNotifier<int> onDispose = ValueNotifier(0);

  bool isDisposed = false;

  void dispose() {
    isDisposed = true;
    spellCheckService?.dispose();
    spellCheckService = null;
    _observer.close();
    _asyncObserver.close();
    _debouncedSealHistoryItemTimer?.cancel();
    onDispose.value += 1;
    onDispose.dispose();
    document.dispose();
    selectionNotifier.dispose();
    _subscription?.cancel();
    _onScrollViewScrolledListeners.clear();
  }

  /// Apply the transaction to the state.
  ///
  /// The options can be used to determine whether the editor
  /// should record the transaction in undo/redo stack.
  ///
  /// The maximumRuleApplyLoop is used to prevent infinite loop.
  ///
  /// The withUpdateSelection is used to determine whether the editor
  /// should update the selection after applying the transaction.
  Future<void> apply(
    Transaction transaction, {
    bool isRemote = false,
    ApplyOptions options = const ApplyOptions(),
    bool withUpdateSelection = true,
    bool skipHistoryDebounce = false,
  }) async {
    if (!editable || isDisposed) {
      return;
    }

    // it's a time consuming task, only enable it if necessary.
    if (_enableCheckIntegrity) {
      document.root.checkDocumentIntegrity();
    }

    final completer = Completer<void>();

    if (isRemote) {
      _selectionUpdateReason = SelectionUpdateReason.remote;
      selection = _applyTransactionFromRemote(transaction);
    } else {
      // broadcast to other users here, before applying the transaction
      if (!_observer.isClosed) {
        _observer.add((TransactionTime.before, transaction, options));
      }

      if (!_asyncObserver.isClosed) {
        _asyncObserver.add((TransactionTime.before, transaction, options));
      }

      _applyTransactionInLocal(transaction);

      _notifyDynamicHeightController(transaction);

      // broadcast to other users here, after applying the transaction
      if (!_observer.isClosed) {
        _observer.add((TransactionTime.after, transaction, options));
      }

      if (!_asyncObserver.isClosed) {
        _asyncObserver.add((TransactionTime.after, transaction, options));
      }

      _recordRedoOrUndo(options, transaction, skipHistoryDebounce);

      if (withUpdateSelection) {
        _selectionUpdateReason =
            transaction.reason ?? SelectionUpdateReason.transaction;
        _selectionType = transaction.customSelectionType;
        if (transaction.selectionExtraInfo != null) {
          selectionExtraInfo = transaction.selectionExtraInfo;
        }
        selection = transaction.afterSelection;
      }
    }

    completer.complete();

    return completer.future;
  }

  /// Force rebuild the editor.
  void reload() {
    document.root.notify();
  }

  void applyCharacterCommand(CharacterShortcutEvent command) {
    command.handler(this);
  }

  void applyCommand(CommandShortcutEvent command) {
    command.handler(this);
  }

  /// get nodes in selection
  ///
  /// if selection is backward, return nodes in order
  /// if selection is forward, return nodes in reverse order
  ///
  List<Node> getNodesInSelection(Selection selection) {
    // Normalize the selection.
    final normalized = selection.normalized;

    // Get the start and end nodes.
    final startNode = document.nodeAtPath(normalized.start.path);
    final endNode = document.nodeAtPath(normalized.end.path);

    // If we have both nodes, we can find the nodes in the selection.
    if (startNode != null && endNode != null) {
      final nodes = NodeIterator(
        document: document,
        startNode: startNode,
        endNode: endNode,
      ).toList();

      return nodes;
    }

    // If we don't have both nodes, we can't find the nodes in the selection.
    return [];
  }

  List<Node> getSelectedNodes({
    Selection? selection,
    bool withCopy = true,
  }) {
    List<Node> res = [];
    selection ??= this.selection;
    if (selection == null) {
      return res;
    }
    final nodes = getNodesInSelection(selection);
    for (final node in nodes) {
      if (res.any((element) => element.isParentOf(node))) {
        continue;
      }
      res.add(node);
    }

    if (withCopy) {
      res = res.map((e) => e.copyWith()).toList();
    }

    if (res.isNotEmpty) {
      var delta = res.first.delta;
      if (delta != null) {
        res.first.updateAttributes(
          {
            ...res.first.attributes,
            blockComponentDelta: delta
                .slice(
                  selection.startIndex,
                  selection.isSingle ? selection.endIndex : delta.length,
                )
                .toJson(),
          },
        );
      }

      var node = res.last;
      while (node.children.isNotEmpty) {
        node = node.children.last;
      }
      delta = node.delta;
      if (delta != null && !selection.isSingle) {
        if (node.parent != null) {
          node.insertBefore(
            node.copyWith(
              attributes: {
                ...node.attributes,
                blockComponentDelta: delta
                    .slice(
                      0,
                      selection.endIndex,
                    )
                    .toJson(),
              },
            ),
          );
          node.unlink();
        } else {
          node.updateAttributes(
            {
              ...node.attributes,
              blockComponentDelta: delta
                  .slice(
                    0,
                    selection.endIndex,
                  )
                  .toJson(),
            },
          );
        }
      }
    }

    return res;
  }

  Node? getNodeAtPath(Path path) {
    return document.nodeAtPath(path);
  }

  /// The current selection areas's rect in editor.
  ///
  /// Computed fresh on every call. Global coordinates depend on the
  /// current scroll offset, so caching across frames would return
  /// stale positions during scroll animations.
  List<Rect> selectionRects() {
    final sel = selection;
    if (sel == null) return [];
    return _computeSelectionRects(sel);
  }

  List<Rect> _computeSelectionRects(Selection selection) {
    final nodes = getNodesInSelection(selection);
    final rects = <Rect>[];

    if (selection.isCollapsed && nodes.length == 1) {
      final selectable = nodes.first.selectable;
      if (selectable != null) {
        final rect = selectable.getCursorRectInPosition(
          selection.end,
          shiftWithBaseOffset: true,
        );
        if (rect != null) {
          rects.add(
            selectable.transformRectToGlobal(
              rect,
              shiftWithBaseOffset: true,
            ),
          );
        }
      }
    } else {
      for (final node in nodes) {
        final selectable = node.selectable;
        if (selectable == null) {
          continue;
        }
        final nodeRects = selectable.getRectsInSelection(
          selection,
          shiftWithBaseOffset: true,
        );
        if (nodeRects.isEmpty) {
          continue;
        }
        final renderBox = node.renderBox;
        if (renderBox == null) {
          continue;
        }
        for (final rect in nodeRects) {
          final globalOffset = renderBox.localToGlobal(rect.topLeft);
          rects.add(globalOffset & rect.size);
        }
      }
    }

    return rects;
  }

  void cancelSubscription() {
    _observer.close();
  }

  void updateAutoScroller(
    ScrollableState scrollableState,
  ) {
    if (this.scrollableState != scrollableState) {
      autoScroller?.stopAutoScroll();
      final bool isDesktopOrWeb = PlatformExtension.isDesktopOrWeb;
      late AutoScroller scroller;
      scroller = AutoScroller(
        scrollableState,
        velocityScalar: 0.5,
        minimumAutoScrollDelta: 0.07,
        maxAutoScrollDelta: 15.0,
        animationDuration: Duration.zero,
        onScrollViewScrolled: () {
          _notifyScrollViewScrolledListeners();
          if (!isDesktopOrWeb) {
            final dynamic dragMode = selectionExtraInfo?[selectionDragModeKey];
            final bool isDraggingSelection = dragMode != null &&
                dragMode.toString() != 'MobileSelectionDragMode.none';
            if (!isDraggingSelection) {
              return;
            }
            WidgetsBinding.instance.addPostFrameCallback((_) {
              if (autoScroller == scroller) {
                scroller.continueToAutoScroll();
              }
            });
          }
        },
      );
      autoScroller = scroller;
      this.scrollableState = scrollableState;
    }
  }

  void _recordRedoOrUndo(
    ApplyOptions options,
    Transaction transaction,
    bool skipDebounce,
  ) {
    if (options.recordUndo) {
      final undoItem = undoManager.getUndoHistoryItem();
      undoItem.addAll(transaction.operations);
      if (undoItem.beforeSelection == null &&
          transaction.beforeSelection != null) {
        undoItem.beforeSelection = transaction.beforeSelection;
      }
      undoItem.afterSelection = transaction.afterSelection;
      if (skipDebounce && undoManager.undoStack.isNonEmpty) {
        NovidentEditorLog.editor.debug('Seal history item');
        final last = undoManager.undoStack.last;
        last.seal();
      } else {
        _debouncedSealHistoryItem();
      }
    } else if (options.recordRedo) {
      final redoItem = HistoryItem();
      redoItem.addAll(transaction.operations);
      redoItem.beforeSelection = transaction.beforeSelection;
      redoItem.afterSelection = transaction.afterSelection;
      undoManager.redoStack.push(redoItem);
    }
  }

  void _debouncedSealHistoryItem() {
    if (disableSealTimer) {
      return;
    }
    _debouncedSealHistoryItemTimer?.cancel();
    _debouncedSealHistoryItemTimer = Timer(minHistoryItemDuration, () {
      if (undoManager.undoStack.isNonEmpty) {
        NovidentEditorLog.editor.debug('Seal history item');
        final last = undoManager.undoStack.last;
        last.seal();
      }
    });
  }

  void _applyTransactionInLocal(Transaction transaction) {
    final changedNodes = <Node>[];
    for (final op in transaction.operations) {
      NovidentEditorLog.editor.debug('apply op (local): ${op.toJson()}');

      if (op is InsertOperation) {
        document.insert(op.path, op.nodes);
        // Pasted/inserted nodes with text: emit so consumers (spell check)
        // analyze their deltas.
        for (final node in op.nodes) {
          if (node.delta != null && node.delta!.isNotEmpty) {
            changedNodes.add(node);
          }
        }
      } else if (op is UpdateOperation) {
        // ignore the update operation if the attributes are the same.
        if (!mapEquals(op.attributes, op.oldAttributes)) {
          document.update(op.path, op.attributes);
          // Delta updates without compose-map metadata (undo/redo and any
          // direct delta replacement): emit an empty change for the node.
          if (op.attributes.containsKey('delta') ||
              op.oldAttributes.containsKey('delta')) {
            final node = document.nodeAtPath(op.path);
            if (node != null) {
              changedNodes.add(node);
            }
          }
        }
      } else if (op is DeleteOperation) {
        document.delete(op.path, op.nodes.length);
      } else if (op is UpdateTextOperation) {
        // Pure full-text replacement: emit an empty change for the node.
        document.updateText(op.path, op.delta);
        final node = document.nodeAtPath(op.path);
        if (node != null) {
          changedNodes.add(node);
        }
      }
    }

    _emitDeltaChanges(transaction, changedNodes);
  }

  /// Emits the captured delta changes to the document listeners, after the
  /// transaction has been fully applied (the nodes already hold the final
  /// deltas). Nodes whose delta changed without local metadata
  /// (undo/redo, paste, full-text replacements, remote updates) get an
  /// empty changes list.
  void _emitDeltaChanges(
    Transaction transaction,
    List<Node> changedNodes,
  ) {
    final emitted = <Node>{};
    for (final entry in transaction.deltaChanges.entries) {
      document.emitChanges(entry.key, entry.value);
      emitted.add(entry.key);
    }
    transaction.clearDeltaChanges();

    for (final node in changedNodes) {
      // Nodes already covered by captured delta changes emit once.
      if (emitted.contains(node)) {
        continue;
      }
      document.emitChanges(node, const []);
    }
  }

  void _notifyDynamicHeightController(Transaction transaction) {
    final controller = dynamicHeightController;
    if (controller == null) return;

    for (final op in transaction.operations) {
      if (op is InsertOperation) {
        final path = op.path;
        if (path.length == 1) {
          controller.onDocumentMutation(
            NodesInserted(atIndex: path.last, count: op.nodes.length),
          );
        }
      } else if (op is DeleteOperation) {
        final path = op.path;
        if (path.length == 1) {
          controller.onDocumentMutation(
            NodesRemoved(atIndex: path.last, count: op.nodes.length),
          );
        }
      } else if (op is UpdateTextOperation) {
        final path = op.path;
        if (path.isNotEmpty) {
          controller.onDocumentMutation(
            TextChanged(nodeIndex: path.first),
          );
        }
      }
    }
  }

  Selection? _applyTransactionFromRemote(Transaction transaction) {
    var selection = this.selection;
    final changedNodes = <Node>[];

    for (final op in transaction.operations) {
      NovidentEditorLog.editor.debug('apply op (remote): ${op.toJson()}');

      if (op is InsertOperation) {
        document.insert(op.path, op.nodes);
        for (final node in op.nodes) {
          if (node.delta != null && node.delta!.isNotEmpty) {
            changedNodes.add(node);
          }
        }
        if (selection != null) {
          if (op.path <= selection.start.path) {
            selection = Selection(
              start: selection.start.copyWith(
                path: selection.start.path.nextNPath(op.nodes.length),
              ),
              end: selection.end.copyWith(
                path: selection.end.path.nextNPath(op.nodes.length),
              ),
            );
          }
        }
      } else if (op is UpdateOperation) {
        document.update(op.path, op.attributes);
        if (op.attributes.containsKey('delta') ||
            op.oldAttributes.containsKey('delta')) {
          final node = document.nodeAtPath(op.path);
          if (node != null) {
            changedNodes.add(node);
          }
        }
      } else if (op is DeleteOperation) {
        document.delete(op.path, op.nodes.length);
        if (selection != null) {
          if (op.path <= selection.start.path) {
            selection = Selection(
              start: selection.start.copyWith(
                path: selection.start.path.previous,
              ),
              end: selection.end.copyWith(
                path: selection.end.path.previous,
              ),
            );
          }
        }
      } else if (op is UpdateTextOperation) {
        document.updateText(op.path, op.delta);
        final node = document.nodeAtPath(op.path);
        if (node != null) {
          changedNodes.add(node);
        }
      }
    }

    // Remote text updates have no local metadata: emit an empty changes
    // list so consumers re-analyze the affected nodes entirely.
    for (final node in changedNodes) {
      document.emitChanges(node, const []);
    }

    return selection;
  }
}
