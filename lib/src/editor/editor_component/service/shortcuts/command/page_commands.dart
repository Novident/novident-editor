import 'package:novident_editor/novident_editor.dart';
import 'package:flutter/material.dart';

import 'move_hooks.dart';

final List<CommandShortcutEvent> pageUpKeys = [
  pageUpCommand,
  pageDownCommand,
];

final CommandShortcutEvent pageUpCommand = CommandShortcutEvent(
  key: 'move cursor page up',
  getDescription: () => 'Page Up',
  command: 'page up',
  handler: _pageUpCommandHandler,
);

final CommandShortcutEvent pageDownCommand = CommandShortcutEvent(
  key: 'move cursor page down',
  getDescription: () => 'Page Down',
  command: 'page down',
  handler: _pageDownCommandHandler,
);

CommandShortcutEventHandler _pageUpCommandHandler = (editorState) {
  final selection = editorState.selection;
  if (selection == null) return KeyEventResult.ignored;

  final renderer = editorState.selectionRenderer;
  if (renderer != null) {
    final node = editorState.getNodeAtPath(selection.end.path);
    final selectable = node?.selectable;
    final rp = selectable?.getRenderParagraph();
    if (node != null && selectable != null && rp != null) {
      final ctx = CursorMoveContext(
        node: node,
        currentOffset: selection.end.offset,
        selection: selection,
        caretLocalDx: selectable.getCaretLocalDx(selection.end.offset) ?? 0,
        textDirection: selectable.textDirection(),
        delegate: selectable,
        renderParagraph: rp,
        textShift: selectable.textShift,
        delta: node.delta,
      );
      final custom = renderer.onPageUp(ctx);
      if (custom != null) {
        final from = selection.end;
        final hookResult = tryMoveHook(
          renderer: renderer,
          editorState: editorState,
          fromPosition: from,
          toPosition: custom,
          direction: MoveDirection.pageUp,
        );
        if (hookResult == null) return KeyEventResult.handled;
        editorState.updateSelectionWithReason(
          Selection.collapsed(hookResult),
          reason: SelectionUpdateReason.uiEvent,
        );
        moveCompletedHook(
          renderer: renderer,
          editorState: editorState,
          fromPosition: from,
          toPosition: hookResult,
          direction: MoveDirection.pageUp,
        );
        return KeyEventResult.handled;
      }
    }
  }

  final scrollService = editorState.scrollService;
  final pageHeight = scrollService?.onePageHeight;
  if (scrollService != null && pageHeight != null) {
    final targetDy = (scrollService.dy - pageHeight)
        .clamp(scrollService.minScrollExtent, scrollService.maxScrollExtent);
    scrollService.scrollTo(targetDy);
  }
  return KeyEventResult.handled;
};

CommandShortcutEventHandler _pageDownCommandHandler = (editorState) {
  final selection = editorState.selection;
  if (selection == null) return KeyEventResult.ignored;

  final renderer = editorState.selectionRenderer;
  if (renderer != null) {
    final node = editorState.getNodeAtPath(selection.end.path);
    final selectable = node?.selectable;
    final rp = selectable?.getRenderParagraph();
    if (node != null && selectable != null && rp != null) {
      final ctx = CursorMoveContext(
        node: node,
        currentOffset: selection.end.offset,
        caretLocalDx: selectable.getCaretLocalDx(selection.end.offset) ?? 0,
        textDirection: selectable.textDirection(),
        delegate: selectable,
        renderParagraph: rp,
        textShift: selectable.textShift,
        selection: selection,
        delta: node.delta,
        forward: true,
      );
      final custom = renderer.onPageDown(ctx);
      if (custom != null) {
        final from = selection.end;
        final hookResult = tryMoveHook(
          renderer: renderer,
          editorState: editorState,
          fromPosition: from,
          toPosition: custom,
          direction: MoveDirection.pageDown,
        );
        if (hookResult == null) return KeyEventResult.handled;
        editorState.updateSelectionWithReason(
          Selection.collapsed(hookResult),
          reason: SelectionUpdateReason.uiEvent,
        );
        moveCompletedHook(
          renderer: renderer,
          editorState: editorState,
          fromPosition: from,
          toPosition: hookResult,
          direction: MoveDirection.pageDown,
        );
        return KeyEventResult.handled;
      }
    }
  }

  final scrollService = editorState.scrollService;
  final pageHeight = scrollService?.onePageHeight;
  if (scrollService != null && pageHeight != null) {
    final targetDy = (scrollService.dy + pageHeight)
        .clamp(scrollService.minScrollExtent, scrollService.maxScrollExtent);
    scrollService.scrollTo(targetDy);
  }
  return KeyEventResult.handled;
};
